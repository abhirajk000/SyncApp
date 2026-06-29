// LocalSendDiscovery.swift — mDNS advertise + browse via Network.framework

import Foundation
import Network
import UIKit

@MainActor
final class LocalSendDiscovery: ObservableObject {
    @Published private(set) var peers: [LocalPeer] = []

    let deviceId: String
    let friendlyName: String

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]

    init(deviceId: String, friendlyName: String) {
        self.deviceId = deviceId
        self.friendlyName = friendlyName
    }

    func start(port: UInt16, onReady: @escaping (UInt16) -> Void) throws {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener

        listener.service = NWListener.Service(
            name: "SyncBridge-\(deviceId.prefix(8))",
            type: LocalSendProtocol.serviceType,
            domain: nil,
            txtRecord: nil
        )

        listener.stateUpdateHandler = { state in
            if case .ready = state, let p = listener.port?.rawValue {
                onReady(p)
            }
        }

        listener.newConnectionHandler = { _ in }
        listener.start(queue: .global(qos: .userInitiated))

        let browser = NWBrowser(for: .bonjour(type: LocalSendProtocol.serviceType, domain: nil), using: params)
        self.browser = browser
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleBrowseResults(results)
            }
        }
        browser.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        browser?.cancel()
        listener?.cancel()
        browser = nil
        listener = nil
        peers = []
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var found: [LocalPeer] = []
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            if name.contains(String(deviceId.prefix(8))) { continue }

            let id = name
            if id == deviceId { continue }
            let peerName = name
            let platform = "unknown"

            if case let .hostPort(host, port) = result.endpoint {
                found.append(LocalPeer(id: id, name: peerName, platform: platform, host: "\(host)", port: Int(port.rawValue)))
            } else {
                resolveEndpoint(result.endpoint, id: id, name: peerName, platform: platform)
            }
        }
        if !found.isEmpty {
            mergePeers(found)
        }
    }

    private func resolveEndpoint(_ endpoint: NWEndpoint, id: String, name: String, platform: String) {
        let conn = NWConnection(to: endpoint, using: .tcp)
        connections[id] = conn
        conn.stateUpdateHandler = { [weak self] state in
            guard case .ready = state,
                  case let .hostPort(host, port) = conn.currentPath?.remoteEndpoint else { return }
            Task { @MainActor in
                self?.mergePeers([LocalPeer(id: id, name: name, platform: platform, host: "\(host)", port: Int(port.rawValue))])
            }
            conn.cancel()
        }
        conn.start(queue: .global())
    }

    private func mergePeers(_ incoming: [LocalPeer]) {
        var map = Dictionary(uniqueKeysWithValues: peers.map { ($0.id, $0) })
        for p in incoming { map[p.id] = p }
        peers = map.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func loadDeviceId() -> String {
        let key = "local_send_device_id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    static func friendlyDeviceName() -> String {
        UIDevice.current.name
    }
}

