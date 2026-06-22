// SyncBridgeIOSApp.swift
// SwiftUI app — fast launch, latest clipboard on open, WS while active.

import SwiftUI

@main
struct SyncBridgeIOSApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var wsClient = WSClient()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.isAuthenticated {
                    MainView()
                        .environmentObject(appState)
                        .environmentObject(wsClient)
                } else {
                    LoginView()
                        .environmentObject(appState)
                }

                if let popup = appState.latestClipboardPopup {
                    LatestClipboardView(
                        entry: popup,
                        onDismiss: { appState.latestClipboardPopup = nil }
                    )
                }
            }
            .onChange(of: appState.isAuthenticated) { _, authed in
                if authed {
                    appState.startClipboardMonitor()
                    Task { await appState.loadLatestClipboard() }
                    connectWS()
                } else {
                    appState.stopClipboardMonitor()
                    wsClient.disconnect()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, appState.isAuthenticated {
                    appState.startClipboardMonitor()
                    Task { await appState.loadLatestClipboard() }
                    connectWS()
                } else if phase == .background {
                    appState.stopClipboardMonitor()
                    wsClient.disconnect()
                }
            }
            .onAppear {
                wsClient.onClipboardNew = { entry in
                    appState.latestClipboardPopup = entry
                    appState.applyEntryToPasteboard(entry)
                }
                if appState.isAuthenticated {
                    appState.startClipboardMonitor()
                    Task { await appState.loadLatestClipboard() }
                    connectWS()
                }
            }
        }
    }

    private func connectWS() {
        guard let token = appState.accessToken else { return }
        wsClient.connect(accessToken: token, serverURL: appState.serverURL)
    }
}

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Latest") {
                    if let latest = appState.latestClipboardPopup {
                        Text(latest.content)
                            .lineLimit(4)
                    } else {
                        Text("Open app to fetch latest clipboard")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Log out", role: .destructive) {
                        appState.logout()
                    }
                }
            }
            .navigationTitle("SyncBridge")
        }
    }
}

#if os(iOS)
import UIKit
#endif
