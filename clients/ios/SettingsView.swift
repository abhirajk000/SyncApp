// SettingsView.swift — Matches Android SettingsScreen.kt

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var wsClient: WSClient
    var onOpenDevices: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space6) {
                AppSectionTitle(title: "Devices")
                AppCard {
                    SettingsLinkRow(
                        icon: "ipad.and.iphone",
                        title: "Trusted devices",
                        subtitle: "Pair, rename, trust, or remove devices",
                        action: onOpenDevices
                    )
                }

                AppSectionTitle(title: "Clipboard")
                AppCard {
                    ClipboardSettingsSection()
                }

                AppSectionTitle(title: "Clipboard access")
                AppCard {
                    VStack(alignment: .leading, spacing: SyncTokens.space3) {
                        Text("Automatic sync from Messages & other apps")
                            .font(SyncFont.body().weight(.semibold))
                        Text("iOS 16+ requires paste permission. The setting only appears after SyncBridge asks once.")
                            .font(SyncFont.bodySm())
                            .foregroundStyle(SyncTokens.slateSecondary)
                        Text("1. Tap “Enable paste access” below → tap Allow on the popup\n2. Then open Settings → Apps → SyncBridge → Paste from Other Apps → Allow")
                            .font(SyncFont.bodySm())
                            .foregroundStyle(SyncTokens.slateMuted)
                        PrimaryButton(text: "Enable paste access") {
                            Task { await appState.requestPasteAccess() }
                        }
                        Text("Or tap Paste — works without changing Settings:")
                            .font(SyncFont.bodySm())
                            .foregroundStyle(SyncTokens.slateMuted)
                            .padding(.top, SyncTokens.space1)
                        ClipboardSyncPasteButton()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }

                AppSectionTitle(title: "Connection")
                AppCard {
                    HStack(spacing: SyncTokens.space3) {
                        Circle()
                            .fill(wsClient.isConnected ? SyncTokens.success : SyncTokens.slateMuted)
                            .frame(width: SyncTokens.space2, height: SyncTokens.space2)
                        Text(wsClient.isConnected
                             ? "Connected — clipboard sync active"
                             : "Offline — reconnecting…")
                            .font(SyncFont.bodySm())
                            .foregroundStyle(SyncTokens.slateSecondary)
                    }
                }

                AppSectionTitle(title: "About")
                AppCard {
                    Text("SyncBridge")
                        .font(SyncFont.titleLg())
                    Text("Instant clipboard sync across your devices.")
                        .font(SyncFont.bodySm())
                        .foregroundStyle(SyncTokens.slateSecondary)
                        .padding(.top, SyncTokens.space2)
                    Text("Version 1.0.0")
                        .font(SyncFont.caption())
                        .foregroundStyle(SyncTokens.slateMuted)
                        .padding(.top, SyncTokens.space3)
                }

                AppSectionTitle(title: "Account")
                AppCard {
                    DestructiveFullWidthButton(title: "Log out", icon: "rectangle.portrait.and.arrow.right") {
                        appState.logout()
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)
            .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
        }
    }
}

private struct ClipboardSettingsSection: View {
    @State private var autoSync = ClipboardSettings.autoSyncClipboard
    @State private var autoApply = ClipboardSettings.autoApplyRemoteClipboard
    @State private var autoImages = ClipboardSettings.autoSyncImages
    @State private var showNotifications = ClipboardSettings.showClipboardNotifications

    var body: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space3) {
            ClipboardSettingToggle(title: "Auto sync clipboard", subtitle: "Upload copies from this device", isOn: $autoSync)
                .onChange(of: autoSync) { ClipboardSettings.autoSyncClipboard = $0 }
            ClipboardSettingToggle(title: "Auto apply remote clipboard", subtitle: "Writes synced clipboard when you open SyncBridge or while it is active. iOS cannot update clipboard in the background.", isOn: $autoApply)
                .onChange(of: autoApply) { ClipboardSettings.autoApplyRemoteClipboard = $0 }
            ClipboardSettingToggle(title: "Auto sync images", subtitle: "Include photos and screenshots", isOn: $autoImages)
                .onChange(of: autoImages) { ClipboardSettings.autoSyncImages = $0 }
            ClipboardSettingToggle(title: "Show clipboard notifications", subtitle: "Alert when clipboard updates from another device", isOn: $showNotifications)
                .onChange(of: showNotifications) { ClipboardSettings.showClipboardNotifications = $0 }
        }
    }
}

private struct ClipboardSettingToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SyncFont.body().weight(.semibold))
                Text(subtitle)
                    .font(SyncFont.bodySm())
                    .foregroundStyle(SyncTokens.slateSecondary)
            }
        }
        .tint(SyncTokens.teal)
    }
}
