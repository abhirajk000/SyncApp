// DevicesView.swift — Trusted devices (system names only)

import SwiftUI

struct DevicesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let onBack: () -> Void

    @State private var devices: [DeviceItem] = []
    @State private var loading = true
    @State private var removeTarget: DeviceItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space4) {
                HStack(spacing: SyncTokens.space2) {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left").font(SyncFont.body().weight(.semibold))
                    }
                    Text("Devices").font(SyncFont.title2xl())
                }

                if loading {
                    AppSkeleton(rows: 4)
                } else {
                    if let current = devices.first(where: { $0.isCurrent }) {
                        AppSectionTitle(title: "This device")
                        ContainerGroup {
                            trustedDeviceContent(current)
                        }
                    }

                    AppSectionTitle(title: "Trusted devices")
                    let others = devices.filter { !$0.isCurrent }
                    if others.isEmpty {
                        AppEmptyState(
                            illustration: .devices,
                            title: "No other devices",
                            description: "Pair from your Mac or web settings to see them here."
                        )
                    } else {
                        ContainerGroup {
                            ForEach(Array(others.enumerated()), id: \.element.id) { index, device in
                                ContainerGroupItem(showDivider: index < others.count - 1) {
                                    trustedDeviceContent(
                                        device,
                                        showTrust: !isDeviceTrusted(device),
                                        showRemove: true
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)
            .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
        }
        .task { await load() }
        .alert("Remove device", isPresented: Binding(get: { removeTarget != nil }, set: { if !$0 { removeTarget = nil } })) {
            Button("Remove", role: .destructive) {
                guard let target = removeTarget else { return }
                Task {
                    guard let token = appState.accessToken else { return }
                    try? await DeviceAPI.revokeDevice(serverURL: appState.serverURL, accessToken: token, id: target.id)
                    removeTarget = nil
                    await load()
                }
            }
            Button("Cancel", role: .cancel) { removeTarget = nil }
        } message: {
            if let target = removeTarget {
                Text("Remove \"\(target.name)\" from your account?")
            }
        }
    }

    @ViewBuilder
    private func trustedDeviceContent(_ device: DeviceItem, showTrust: Bool = false, showRemove: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: SyncTokens.space3) {
                HStack(spacing: SyncTokens.space2) {
                    Circle()
                        .fill(device.online ? SyncTokens.teal : SyncTokens.slateMuted)
                        .frame(width: SyncTokens.space2, height: SyncTokens.space2)
                    Text(device.name).font(SyncFont.body().weight(.semibold))
                }
                Text(platformLabel(device.platform) + (device.isCurrent ? " · This device" : ""))
                    .font(SyncFont.caption())
                    .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))
                Text(device.lastSeenAt.map { relativeTime($0) } ?? "Never seen")
                    .font(SyncFont.caption())
                    .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))
                HStack(spacing: SyncTokens.space2) {
                    if showTrust {
                        GhostButton(title: "Trust") {
                            Task {
                                guard let token = appState.accessToken else { return }
                                try? await DeviceAPI.trustDevice(serverURL: appState.serverURL, accessToken: token, id: device.id)
                                await load()
                            }
                        }
                    }
                    if showRemove {
                        GhostButton(title: "Remove") { removeTarget = device }
                    }
                }
        }
    }

    private func platformLabel(_ platform: String) -> String {
        switch platform {
        case "macos": return "macOS"
        case "ios": return "iOS"
        case "web": return "Web"
        case "android": return "Android"
        default: return platform.capitalized
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let token = appState.accessToken else { return }
        if let list = try? await DeviceAPI.fetchDevices(serverURL: appState.serverURL, accessToken: token) {
            devices = list
        }
    }
}
