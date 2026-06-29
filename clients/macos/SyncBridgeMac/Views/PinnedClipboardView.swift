// PinnedClipboardView.swift — Web ClipboardPage parity.

import SwiftUI

struct PinnedClipboardView: View {
    var embedded: Bool = false

    @EnvironmentObject var appState: AppState

    private var pinned: [ClipboardEntryResponse] {
        appState.clipboardHistory
            .filter { $0.pinned }
            .sorted { clipboardDate($0.createdAt) > clipboardDate($1.createdAt) }
    }

    var body: some View {
        Group {
            if pinned.isEmpty {
                AppEmptyState(
                    illustration: .pinned,
                    title: "No pinned items",
                    description: "Pin clipboard entries to keep them synced across all devices."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        if !embedded {
                            sectionTitle("Pinned")
                        }
                        ContainerGroup {
                            ForEach(Array(pinned.enumerated()), id: \.element.id) { index, entry in
                                PinnedListItem(entry: entry)
                                if index < pinned.count - 1 {
                                    Divider().padding(.horizontal, DS.Space.space5)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Space.md)
                    .padding(.top, embedded ? DS.Space.sm : DS.Space.md)
                    .padding(.bottom, embedded ? DS.Space.md : DS.Space.lg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await appState.refreshClipboardHistory() }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(DS.Font.label())
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }
}

private struct PinnedListItem: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntryResponse

    private var isImage: Bool { entry.contentType.hasPrefix("image/") }

    private var transferMode: String {
        let peerIds = Set(appState.networkManager.peers.map(\.deviceId))
        return peerIds.contains(entry.sourceDeviceId) ? "direct_lan" : "relay"
    }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    if isImage {
                        ClipboardImageThumb(entry: entry, maxHeight: 120)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    } else {
                        Text(ClipboardDisplay.previewText(for: entry, maxLength: 500))
                            .font(DS.Font.body())
                            .foregroundStyle(DS.Color.textAdaptive(colorScheme))
                            .lineLimit(1)
                    }
                    Text("\(entry.contentType) · \(relativeTimeShort(entry.createdAt))")
                        .font(DS.Font.caption())
                        .foregroundStyle(.secondary)
                    TransferBadgeView(transferMode: transferMode)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: DS.Space.sm) {
                    ListGhostButton(title: isImage ? "Copy Image" : "Copy") {
                        appState.copyToClipboard(entry)
                    }
                    ListGhostButton(title: "Unpin") {
                        Task { await appState.pinClipboardEntry(entry, pinned: false) }
                    }
                    ItemDeleteButton {
                        Task { await appState.deleteClipboardEntry(entry) }
                    }
                }
            }
            .padding(.horizontal, DS.Space.space5)
            .padding(.vertical, DS.Space.md)
    }
}

/// Compact ghost button for list row actions (web ds-btn--ghost--sm).
private struct ListGhostButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Font.label())
                .foregroundStyle(.secondary)
                .padding(.vertical, DS.Space.sm)
                .padding(.horizontal, DS.Space.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(DS.Color.borderAdaptive(colorScheme).opacity(0.4))
                )
        }
        .buttonStyle(.plain)
    }
}

private func clipboardDate(_ isoString: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: isoString)
        ?? ISO8601DateFormatter().date(from: isoString)
        ?? .distantPast
}

private func relativeTimeShort(_ isoString: String) -> String {
    let date = clipboardDate(isoString)
    guard date != .distantPast else { return isoString }
    let rel = RelativeDateTimeFormatter()
    rel.unitsStyle = .short
    return rel.localizedString(for: date, relativeTo: Date())
}
