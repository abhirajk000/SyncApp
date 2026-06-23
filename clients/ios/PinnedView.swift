// PinnedView.swift — Matches Android PinnedScreen.kt

import SwiftUI

struct PinnedView: View {
    @EnvironmentObject var appState: AppState

    private var pinned: [ClipboardEntry] {
        appState.clipboardHistory.filter { $0.pinned }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space3) {
                AppSectionTitle(title: "Pinned")
                if pinned.isEmpty {
                    AppEmptyState(
                        icon: "pin.fill",
                        title: "No pinned items",
                        description: "Pin clipboard entries to keep them synced across devices."
                    )
                } else {
                    ForEach(pinned) { entry in
                        GlassListRow(onTap: { appState.copyEntry(entry) }) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: SyncTokens.space1) {
                                    Text(clipboardDisplayText(entry.content, max: 200))
                                        .font(.system(size: 14))
                                        .lineLimit(3)
                                    Text(relativeTime(entry.createdAt))
                                        .font(.system(size: 12))
                                        .foregroundStyle(SyncTokens.slateSecondary)
                                }
                                Spacer()
                                Button("Unpin") {
                                    Task { await appState.pinClipboard(entry, pinned: false) }
                                }
                                .font(.system(size: 13, weight: .medium))
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)
            .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
        }
    }
}
