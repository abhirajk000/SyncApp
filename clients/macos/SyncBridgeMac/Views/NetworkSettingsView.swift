// NetworkSettingsView.swift — Settings → Network

import SwiftUI
import Darwin

struct NetworkSettingsView: View {

    @EnvironmentObject var appState: AppState

    @State private var diagnostics: DiagnosticsResponse?
    @State private var peers: [LocalPeerResponse] = []
    @State private var errorMessage: String?
    @State private var timer: Timer?

    private var wsConnected: Bool {
        if case .connected = appState.syncStatus { return true }
        return false
    }

    var body: some View {
        Group {
            if let errorMessage {
                Text(errorMessage).font(DS.Font.caption()).foregroundStyle(DS.Color.danger)
            }

            Section("Status") {
                LabeledContent("Server") {
                    Text(diagnostics != nil ? "Online" : "Checking…")
                        .foregroundStyle(diagnostics != nil ? DS.Color.success : .secondary)
                }
                if let v = diagnostics?.serverVersion, !v.isEmpty {
                    LabeledContent("Version", value: v)
                }
                LabeledContent("WebSocket") {
                    Text(wsConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(wsConnected ? DS.Color.success : DS.Color.warning)
                }
                LabeledContent("File routing", value: wsConnected ? "Automatic" : "Offline")
                LabeledContent("Clipboard", value: "Cloud relay (always)")
                LabeledContent("LAN peers", value: "\(diagnostics?.localPeers ?? peers.count)")
                LabeledContent("mDNS", value: diagnostics?.mdnsEnabled == true ? "Enabled" : "Disabled")
                LabeledContent("Your IP") {
                    Text(diagnostics?.clientIp ?? "—")
                        .font(.system(.caption, design: .monospaced))
                }
            }

            Section("Routing policy") {
                Text("Clipboard text and images always use cloud relay for reliability. Files under 100 MB use relay. Larger files, folders, and multi-file uploads attempt WebRTC with automatic relay fallback. You never choose a transfer method.")
                    .font(DS.Font.caption())
                    .foregroundStyle(.secondary)
            }

            Section("Nearby devices") {
                if peers.isEmpty {
                    Text("No devices on the same network right now.")
                        .font(DS.Font.caption())
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(peers) { peer in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(peer.deviceId.prefix(8)) + "…")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                            Text(peer.addrs.joined(separator: ", ") + (peer.port > 0 ? ":\(peer.port)" : ""))
                                .font(DS.Font.caption())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Auto-refreshes every 15 seconds")
                    .font(DS.Font.caption())
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            Task { await refresh() }
            timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
                Task { await refresh() }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func refresh() async {
        guard case .loggedIn = appState.authState else { return }
        do {
            let auth = AuthService(api: .shared)
            let diag = try await auth.fetchDiagnostics()
            diagnostics = diag
            let localAddrs = LanAddressHelper.localIPv4Addresses()
            if !localAddrs.isEmpty {
                try? await auth.advertiseLocalAddrs(localAddrs)
            }
            let query = (localAddrs + [diag.clientIp]).filter { !$0.isEmpty }.joined(separator: ",")
            peers = try await auth.fetchLocalPeers(addrs: query).peers
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum LanAddressHelper {
    static func localIPv4Addresses() -> [String] {
        var addrs: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let sa = ptr.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: hostname)
                if !ip.isEmpty { addrs.append(ip) }
            }
        }
        return Array(Set(addrs))
    }
}
