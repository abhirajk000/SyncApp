// SyncBridgeIOSApp.swift
// SwiftUI app entry — minimal Phase D+E scaffold.

import SwiftUI

@main
struct SyncBridgeIOSApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                ContentPlaceholderView()
                    .environmentObject(appState)
            } else {
                LoginView()
                    .environmentObject(appState)
            }
        }
    }
}

/// Placeholder main view — replace with clipboard/files tabs in Phase D+E.
struct ContentPlaceholderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("Unlocked")
                    .font(.headline)
                Text("Add Clipboard and Files views here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Log out") {
                    appState.logout()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("SyncBridge")
        }
    }
}
