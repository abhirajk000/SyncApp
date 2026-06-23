// ClipboardHistoryView.swift
// Temporary and Pinned clipboard sections with pin/unpin actions.

import SwiftUI

struct ClipboardHistoryView: View {

    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    private var filtered: [ClipboardEntryResponse] {
        guard !searchText.isEmpty else { return appState.clipboardHistory }
        return appState.clipboardHistory.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var temporary: [ClipboardEntryResponse] { filtered.filter { !$0.pinned } }
    private var pinned: [ClipboardEntryResponse] { filtered.filter { $0.pinned } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Search clipboard…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
            .background(Color.primary.opacity(0.05))

            Divider().opacity(0.35)

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !temporary.isEmpty {
                            sectionHeader("Temporary")
                            ForEach(temporary) { entry in
                                ClipboardEntryRow(entry: entry)
                                Divider().opacity(0.35)
                            }
                        }
                        if !pinned.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(pinned) { entry in
                                ClipboardEntryRow(entry: entry)
                                Divider().opacity(0.35)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Space.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await appState.refreshClipboardHistory() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        AppSectionHeader(title: title)
    }

    private var emptyState: some View {
        AppEmptyState(
            icon: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
            title: searchText.isEmpty ? "No clipboard history" : "No results",
            description: searchText.isEmpty
                ? "Copy on any device — items appear here instantly."
                : "Try a different search term."
        )
    }
}

struct ClipboardEntryRow: View {

    @EnvironmentObject var appState: AppState
    let entry: ClipboardEntryResponse

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: contentIcon)
                .frame(width: 20)
                .foregroundColor(.accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(ClipboardDisplay.previewText(for: entry))
                    .font(.subheadline)
                    .lineLimit(2)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    Text(entry.contentType.replacingOccurrences(of: "text/", with: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(relativeTime(entry.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if entry.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            ClipboardItemActionMenu(entry: entry)
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .contentShape(Rectangle())
        .onTapGesture { appState.copyToClipboard(entry) }
    }

    private var contentIcon: String {
        switch entry.contentType {
        case "text/uri-list": return "link"
        case "text/html":     return "chevron.left.forwardslash.chevron.right"
        case "text/rtf":      return "doc.richtext"
        default:              return "doc.plaintext"
        }
    }
}

private func relativeTime(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: isoString) else { return isoString }
    let rel = RelativeDateTimeFormatter()
    rel.unitsStyle = .short
    return rel.localizedString(for: date, relativeTo: Date())
}
