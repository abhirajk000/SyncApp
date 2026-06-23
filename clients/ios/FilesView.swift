// FilesView.swift — Matches Android FilesScreen.kt

import SwiftUI

struct FilesView: View {
    @EnvironmentObject var appState: AppState
    @State private var tabIndex = 0

    private var filtered: [FileItem] {
        let pinned = tabIndex == 1
        return appState.files.filter { $0.isPinned == pinned }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space4) {
                SegmentedTabs(
                    options: ["Temporary", "Pinned"],
                    selectedIndex: $tabIndex
                )
                AppSectionTitle(title: tabIndex == 1 ? "Pinned files" : "Temporary files")

                if filtered.isEmpty {
                    AppEmptyState(
                        icon: "folder",
                        title: tabIndex == 1 ? "No pinned files" : "No files yet",
                        description: "Send files from the Send tab or receive them from other devices."
                    )
                } else if tabIndex == 0 {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120), spacing: SyncTokens.space4)],
                        spacing: SyncTokens.space4
                    ) {
                        ForEach(filtered) { file in
                            FileGridItemView(file: file)
                        }
                    }
                    .padding(.top, SyncTokens.space3)
                } else {
                    ForEach(filtered) { file in
                        PinnedFileRow(file: file)
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)
            .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
        }
        .task { await appState.refreshFiles() }
    }
}

private struct PinnedFileRow: View {
    @EnvironmentObject var appState: AppState
    let file: FileItem

    private var ready: Bool { file.status == "ready" }

    var body: some View {
        GlassListRow {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name).lineLimit(1)
                    Text("\(formatBytes(file.totalSize)) · \(relativeTime(file.createdAt))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(SyncTokens.slateSecondary)
                    TransferBadge(transferMode: file.transferMode)
                }
                Spacer()
                ItemActionMenu(
                    showDownload: ready,
                    showCopy: canCopyFile(file),
                    showPin: true,
                    showDelete: true,
                    isPinned: true,
                    onDownload: { Task { await appState.downloadFile(file) } },
                    onCopy: { Task { await appState.copyFileToClipboard(file) } },
                    onPin: { Task { await appState.pinFile(file, pinned: false) } }
                )
            }
        }
    }
}
