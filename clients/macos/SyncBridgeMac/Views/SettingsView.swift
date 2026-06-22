// SettingsView.swift
// Standard macOS Settings (Preferences) window — Cmd+, or menu bar right-click.

import SwiftUI
import ServiceManagement

struct SettingsView: View {

    @EnvironmentObject var appState: AppState
    @AppStorage("syncEnabled")         private var syncEnabled = true
    @AppStorage("showNotifications")   private var showNotifications = true
    @AppStorage("historyLimit")        private var historyLimit = 100
    @State private var launchAtLogin = false
    @State private var serverURL = KeychainService.shared.serverURL

    var body: some View {
        Form {
            // ── Server ────────────────────────────────────────────────────────
            Section("Server") {
                HStack {
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        KeychainService.shared.serverURL = serverURL
                        APIClient.shared.baseURL = serverURL
                    }
                    .buttonStyle(.bordered)
                }
                Text("WebSocket and API endpoint for your SyncBridge server.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // ── Sync ──────────────────────────────────────────────────────────
            Section("Clipboard Sync") {
                Toggle("Enable clipboard sync", isOn: $syncEnabled)
                    .onChange(of: syncEnabled) { _, enabled in
                        if enabled { appState.clipboardMonitor.start() }
                        else       { appState.clipboardMonitor.stop() }
                    }

                Toggle("Show notifications on sync", isOn: $showNotifications)

                Stepper("Keep last \(historyLimit) entries", value: $historyLimit, in: 10...500, step: 10)
            }

            // ── Startup ───────────────────────────────────────────────────────
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LoginItemService.shared.setEnabled(enabled)
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
        .padding()
        .frame(width: 440, height: 500)
        .onAppear {
            launchAtLogin = LoginItemService.shared.isEnabled
        }
    }
}
