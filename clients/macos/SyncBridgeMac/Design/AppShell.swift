// AppShell.swift — Unified layout (Phase 2)

import SwiftUI

struct AppShell<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let selectedTab: AppNavTab
    let connected: Bool
    let refreshing: Bool
    let onRefresh: () -> Void
    let onNavigate: (AppNavTab) -> Void
    @ViewBuilder let content: (AppNavTab) -> Content

    var body: some View {
        ZStack {
            LiquidBackground()
            VStack(spacing: 0) {
                macTopBar
                ZStack {
                    content(selectedTab)
                        .id(selectedTab)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeOut(duration: DS.Duration.normal), value: selectedTab)
                DockBottomBar(current: selectedTab, onNavigate: onNavigate)
            }
        }
    }

    private var macTopBar: some View {
        HStack(spacing: DS.Space.sm) {
            Image(nsImage: NSImage(named: "AppLogo") ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            Text("SyncBridge")
                .font(SyncFont.titleXl())
            Spacer(minLength: 4)
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(SyncFont.bodySm().weight(.semibold))
                    .foregroundStyle(DS.Color.primaryAdaptive(colorScheme))
                    .rotationEffect(.degrees(refreshing ? 360 : 0))
                    .animation(refreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: refreshing)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .disabled(refreshing)
            .help("Refresh sync")
            AppBadge(status: connected ? .connected : .offline, label: connected ? "Connected" : "Offline")
        }
        .frame(height: MenuBarLayout.headerHeight)
        .padding(.horizontal, DS.Space.lg)
        .background(DS.Color.cardAdaptive(colorScheme).opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.Color.borderAdaptive(colorScheme).opacity(0.25))
                .frame(height: 1)
        }
    }
}
