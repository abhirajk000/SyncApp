// SyncBridgeIOSApp.swift — App entry matching Android MainActivity flow

import SwiftUI
import UIKit

@main
struct SyncBridgeIOSApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var wsClient = WSClient()
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundDisconnectTask: UIBackgroundTaskIdentifier = .invalid

    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.isAuthenticated {
                    MainShell()
                        .environmentObject(appState)
                        .environmentObject(wsClient)
                } else {
                    LoginView()
                        .environmentObject(appState)
                }

                if let popup = appState.latestClipboardPopup {
                    LatestClipboardView(entry: popup) {
                        appState.dismissLatestClipboardPopup()
                    }
                    .environmentObject(appState)
                }
            }
            .preferredColorScheme(nil)
            .onChange(of: appState.isAuthenticated) { authed in
                if authed {
                    Task {
                        connectWS()
                        appState.resetLatestPopupSession()
                        await appState.catchUpRemoteClipboard()
                        await appState.presentLatestClipboardPopupIfNeeded()
                        await appState.refreshAll()
                    }
                } else {
                    wsClient.disconnect()
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active, appState.isAuthenticated {
                    appState.startClipboardMonitor()
                    Task {
                        await appState.syncForegroundClipboard()
                        if appState.clipboardPastePending {
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            await appState.syncForegroundClipboard()
                        }
                        await appState.catchUpRemoteClipboard()
                        await appState.presentLatestClipboardPopupIfNeeded()
                        await appState.refreshClipboardHistory()
                        await appState.refreshFiles()
                    }
                    connectWS()
                } else if phase == .background {
                    appState.stopClipboardMonitor()
                    scheduleBackgroundDisconnect()
                }
            }
            .onAppear {
                if appState.isAuthenticated {
                    Task {
                        await appState.catchUpRemoteClipboard()
                    }
                    connectWS()
                }
                wsClient.onClipboardNew = { entry in
                    Task { await appState.handleRemoteClipboardPush(entry) }
                }
                wsClient.onClipboardPin = { entryId, pinned in
                    appState.handleClipboardPin(entryId: entryId, pinned: pinned)
                }
                wsClient.onFilesUpdated = {
                    Task { await appState.refreshFiles() }
                }
            }
        }
    }

    private func connectWS() {
        guard let token = appState.accessToken else { return }
        if backgroundDisconnectTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundDisconnectTask)
            backgroundDisconnectTask = .invalid
        }
        wsClient.connect(accessToken: token, serverURL: appState.serverURL)
    }

    /// Keep WS alive briefly after backgrounding so a just-copied Mac clip can still land.
    private func scheduleBackgroundDisconnect() {
        if backgroundDisconnectTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundDisconnectTask)
        }
        backgroundDisconnectTask = UIApplication.shared.beginBackgroundTask {
            wsClient.disconnect()
            if backgroundDisconnectTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundDisconnectTask)
                backgroundDisconnectTask = .invalid
            }
        }
        Task {
            try? await Task.sleep(nanoseconds: 28_000_000_000)
            wsClient.disconnect()
            if backgroundDisconnectTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundDisconnectTask)
                backgroundDisconnectTask = .invalid
            }
        }
    }
}
