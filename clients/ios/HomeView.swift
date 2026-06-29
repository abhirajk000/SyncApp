// HomeView.swift — Phase 5: Clipboard · Pinned · Files · Trusted Devices · Recent Activity

import SwiftUI

private let recentFilesLimit = 8
private let pinnedPreviewLimit = 5
private let activityLimit = 10

private struct ActivityRow: Identifiable {
    let id: String
    let at: String
    let kind: String
    let label: String
    let entry: ClipboardEntry?
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    let onNavigate: (MainTab) -> Void

    private var unpinned: [ClipboardEntry] {
        appState.clipboardHistory.filter { !$0.pinned }.sorted { $0.createdAt > $1.createdAt }
    }

    private var pinned: [ClipboardEntry] {
        appState.clipboardHistory.filter { $0.pinned }.sorted { $0.createdAt > $1.createdAt }.prefix(pinnedPreviewLimit).map { $0 }
    }

    private var pinnedFiles: [FileItem] {
        appState.files.filter { $0.isPinned && $0.status == "ready" }.sorted { $0.createdAt > $1.createdAt }.prefix(4).map { $0 }
    }

    private var recentFiles: [FileItem] {
        appState.files.filter { !$0.isPinned && $0.status == "ready" }.sorted { $0.createdAt > $1.createdAt }.prefix(recentFilesLimit).map { $0 }
    }

    private var latestText: ClipboardEntry? { unpinned.first { !isImageContentType($0.contentType) } }
    private var latestImage: ClipboardEntry? { unpinned.first { isImageContentType($0.contentType) } }
    private var earlier: [ClipboardEntry] {
        unpinned.filter { $0.id != latestText?.id && $0.id != latestImage?.id }
    }

    private var activity: [ActivityRow] {
        var rows: [ActivityRow] = []
        for entry in appState.clipboardHistory {
            let label = isImageContentType(entry.contentType) ? "Image copied" : clipboardDisplayText(entry.content, max: 120)
            rows.append(ActivityRow(id: "clip-\(entry.id)", at: entry.createdAt, kind: "Clipboard", label: label, entry: entry))
        }
        for file in appState.files where file.status == "ready" {
            rows.append(ActivityRow(id: "file-\(file.id)", at: file.createdAt, kind: "File", label: "\(file.name) · \(formatBytes(file.totalSize))", entry: nil))
        }
        return rows.sorted { $0.at > $1.at }.prefix(activityLimit).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space8) {
                clipboardSection
                if !pinned.isEmpty || !pinnedFiles.isEmpty { pinnedSection }
                filesSection
                trustedDevicesSection
                if !activity.isEmpty { activitySection }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)
            .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
        }
        .task { await appState.refreshAll() }
    }

    // MARK: - Sections

    private var clipboardSection: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space4) {
            AppSectionTitle(title: "Clipboard")
            if unpinned.isEmpty {
                AppEmptyState(
                    illustration: .clipboard,
                    title: "No clipboard items",
                    description: "Copy text or an image on any device — it appears here automatically."
                )
            } else {
                if let latestText {
                    LatestTextCard(entry: latestText, title: "Latest text", onCopy: { appState.copyEntry(latestText) })
                }
                if let latestImage {
                    LatestImageCard(
                        entry: latestImage,
                        serverURL: appState.serverURL,
                        accessToken: appState.accessToken,
                        title: "Latest image",
                        onCopy: { appState.copyEntry(latestImage) }
                    )
                }
                VStack(spacing: SyncTokens.space2) {
                    ForEach(earlier) { entry in
                        if isImageContentType(entry.contentType) {
                            EarlierImageRow(
                                entry: entry,
                                serverURL: appState.serverURL,
                                accessToken: appState.accessToken,
                                onCopy: { appState.copyEntry(entry) }
                            )
                        } else {
                            EarlierTextRow(entry: entry, onCopy: { appState.copyEntry(entry) })
                        }
                    }
                }
            }
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space4) {
            SectionHeaderRow(title: "Pinned", actionLabel: "See all", onAction: { onNavigate(.clipboard) })
            ForEach(pinned) { entry in
                ClipboardCard(
                    entry: entry,
                    onCopy: { appState.copyEntry(entry) },
                    onDelete: { Task { await appState.deleteClipboard(entry) } }
                )
            }
            if !pinnedFiles.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: SyncTokens.space4)], spacing: SyncTokens.space4) {
                    ForEach(pinnedFiles) { file in
                        FileGridItemView(file: file, compact: true)
                    }
                }
            }
        }
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space4) {
            SectionHeaderRow(title: "Files", actionLabel: "See all", onAction: { onNavigate(.files) })
            if recentFiles.isEmpty {
                AppEmptyState(
                    illustration: .files,
                    title: "No files yet",
                    description: "Send files from another device — they appear here when ready."
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: SyncTokens.space4)], spacing: SyncTokens.space4) {
                    ForEach(recentFiles) { file in
                        FileGridItemView(file: file, compact: true)
                    }
                }
            }
        }
    }

    private var trustedDevicesSection: some View {
        TrustedDevicesBar(serverURL: appState.serverURL, accessToken: appState.accessToken)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space4) {
            AppSectionTitle(title: "Recent activity")
            VStack(spacing: SyncTokens.space2) {
                ForEach(activity) { row in
                    GlassListRow(
                        onTap: row.entry.map { entry in { appState.copyEntry(entry) } }
                    ) {
                        HStack(spacing: SyncTokens.space2) {
                            PremiumChip(
                                label: row.kind,
                                variant: row.kind == "Clipboard" ? .primary : .neutral
                            )
                            Text(relativeTime(row.at))
                                .font(SyncFont.caption())
                                .foregroundStyle(SyncTokens.slateMuted)
                        }
                        Text(row.label)
                            .font(SyncFont.bodySm())
                            .lineLimit(2)
                            .padding(.top, SyncTokens.space1)
                    }
                }
            }
        }
    }
}
