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
    let entry: ClipboardEntryResponse?
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    var onNavigate: (AppNavTab) -> Void

    private var unpinned: [ClipboardEntryResponse] {
        appState.clipboardHistory.filter { !$0.pinned }.sorted { clipboardDate($0.createdAt) > clipboardDate($1.createdAt) }
    }

    private var pinned: [ClipboardEntryResponse] {
        appState.clipboardHistory.filter { $0.pinned }.sorted { clipboardDate($0.createdAt) > clipboardDate($1.createdAt) }.prefix(pinnedPreviewLimit).map { $0 }
    }

    private var pinnedFiles: [FileResponse] {
        appState.files.filter { $0.isPinned && $0.status == "ready" }.sorted { clipboardDate($0.createdAt) > clipboardDate($1.createdAt) }.prefix(4).map { $0 }
    }

    private var recentFiles: [FileResponse] {
        appState.files.filter { !$0.isPinned && $0.status == "ready" }.sorted { clipboardDate($0.createdAt) > clipboardDate($1.createdAt) }.prefix(recentFilesLimit).map { $0 }
    }

    private var activity: [ActivityRow] {
        var rows: [ActivityRow] = []
        for entry in appState.clipboardHistory {
            let label = entry.contentType.hasPrefix("image/")
                ? "Image copied"
                : ClipboardDisplay.previewText(for: entry, maxLength: 120)
            rows.append(ActivityRow(id: "clip-\(entry.id)", at: entry.createdAt, kind: "Clipboard", label: label, entry: entry))
        }
        for file in appState.files where file.status == "ready" {
            rows.append(ActivityRow(id: "file-\(file.id)", at: file.createdAt, kind: "File", label: "\(file.name) · \(formatBytes(file.size))", entry: nil))
        }
        return rows.sorted { clipboardDate($0.at) > clipboardDate($1.at) }.prefix(activityLimit).map { $0 }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: DS.Space.xxl) {
                clipboardSection
                if !pinned.isEmpty || !pinnedFiles.isEmpty { pinnedSection }
                filesSection
                trustedDevicesSection
                if !activity.isEmpty { activitySection }
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await appState.refreshHome() }
    }

    private var clipboardSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            AppSectionHeader(title: "Clipboard")
            if unpinned.isEmpty {
                AppEmptyState(
                    illustration: .clipboard,
                    title: "No clipboard items",
                    description: "Copy text or an image on any device — it appears here automatically."
                )
            } else {
                ForEach(unpinned.prefix(6)) { entry in
                    ClipboardCard(
                        entry: entry,
                        onCopy: { appState.copyToClipboard(entry) },
                        onDelete: { Task { await appState.deleteClipboardEntry(entry) } }
                    )
                }
            }
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                AppSectionHeader(title: "Pinned")
                Spacer()
                AppButton(title: "See all", variant: .ghost, action: { onNavigate(.clipboard) })
            }
            ForEach(pinned) { entry in
                ClipboardCard(
                    entry: entry,
                    onCopy: { appState.copyToClipboard(entry) },
                    onDelete: { Task { await appState.deleteClipboardEntry(entry) } }
                )
            }
            if !pinnedFiles.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: DS.Space.lg)], spacing: DS.Space.lg) {
                    ForEach(pinnedFiles) { file in
                        FileGridItemView(file: file)
                    }
                }
            }
        }
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                AppSectionHeader(title: "Files")
                Spacer()
                AppButton(title: "See all", variant: .ghost, action: { onNavigate(.files) })
            }
            if recentFiles.isEmpty {
                AppEmptyState(
                    illustration: .files,
                    title: "No files yet",
                    description: "Send files from another device — they appear here when ready."
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: DS.Space.lg)], spacing: DS.Space.lg) {
                    ForEach(recentFiles) { file in
                        FileGridItemView(file: file)
                    }
                }
            }
        }
    }

    private var trustedDevicesSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            AppSectionHeader(title: "Trusted devices")
            AppCard {
                OnlineDevicesBar()
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            AppSectionHeader(title: "Recent activity")
            VStack(spacing: DS.Space.sm) {
                ForEach(activity) { row in
                    GlassListRow {
                        HStack(spacing: DS.Space.sm) {
                            PremiumChip(label: row.kind, variant: row.kind == "Clipboard" ? .primary : .neutral)
                            Text(relativeTimeShort(row.at))
                                .font(DS.Font.caption())
                                .foregroundStyle(.secondary)
                        }
                        Text(row.label)
                            .font(DS.Font.body())
                            .lineLimit(2)
                            .padding(.top, DS.Space.xs)
                    }
                    .onTapGesture {
                        if let entry = row.entry { appState.copyToClipboard(entry) }
                    }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_000_000 { return String(format: "%.1f MB", Double(bytes) / 1_000_000) }
        if bytes >= 1_000 { return String(format: "%.0f KB", Double(bytes) / 1_000) }
        return "\(bytes) B"
    }
}

private func clipboardDate(_ isoString: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: isoString) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: isoString) ?? .distantPast
}

private func relativeTimeShort(_ isoString: String) -> String {
    let date = clipboardDate(isoString)
    guard date != .distantPast else { return isoString }
    let rel = RelativeDateTimeFormatter()
    rel.unitsStyle = .short
    return rel.localizedString(for: date, relativeTo: Date())
}
