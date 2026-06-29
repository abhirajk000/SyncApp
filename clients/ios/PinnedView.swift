// PinnedView.swift — Web ClipboardPage parity.

import SwiftUI

struct PinnedView: View {
    var embedded: Bool = false
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var pinned: [ClipboardEntry] {
        appState.clipboardHistory
            .filter { $0.pinned }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space3) {
                if !embedded {
                    AppSectionTitle(title: "Pinned")
                }
                if pinned.isEmpty {
                    AppEmptyState(
                        illustration: .pinned,
                        title: "No pinned items",
                        description: "Pin clipboard entries to keep them synced across all devices."
                    )
                } else {
                    ContainerGroup {
                        ForEach(Array(pinned.enumerated()), id: \.element.id) { index, entry in
                            PinnedListItem(entry: entry)
                            if index < pinned.count - 1 {
                                Divider()
                                    .overlay(AppSurfaces.cardBorder(colorScheme))
                                    .padding(.horizontal, SyncTokens.space5)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, embedded ? SyncTokens.space2 : SyncTokens.space4)
            .padding(.bottom, embedded ? SyncTokens.space6 : SyncTokens.space10 + SyncTokens.dockHeight)
        }
    }
}

private struct PinnedListItem: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry

    private var isImage: Bool { isImageContentType(entry.contentType) }

    var body: some View {
        HStack(alignment: .center, spacing: SyncTokens.space4) {
                VStack(alignment: .leading, spacing: SyncTokens.space1) {
                    if isImage {
                        ClipboardImageThumb(
                            entry: entry,
                            serverURL: appState.serverURL,
                            accessToken: appState.accessToken,
                            maxHeight: 120
                        )
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusLg))
                    } else {
                        Text(clipboardDisplayText(entry.content, max: 500))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppSurfaces.onSurface(colorScheme))
                            .lineLimit(1)
                    }
                    Text("\(entry.contentType) · \(relativeTime(entry.createdAt))")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(SyncTokens.slateMuted)
                    TransferBadge(transferMode: "relay")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: SyncTokens.space2) {
                    GhostButton(title: isImage ? "Copy Image" : "Copy") {
                        appState.copyEntry(entry)
                    }
                    GhostButton(title: "Unpin") {
                        Task { await appState.pinClipboard(entry, pinned: false) }
                    }
                    ItemDeleteButton {
                        Task { await appState.deleteClipboard(entry) }
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space5)
            .padding(.vertical, SyncTokens.space4)
    }
}
