// LocalSendManager.swift — P2P LAN file transfer (no VPS, no cloud).

import Foundation
import Network
import AppKit

@MainActor
final class LocalSendManager: ObservableObject {
    @Published private(set) var peers: [LocalPeer] = []
    @Published var progress: LocalTransferProgress?
    @Published var incomingOffer: IncomingLocalOffer?

    let deviceId: String
    let friendlyName: String

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var acceptContinuation: CheckedContinuation<Bool, Never>?
    private var resumeOffsets: [String: [Int: Int64]] = [:]
    private var activeTask: Task<Void, Never>?

    init() {
        deviceId = LocalSendDiscovery.loadDeviceId()
        friendlyName = LocalSendDiscovery.friendlyDeviceName()
    }

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            let listener = try NWListener(using: params, on: .any)
            self.listener = listener
            listener.service = NWListener.Service(
                name: "SB-\(deviceId.prefix(8))",
                type: LocalSendProtocol.serviceType,
                txtRecord: nil
            )
            listener.newConnectionHandler = { [weak self] conn in
                Task { await self?.handleIncoming(conn) }
            }
            listener.start(queue: .global(qos: .userInitiated))

            let browser = NWBrowser(for: .bonjour(type: LocalSendProtocol.serviceType, domain: nil), using: params)
            self.browser = browser
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { await self?.updatePeers(from: results) }
            }
            browser.start(queue: .global(qos: .userInitiated))
        } catch {
            NSLog("LocalSend start failed: \(error)")
        }
    }

    func stop() {
        activeTask?.cancel()
        browser?.cancel()
        listener?.cancel()
        browser = nil
        listener = nil
        peers = []
    }

    func acceptIncoming() {
        incomingOffer = nil
        acceptContinuation?.resume(returning: true)
        acceptContinuation = nil
    }

    func rejectIncoming() {
        incomingOffer = nil
        acceptContinuation?.resume(returning: false)
        acceptContinuation = nil
    }

    func cancelTransfer() {
        activeTask?.cancel()
        progress = nil
    }

    func send(to peer: LocalPeer, urls: [URL]) {
        activeTask?.cancel()
        activeTask = Task { await sendTransfer(peer: peer, urls: urls) }
    }

    // MARK: - Discovery

    private func updatePeers(from results: Set<NWBrowser.Result>) {
        var found: [LocalPeer] = []
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            if name.contains(String(deviceId.prefix(8))) { continue }
            let id = name
            if id == deviceId { continue }
            let peerName = name
            let platform = "unknown"

            let resolve = NWConnection(to: result.endpoint, using: .tcp)
            resolve.stateUpdateHandler = { [weak self] state in
                guard case .ready = state,
                      case let .hostPort(host, port) = resolve.currentPath?.remoteEndpoint else { return }
                let peer = LocalPeer(id: id, name: peerName, platform: platform, host: "\(host)", port: Int(port.rawValue))
                Task { @MainActor in self?.upsertPeer(peer) }
                resolve.cancel()
            }
            resolve.start(queue: .global())
            found.append(LocalPeer(id: id, name: peerName, platform: platform, host: "", port: 0))
        }
        _ = found
    }

    private func upsertPeer(_ peer: LocalPeer) {
        guard !peer.host.isEmpty else { return }
        var map = Dictionary(uniqueKeysWithValues: peers.map { ($0.id, $0) })
        map[peer.id] = peer
        peers = map.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Incoming

    private func handleIncoming(_ connection: NWConnection) async {
        guard activeTask == nil || activeTask?.isCancelled == true else {
            connection.cancel()
            return
        }
        activeTask = Task { await processIncoming(connection) }
    }

    private func processIncoming(_ connection: NWConnection) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
                guard let self, let data, let line = String(data: data, encoding: .utf8)?.components(separatedBy: "\n").first,
                      let json = try? JSONDecoder().decode(LocalSendProtocol.Offer.self, from: Data(line.utf8)) else {
                    connection.cancel()
                    cont.resume()
                    return
                }
                Task { @MainActor in
                    let peer = LocalPeer(id: "unknown", name: json.sender, platform: "unknown", host: "", port: 0)
                    self.incomingOffer = IncomingLocalOffer(offer: json, peer: peer)
                    let accepted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                        self.acceptContinuation = c
                    }
                    self.acceptContinuation = nil
                    if accepted {
                        await self.receive(on: connection, offer: json, startData: data)
                    } else {
                        let reject = try? LocalSendProtocol.encodeLine(LocalSendProtocol.Reject(id: json.id, reason: "Declined"))
                        if let reject { connection.send(content: reject, completion: .contentProcessed { _ in }) }
                        connection.cancel()
                    }
                    self.incomingOffer = nil
                    cont.resume()
                }
            }
        }
    }

    // MARK: - Receive

    private func receive(on connection: NWConnection, offer: LocalSendProtocol.Offer, startData: Data) async {
        let destRoot = receiveDirectory()
        var offsets = resumeOffsets[offer.id] ?? [:]
        let resumeEntries = offsets.filter { $0.value > 0 }.map { LocalSendProtocol.Resume.Entry(index: $0.key, offset: $0.value) }

        let acceptData: Data
        if resumeEntries.isEmpty {
            acceptData = (try? LocalSendProtocol.encodeLine(LocalSendProtocol.Accept(id: offer.id))) ?? Data()
        } else {
            acceptData = (try? LocalSendProtocol.encodeLine(LocalSendProtocol.Resume(id: offer.id, files: resumeEntries))) ?? Data()
        }
        connection.send(content: acceptData, completion: .contentProcessed { _ in })

        var fileProgress = offer.files.map { LocalFileProgress(index: $0.index, name: $0.name, size: $0.size, transferred: offsets[$0.index] ?? 0) }
        progress = LocalTransferProgress(
            transferId: offer.id,
            peerName: offer.sender,
            direction: .receiving,
            phase: .transferring,
            files: fileProgress
        )

        var buffer = startData
        if let firstNl = buffer.firstIndex(of: 0x0A) { buffer = Data(buffer[buffer.index(after: firstNl)...]) }

        var currentHandle: FileHandle?
        var currentIndex = -1
        var tracker = SpeedTracker()

        while !Task.isCancelled {
            if let chunk = try? await readChunkFromBuffer(&buffer, connection: connection) {
                if chunk.fileIndex != currentIndex {
                    currentHandle?.closeFile()
                    let entry = offer.files.first { $0.index == chunk.fileIndex }!
                    let dest = destRoot.appendingPathComponent(entry.relativePath)
                    try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        FileManager.default.createFile(atPath: dest.path, contents: nil)
                    }
                    currentHandle = try? FileHandle(forWritingTo: dest)
                    if chunk.offset > 0 { currentHandle?.seek(toFileOffset: UInt64(chunk.offset)) }
                    currentIndex = chunk.fileIndex
                }
                currentHandle?.write(chunk.data)
                let newOff = chunk.offset + Int64(chunk.data.count)
                offsets[chunk.fileIndex] = newOff
                if let idx = fileProgress.firstIndex(where: { $0.index == chunk.fileIndex }) {
                    fileProgress[idx].transferred = newOff
                }
                tracker.add(bytes: chunk.data.count)
                progress?.files = fileProgress
                progress?.speedBytesPerSec = tracker.bytesPerSec
                continue
            }

            if let (line, remainder) = extractLine(from: &buffer) {
                buffer = remainder
                guard let parsed = LocalSendProtocol.parseOp(line) else { continue }
                switch parsed.op {
                case "file_begin":
                    currentHandle?.closeFile()
                    let index = parsed.json["index"] as? Int ?? 0
                    let offset = parsed.json["offset"] as? Int64 ?? 0
                    let entry = offer.files.first { $0.index == index }!
                    let dest = destRoot.appendingPathComponent(entry.relativePath)
                    try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        FileManager.default.createFile(atPath: dest.path, contents: nil)
                    }
                    currentHandle = try? FileHandle(forWritingTo: dest)
                    if offset > 0 { currentHandle?.seek(toFileOffset: UInt64(offset)) }
                    currentIndex = index
                case "file_end":
                    currentHandle?.closeFile()
                    currentHandle = nil
                case "complete":
                    currentHandle?.closeFile()
                    progress?.phase = .completed
                    progress?.speedBytesPerSec = 0
                    resumeOffsets[offer.id] = offsets
                    connection.cancel()
                    return
                default: break
                }
            } else {
                guard let more = await receiveData(connection) else { break }
                buffer.append(more)
            }
        }
        currentHandle?.closeFile()
        if progress?.phase != .completed { progress?.phase = .paused }
    }

    // MARK: - Send

    private func sendTransfer(peer: LocalPeer, urls: [URL]) async {
        let transferId = UUID().uuidString
        var sources: [(index: Int, url: URL, name: String, size: Int64)] = []
        for (i, url) in urls.enumerated() {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .localizedNameKey])
            sources.append((i, url, values?.localizedName ?? url.lastPathComponent, Int64(values?.fileSize ?? 0)))
        }
        let files = sources.map { LocalSendProtocol.FileEntry(index: $0.index, name: $0.name, relativePath: $0.name, size: $0.size) }
        let offer = LocalSendProtocol.Offer(id: transferId, sender: friendlyName, files: files)
        var fileProgress = files.map { LocalFileProgress(index: $0.index, name: $0.name, size: $0.size, transferred: 0) }
        var offsets = resumeOffsets[transferId] ?? [:]

        progress = LocalTransferProgress(
            transferId: transferId,
            peerName: peer.name,
            direction: .sending,
            phase: .connecting,
            files: fileProgress
        )

        guard let port = NWEndpoint.Port(rawValue: UInt16(peer.port)) else { return }
        let host = NWEndpoint.Host(peer.host)
        let connection = NWConnection(host: host, port: port, using: .tcp)

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            connection.stateUpdateHandler = { state in
                if case .failed(let err) = state {
                    Task { @MainActor in
                        self.progress?.phase = .failed
                        self.progress?.error = err.localizedDescription
                    }
                    cont.resume()
                }
            }
            connection.start(queue: .global())
            connection.send(content: (try? LocalSendProtocol.encodeLine(offer)) ?? Data(), completion: .contentProcessed { _ in
                Task { @MainActor in
                    self.progress?.phase = .waitingAccept
                    await self.sendFiles(connection: connection, transferId: transferId, sources: sources, fileProgress: &fileProgress, offsets: &offsets)
                    cont.resume()
                }
            })
        }
    }

    private func sendFiles(
        connection: NWConnection,
        transferId: String,
        sources: [(index: Int, url: URL, name: String, size: Int64)],
        fileProgress: inout [LocalFileProgress],
        offsets: inout [Int: Int64]
    ) async {
        guard let acceptResult = await waitForAccept(on: connection, transferId: transferId) else { return }
        acceptResult.resumeOffsets.forEach { offsets[$0.key] = $0.value }
        guard acceptResult.accepted else {
            progress?.phase = .failed
            progress?.error = "Rejected"
            return
        }

        progress?.phase = .transferring
        var tracker = SpeedTracker()
        let chunkSize = LocalSendProtocol.chunkSize

        for src in sources {
            let start = offsets[src.index] ?? 0
            let begin = LocalSendProtocol.FileBegin(id: transferId, index: src.index, offset: start)
            connection.send(content: (try? LocalSendProtocol.encodeLine(begin)) ?? Data(), completion: .contentProcessed { _ in })

            guard let handle = try? FileHandle(forReadingFrom: src.url) else { continue }
            handle.seek(toFileOffset: UInt64(start))
            var offset = start
            while offset < src.size {
                let toRead = min(Int64(chunkSize), src.size - offset)
                guard let data = try? handle.read(upToCount: Int(toRead)), !data.isEmpty else { break }
                let chunkData = buildChunk(fileIndex: src.index, offset: offset, payload: data)
                await sendChunk(connection, data: chunkData)
                offset += Int64(data.count)
                offsets[src.index] = offset
                if let idx = fileProgress.firstIndex(where: { $0.index == src.index }) {
                    fileProgress[idx].transferred = offset
                }
                progress?.files = fileProgress
                tracker.add(bytes: data.count)
                progress?.speedBytesPerSec = tracker.bytesPerSec
            }
            handle.closeFile()

            let end = LocalSendProtocol.FileEnd(id: transferId, index: src.index)
            connection.send(content: (try? LocalSendProtocol.encodeLine(end)) ?? Data(), completion: .contentProcessed { _ in })
        }

        let done = LocalSendProtocol.Complete(id: transferId)
        connection.send(content: (try? LocalSendProtocol.encodeLine(done)) ?? Data(), completion: .contentProcessed { _ in })
        progress?.phase = .completed
        progress?.speedBytesPerSec = 0
        resumeOffsets[transferId] = offsets
        connection.cancel()
    }

    private func waitForAccept(on connection: NWConnection, transferId: String) async -> (accepted: Bool, resumeOffsets: [Int: Int64])? {
        await withCheckedContinuation { cont in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                guard let data, let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let parsed = LocalSendProtocol.parseOp(line) else {
                    cont.resume(returning: nil)
                    return
                }
                switch parsed.op {
                case "accept": cont.resume(returning: (true, [:]))
                case "resume":
                    cont.resume(returning: (true, LocalSendProtocol.resumeOffsets(from: parsed.json)))
                case "reject": cont.resume(returning: (false, [:]))
                default: cont.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Helpers

    private func receiveDirectory() -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let dir = downloads.appendingPathComponent("SyncBridge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func openReceiveFolder() {
        NSWorkspace.shared.open(receiveDirectory())
    }

    private func receiveData(_ connection: NWConnection) async -> Data? {
        await withCheckedContinuation { cont in
            connection.receive(minimumIncompleteLength: 1, maximumLength: LocalSendProtocol.chunkSize + 64) { data, _, _, _ in
                cont.resume(returning: data)
            }
        }
    }

    private func sendChunk(_ connection: NWConnection, data: Data) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            connection.send(content: data, completion: .contentProcessed { _ in cont.resume() })
        }
    }

    private func buildChunk(fileIndex: Int, offset: Int64, payload: Data) -> Data {
        var out = Data([0x53, 0x42, 0x4C, 0x53])
        var idx = UInt16(fileIndex).bigEndian
        var off = offset.bigEndian
        var len = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &idx) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: &off) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    private func extractLine(from buffer: inout Data) -> (String, Data)? {
        guard let idx = buffer.firstIndex(of: 0x0A) else { return nil }
        let lineData = buffer[..<idx]
        let remainder = Data(buffer[buffer.index(after: idx)...])
        buffer = remainder
        guard let line = String(data: lineData, encoding: .utf8) else { return nil }
        return (line, remainder)
    }

    private func readChunkFromBuffer(_ buffer: inout Data, connection: NWConnection) async throws -> (fileIndex: Int, offset: Int64, data: Data)? {
        guard buffer.count >= 18 else { return nil }
        guard buffer.prefix(4).elementsEqual([0x53, 0x42, 0x4C, 0x53]) else { return nil }
        let fileIndex = Int(buffer[4..<6].withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
        let offset = buffer[6..<14].withUnsafeBytes { $0.load(as: Int64.self).bigEndian }
        let length = Int(buffer[14..<18].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        if buffer.count < 18 + length {
            if let more = await receiveData(connection) { buffer.append(more) }
            if buffer.count < 18 + length { return nil }
        }
        let payload = Data(buffer[18..<(18 + length)])
        buffer = Data(buffer[(18 + length)...])
        return (fileIndex, offset, payload)
    }
}

private struct SpeedTracker {
    private var window: [(Date, Int)] = []

    mutating func add(bytes: Int) {
        let now = Date()
        window.append((now, bytes))
        window.removeAll { now.timeIntervalSince($0.0) > 2 }
    }

    var bytesPerSec: Int64 {
        guard window.count >= 2 else { return 0 }
        let span = window.last!.0.timeIntervalSince(window.first!.0)
        guard span > 0 else { return 0 }
        let total = window.reduce(0) { $0 + $1.1 }
        return Int64(Double(total) / span)
    }
}

