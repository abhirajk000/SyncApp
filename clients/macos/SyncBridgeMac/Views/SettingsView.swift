// SettingsView.swift
// Standard macOS Settings (Preferences) window — Cmd+, or menu bar right-click.

import SwiftUI
import ServiceManagement

struct SettingsView: View {

    @EnvironmentObject var appState: AppState
    @AppStorage("syncEnabled")         private var syncEnabled = true
    @AppStorage("autoApplyRemoteClipboard") private var autoApplyRemoteClipboard = true
    @AppStorage("autoSyncImages")     private var autoSyncImages = true
    @AppStorage("showNotifications")   private var showNotifications = true
    @AppStorage("historyLimit")        private var historyLimit = 100
    @AppStorage("startHidden")         private var startHidden = false
    @State private var launchAtLogin = false

    var embedded = false

    var body: some View {
        Group {
            if embedded {
                ScrollView {
                    settingsForm
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                settingsForm
                    .frame(width: 440, height: 500)
            }
        }
        .tint(DS.Color.primary)
        .onAppear {
            launchAtLogin = LoginItemService.shared.isEnabled
        }
    }

    private var settingsForm: some View {
        Form {
            // ── Sync ──────────────────────────────────────────────────────────
            Section("Clipboard Sync") {
                Toggle("Sync clipboard automatically", isOn: $syncEnabled)
                    .onChange(of: syncEnabled) { _, enabled in
                        appState.clipboardMonitor.autoSyncEnabled = enabled
                        if enabled { appState.clipboardMonitor.start() }
                        else       { appState.clipboardMonitor.stop() }
                    }

                Toggle("Auto apply remote clipboard", isOn: $autoApplyRemoteClipboard)

                Toggle("Auto sync images", isOn: $autoSyncImages)
                    .onChange(of: autoSyncImages) { _, enabled in
                        appState.clipboardMonitor.autoSyncImagesEnabled = enabled
                    }

                Toggle("Show clipboard notifications", isOn: $showNotifications)

                Stepper("Keep last \(historyLimit) entries", value: $historyLimit, in: 10...500, step: 10)
            }

            Section("Background") {
                Text("Closing the window keeps SyncBridge running in the menu bar. Use Quit SyncBridge to stop.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Start hidden (menu bar only)", isOn: $startHidden)
            }

            // ── Startup ───────────────────────────────────────────────────────
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LoginItemService.shared.setEnabled(enabled)
                    }
            }

            // ── Network ───────────────────────────────────────────────────────
            if case .loggedIn = appState.authState {
                NetworkSettingsView()
            }

            // ── Devices ───────────────────────────────────────────────────────
            if case .loggedIn = appState.authState {
                Section("Devices") {
                    Button("Pair a new device") {
                        Task { await appState.initiatePairing() }
                    }
                }
            }

            // ── Account ───────────────────────────────────────────────────────
            if case .loggedIn = appState.authState {
                Section("Account") {
                    if let deviceId = KeychainService.shared.deviceId {
                        LabeledContent("Device ID") {
                            Text(deviceId)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    Button("Sign Out", role: .destructive) {
                        Task { await appState.logout() }
                    }
                }
            }

            // ── About ─────────────────────────────────────────────────────────
            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Build",   value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                Link("View on GitHub", destination: URL(string: "https://github.com/your-org/syncbridge")!)
            }
        }
        .formStyle(.grouped)
        .padding(embedded ? DS.Space.md : 0)
    }
}
