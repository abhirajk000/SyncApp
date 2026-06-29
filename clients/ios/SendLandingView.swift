// SendLandingView.swift — Cloud vs Local Send choice

import SwiftUI

struct SendLandingView: View {
    let onCloud: () -> Void
    let onWifi: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space4) {
                Text("Send")
                    .font(SyncFont.title2xl())
                Text("Choose how you want to transfer files.")
                    .font(SyncFont.bodySm())
                    .foregroundStyle(SyncTokens.slateMuted)

                HStack(spacing: SyncTokens.space4) {
                    modeCard(
                        title: "Cloud Send",
                        description: "Text, images, and files via your SyncBridge server.",
                        icon: "cloud.fill",
                        colors: [SyncTokens.teal, SyncTokens.tealLight],
                        action: onCloud
                    )
                    modeCard(
                        title: "Local Send",
                        description: "Direct Wi‑Fi — no cloud upload.",
                        icon: "wifi",
                        colors: [SyncTokens.indigo, SyncTokens.violet],
                        action: onWifi
                    )
                }
            }
            .padding(SyncTokens.space4)
            .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
        }
    }

    private func modeCard(
        title: String,
        description: String,
        icon: String,
        colors: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SyncTokens.space3) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusLg))
                Text(title).font(SyncFont.titleLg()).foregroundStyle(AppSurfaces.onSurface(colorScheme))
                Text(description)
                    .font(SyncFont.bodySm())
                    .foregroundStyle(SyncTokens.slateMuted)
                    .multilineTextAlignment(.leading)
            }
            .padding(SyncTokens.space5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppSurfaces.card(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: SyncTokens.radiusCard).stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
