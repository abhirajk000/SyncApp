// NetworkManager.swift — LAN discovery, routing, diagnostics logging

import Foundation
import Network
import Darwin

struct SignalPeerEvent: Equatable {
    let deviceId: String
    let addrs: [String]
    let port: Int
    let at: String
}

struct TransferLogEntry: Identifiable {
    let id: String
    let at: String
    let name: String
    let method: String
    let fallbackReason: String?
    let bytesPerSec: Int64?
    let peerDeviceId: String?
}

struct EnrichedPeer: Identifiable {
    let deviceId: String
    let addrs: [String]
    let port: Int
    let updatedAt: String
    let name: String
    let platform: String
    var id: String { deviceId }
}

@MainActor
final class NetworkManager: ObservableObject {

    @Published private(set) var diagnostics: DiagnosticsResponse?
    @Published private(set) var peers: [LocalPeerResponse] = []
    @Published private(set) var enrichedPeers: [EnrichedPeer] = []
    @Published private(set) var lastSignalTime: String?
    @Published private(set) var nearbyAlert: SignalPeerEvent?
    @Published private(set) var currentTransferMode = "Cloud Relay"
    @Published private(set) var lastSyncAt: String?
    @Published private(set) var latencyMs: Int?
    @Published private(set) var transferLogs: [TransferLogEntry] = []
    @Published private(set) var loading = false
    @Published private(set) var errorMessage: String?

    private var knownPeerIds = Set<String>()

    var wsConnected = false {
        didSet { updateTransferLabel() }
    }

    private let auth: AuthService
    private var refreshTask: Task<Void, Never>?
    private var advertiseTask: Task<Void, Never>?
    private var clientIp = ""
    private var uiActive = true

    init(auth: AuthService) {
        self.auth = auth
    }

    /// Slow or skip LAN polling when the app is not active (saves CPU/battery).
    func setUiActive(_ active: Bool) {
        uiActive = active
        if active {
            Task { await refresh() }
        }
    }

    func start() {
        stop()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                if self?.uiActive == true {
                    await self?.refresh()
                }
                let delayNs: UInt64 = self?.uiActive == true ? 15_000_000_000 : 300_000_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
        advertiseTask = Task { [weak self] in
            while !Task.isCancelled {
                let delayNs: UInt64 = self?.uiActive == true ? 60_000_000_000 : 300_000_000_000
                try? await Task.sleep(nanoseconds: delayNs)
                if self?.uiActive == true {
                    await self?.advertiseOnce()
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        advertiseTask?.cancel()
        refreshTask = nil
        advertiseTask = nil
        diagnostics = nil
        peers = []
        enrichedPeers = []
        nearbyAlert = nil
        knownPeerIds.removeAll()
        wsConnected = false
    }

    func markSync() {
        lastSyncAt = ISO8601DateFormatter().string(from: Date())
    }

    func dismissNearbyAlert() {
        nearbyAlert = nil
    }

    /// Returns true the first time we see this peer (for optional notification).
    @discardableResult
    func handleSignalPeer(deviceId: String, addrs: [String], port: Int) -> Bool {
        let isNew = !knownPeerIds.contains(deviceId)
        if isNew { knownPeerIds.insert(deviceId) }
        let event = SignalPeerEvent(
            deviceId: deviceId,
            addrs: addrs,
            port: port,
            at: ISO8601DateFormatter().string(from: Date())
        )
        lastSignalTime = event.at
        if isNew { nearbyAlert = event }
        return isNew
    }

    func resolveUploadRoute(
        fileSizeBytes: Int,
        fileCount: Int = 1,
        isFolder: Bool = false
    ) -> (transferMode: String, route: String, fallback: String?, peerId: String?) {
        let r = FileRouting.resolve(fileSizeBytes: fileSizeBytes, fileCount: fileCount, isFolder: isFolder)
        return (r.transferMode, r.route, r.fallback, nil)
    }

    func logTransfer(name: String, method: String, fallback: String?, bytesPerSec: Int64?, peerId: String?) {
        let entry = TransferLogEntry(
            id: UUID().uuidString,
            at: ISO8601DateFormatter().string(from: Date()),
            name: name,
            method: method,
            fallbackReason: fallback,
            bytesPerSec: bytesPerSec,
            peerDeviceId: peerId
        )
        transferLogs = ([entry] + transferLogs).prefix(50).map { $0 }
    }

    func refresh() async {
        loading = true
        errorMessage = nil
        let t0 = CFAbsoluteTimeGetCurrent()
        do {
            let diag = try await auth.fetchDiagnostics()
            diagnostics = diag
            clientIp = diag.clientIp
            await advertiseOnce()
            let localAddrs = Self.localIPv4Addresses()
            let query = (localAddrs + [diag.clientIp].filter { !$0.isEmpty }).joined(separator: ",")
            let peerResp = try await auth.fetchLocalPeers(addrs: query)
            peers = peerResp.peers
            let devices = try await auth.listDevices().devices
            enrichedPeers = enrich(peers: peerResp.peers, devices: devices)
            latencyMs = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
            loading = false
            updateTransferLabel()
        } catch {
            loading = false
            errorMessage = error.localizedDescription
        }
    }

    private func advertiseOnce() async {
        let addrs = Self.localIPv4Addresses()
        guard !addrs.isEmpty else { return }
        _ = try? await auth.advertiseLocalAddrs(addrs)
    }

    private func updateTransferLabel() {
        currentTransferMode = wsConnected ? "Automatic" : "Offline"
    }

    private func enrich(peers: [LocalPeerResponse], devices: [DeviceResponse]) -> [EnrichedPeer] {
        let byId = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        return peers.map { p in
            let dev = byId[p.deviceId]
            return EnrichedPeer(
                deviceId: p.deviceId,
                addrs: p.addrs,
                port: p.port,
                updatedAt: p.updatedAt,
                name: dev?.name ?? String(p.deviceId.prefix(8)) + "…",
                platform: dev?.platform ?? "unknown"
            )
        }
    }

    static func localIPv4Addresses() -> [String] {
        var addrs: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            guard iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: iface.ifa_name)
            if name == "lo0" { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: hostname)
            if !ip.isEmpty { addrs.append(ip) }
        }
        return addrs
    }

    static func platformLabel(_ platform: String) -> String {
        switch platform {
        case "macos": return "Mac"
        case "android": return "Android"
        case "ios": return "iPhone"
        case "web": return "Web"
        default: return platform
        }
    }
}
