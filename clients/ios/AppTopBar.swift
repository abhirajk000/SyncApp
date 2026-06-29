// AppTopBar.swift — Glass top app bar (Phase 2)

import SwiftUI

struct AppTopBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let connected: Bool
    let refreshing: Bool
    let onRefresh: () -> Void
    let onConnectionTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: SyncTokens.space3) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text("SyncBridge")
                        .font(SyncFont.titleXl())
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(SyncFont.bodySm().weight(.semibold))
                        .foregroundStyle(SyncTokens.teal)
                        .rotationEffect(.degrees(refreshing ? 360 : 0))
                        .animation(refreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: refreshing)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(refreshing)
                .accessibilityLabel("Refresh sync")
                ConnectionChip(connected: connected, onTap: onConnectionTap)
            }
            .padding(.horizontal, SyncTokens.space4)
            .frame(height: SyncTokens.headerHeight)
            .background(AppSurfaces.card(colorScheme))
            Divider().overlay(AppSurfaces.cardBorder(colorScheme))
        }
    }
}
