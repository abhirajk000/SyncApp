// AppShell.swift — Unified layout: glass top bar + page transitions + floating dock (Phase 2)

import SwiftUI

struct AppShell<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let selectedTab: MainTab
    let connected: Bool
    let refreshing: Bool
    let onRefresh: () -> Void
    let onConnectionTap: () -> Void
    let onNavigate: (MainTab) -> Void
    @ViewBuilder let content: (MainTab) -> Content

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                AppTopBar(
                    connected: connected,
                    refreshing: refreshing,
                    onRefresh: onRefresh,
                    onConnectionTap: onConnectionTap
                )
                ZStack {
                    content(selectedTab)
                        .id(selectedTab)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeOut(duration: SyncTokens.durationNormal), value: selectedTab)
                DockBottomBar(current: selectedTab, onNavigate: onNavigate)
            }
        }
    }
}
