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
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                TextField("Search clipboard…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !temporary.isEmpty {
                            sectionHeader("Temporary")
                            ForEach(temporary) { entry in
                                ClipboardEntryRow(entry: entry)
                                Divider()
                            }
                        }
                        if !pinned.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(pinned) { entry in
                                ClipboardEntryRow(entry: entry)
                                Divider()
                            }
                        }
                    }
                }
                .task { await appState.refreshClipboardHistory() }
            }
        }
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
    @State private var isCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: contentIcon)
                .frame(width: 20)
                .foregroundColor(.accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.content)
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

            HStack(spacing: 4) {
                Button {
                    Task { await appState.pinClipboardEntry(entry, pinned: !entry.pinned) }
                } label: {
                    Image(systemName: entry.pinned ? "pin.slash" : "pin")
                        .foregroundColor(entry.pinned ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(entry.pinned ? "Unpin" : "Pin")

                Button {
                    appState.copyToClipboard(entry)
                    withAnimation { isCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { isCopied = false }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundColor(isCopied ? .green : .accentColor)
                }
                .buttonStyle(.plain)

                if !entry.pinned {
                    Button(role: .destructive) {
                        Task { await appState.deleteClipboardEntry(entry) }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
        .glassCard(cornerRadius: DS.Radius.md)
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
