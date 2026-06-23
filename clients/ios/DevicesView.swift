// DevicesView.swift — Matches Android DevicesScreen.kt

import SwiftUI

struct DevicesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let onBack: () -> Void

    @State private var devices: [DeviceItem] = []
    @State private var loading = true
    @State private var renameTarget: DeviceItem?
    @State private var renameValue = ""
    @State private var saving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space4) {
                HStack(spacing: SyncTokens.space2) {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text("Devices")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }

                if loading {
                    ProgressView().frame(maxWidth: .infinity)
                }

                if let current = devices.first(where: { $0.isCurrent }) {
                    AppSectionTitle(title: "This device")
                    deviceCard(current, showActions: true)
                }

                AppSectionTitle(title: "Trusted devices")
                let others = devices.filter { !$0.isCurrent }
                if others.isEmpty {
                    AppCard {
                        Text("No other devices yet. Pair from your Mac or web settings.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))
                    }
                } else {
                    ForEach(others) { device in
                        deviceCard(
                            device,
                            showActions: true,
                            showTrust: !isDeviceTrusted(device),
                            showRemove: true
                        )
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)
            .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
        }
        .task { await load() }
        .alert("Rename device", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Device name", text: $renameValue)
            Button("Save") {
                guard let target = renameTarget else { return }
                Task {
                    saving = true
                    defer { saving = false }
                    guard let token = appState.accessToken else { return }
                    try? await DeviceAPI.renameDevice(
                        serverURL: appState.serverURL,
                        accessToken: token,
                        id: target.id,
                        name: renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    renameTarget = nil
                    await load()
                }
            }
            .disabled(saving || renameValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
    }

    @ViewBuilder
    private func deviceCard(
        _ device: DeviceItem,
        showActions: Bool,
        showTrust: Bool = false,
        showRemove: Bool = false
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: SyncTokens.space3) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(device.online ? SyncTokens.teal : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(device.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                Text(platformLabel(device.platform) + (device.isCurrent ? " · This device" : ""))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))
                Text(device.lastSeenAt.map { relativeTime($0) } ?? "Never seen")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))

                if showActions {
                    HStack(spacing: SyncTokens.space2) {
                        Button("Rename") {
                            renameTarget = device
                            renameValue = device.name
                        }
                        .buttonStyle(.bordered)
                        if showTrust {
                            Button("Trust") {
                                Task {
                                    guard let token = appState.accessToken else { return }
                                    try? await DeviceAPI.trustDevice(
                                        serverURL: appState.serverURL,
                                        accessToken: token,
                                        id: device.id
                                    )
                                    await load()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        if showRemove {
                            Button("Remove") {
                                Task {
                                    guard let token = appState.accessToken else { return }
                                    try? await DeviceAPI.revokeDevice(
                                        serverURL: appState.serverURL,
                                        accessToken: token,
                                        id: device.id
                                    )
                                    await load()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
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
