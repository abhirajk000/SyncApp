// SendLandingView.swift — Cloud vs Local Send (macOS)

import SwiftUI

struct SendLandingView: View {
    let onCloud: () -> Void
    let onWifi: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                Text("Send").font(SyncFont.title2xl())
                Text("Choose how you want to transfer files.")
                    .font(SyncFont.caption())
                    .foregroundStyle(DS.Color.muted)

                HStack(spacing: DS.Space.md) {
                    modeCard(title: "Cloud Send", description: "Via your SyncBridge server.", icon: "cloud.fill", colors: [DS.Color.primary, DS.Color.secondary], action: onCloud)
                    modeCard(title: "Local Send", description: "Direct Wi‑Fi — no cloud.", icon: "wifi", colors: [DS.Color.secondary, DS.Color.muted], action: onWifi)
                }
            }
            .padding(DS.Space.md)
        }
    }

    private func modeCard(title: String, description: String, icon: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                Text(title).font(SyncFont.titleLg())
                Text(description).font(SyncFont.caption()).foregroundStyle(DS.Color.muted)
            }
            .padding(DS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveGlassCard(cornerRadius: DS.Radius.card)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
