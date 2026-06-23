// MainShell.swift — Matches Android MainShell.kt

import SwiftUI

struct MainShell: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var wsClient: WSClient
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: MainTab = .clipboard
    @State private var settingsSubpage = "main"
    @State private var showConnMenu = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                header
                Divider().overlay(AppSurfaces.cardBorder(colorScheme))
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                DockBottomBar(current: selectedTab, onNavigate: navigate)
            }
        }
        .onChange(of: selectedTab) { tab in
            if tab != .settings { settingsSubpage = "main" }
        }
        .sheet(isPresented: $showConnMenu) {
            connectionSheet
                .presentationDetents([.height(280)])
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: SyncTokens.space3) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                Text("SyncBridge")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            Spacer()
            ConnectionChip(connected: wsClient.isConnected) {
                showConnMenu = true
            }
        }
        .padding(.horizontal, SyncTokens.space4)
        .frame(height: SyncTokens.headerHeight)
        .background(AppSurfaces.card(colorScheme))
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
            Text(value)
                .foregroundStyle(SyncTokens.slateSecondary)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .clipboard:
            HomeView(onNavigate: navigate)
        case .pinned:
            PinnedView()
        case .send:
            SendView()
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
        selectedTab = tab
    }
}
