// MainShell.swift — Authenticated app shell

import SwiftUI

struct MainShell: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var wsClient: WSClient

    @State private var selectedTab: MainTab = .clipboard
    @State private var settingsSubpage = "main"
    @State private var showConnMenu = false

    var body: some View {
        AppShell(
            selectedTab: selectedTab,
            connected: wsClient.isConnected,
            refreshing: appState.isRefreshing,
            onRefresh: { Task { await appState.refreshAll() } },
            onConnectionTap: { showConnMenu = true },
            onNavigate: navigate,
            content: tabContent
        )
        .onChange(of: selectedTab) { tab in
            if tab != .settings { settingsSubpage = "main" }
        }
        .sheet(isPresented: $showConnMenu) {
            connectionSheet
                .presentationDetents([.height(280)])
        }
    }

    private var connectionSheet: some View {
        NavigationStack {
            List {
                connectionRow("Server", wsClient.isConnected ? "Online" : "—")
                connectionRow("Peers", "—")
                connectionRow("Transfer", "Automatic")
                connectionRow("Latency", "—")
                connectionRow("Last sync", "—")
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showConnMenu = false }
                }
            }
        }
    }

    private func connectionRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(SyncTokens.textMuted)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: MainTab) -> some View {
        switch tab {
        case .cloudSend:
            SendView()
        case .localSend:
            LocalSendView()
        case .clipboard:
            ClipboardHubView()
        case .files:
            FilesView()
        case .settings:
            if settingsSubpage == "devices" {
                DevicesView(onBack: { settingsSubpage = "main" })
            } else {
                SettingsView(onOpenDevices: { settingsSubpage = "devices" })
            }
        }
    }

    private func navigate(_ tab: MainTab) {
        withAnimation(.easeOut(duration: SyncTokens.durationNormal)) {
            selectedTab = tab
        }
    }
}
