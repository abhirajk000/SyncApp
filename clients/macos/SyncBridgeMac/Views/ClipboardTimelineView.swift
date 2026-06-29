// ClipboardTimelineView.swift — Phase 6 premium clipboard timeline

import SwiftUI

private enum ClipboardFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case images = "Images"
}

private struct DayGroup: Identifiable {
    let id: String
    let label: String
    let items: [ClipboardEntryResponse]
}

struct ClipboardTimelineView: View {
    var embedded: Bool = false
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var search = ""
    @State private var filter: ClipboardFilter = .all
    @State private var copiedId: String?
    @State private var preview: ClipboardEntryResponse?
    @State private var lastHeadId: String?

    private var sorted: [ClipboardEntryResponse] {
        appState.clipboardHistory.sorted { clipboardDate($0.createdAt) > clipboardDate($1.createdAt) }
    }

    private var filtered: [ClipboardEntryResponse] {
        sorted.filter { matchesFilter($0) && matchesSearch($0) }
    }

    private var groups: [DayGroup] {
        var map: [(String, [ClipboardEntryResponse])] = []
        for entry in filtered {
            let label = dayLabel(entry.createdAt)
            if let idx = map.firstIndex(where: { $0.0 == label }) {
                map[idx].1.append(entry)
            } else {
                map.append((label, [entry]))
            }
        }
        return map.map { DayGroup(id: $0.0, label: $0.0, items: $0.1) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                toolbar

                if filtered.isEmpty {
                    AppEmptyState(
                        illustration: .clipboard,
                        title: search.isEmpty ? "No clipboard items" : "No matches",
                        description: search.isEmpty
                            ? "Copy text or an image on any device — it appears here instantly."
                            : "Try a different search or filter."
                    )
                } else {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            Text(group.label.uppercased())
                                .font(DS.Font.label())
                                .foregroundStyle(.secondary)
                                .tracking(0.8)

                            ContainerGroup {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, entry in
                                    ClipboardCard(
                                        entry: entry,
                                        onCopy: { copy(entry) },
                                        onDelete: { Task { await appState.deleteClipboardEntry(entry) } },
                                        deviceName: deviceName(for: entry),
                                        transferMode: transferMode(for: entry),
                                        copied: copiedId == entry.id,
                                        onPin: { Task { await appState.pinClipboardEntry(entry, pinned: !entry.pinned) } },
                                        onPreview: { preview = entry }
                                    )
                                    if index < group.items.count - 1 {
                                        Divider().padding(.horizontal, DS.Space.space5)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, embedded ? DS.Space.sm : DS.Space.md)
            .padding(.bottom, embedded ? DS.Space.md : DS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: DS.Duration.normal), value: filtered.map(\.id))
        .task { await appState.refreshHome() }
        .onChange(of: sorted.first?.id) { newId in
            lastHeadId = newId
        }
        .sheet(item: $preview) { entry in
            previewSheet(entry)
        }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            PremiumSearchField(text: $search, placeholder: "Search clipboard…")
            HStack(spacing: DS.Space.xs) {
                ForEach(ClipboardFilter.allCases, id: \.self) { item in
                    Button { filter = item } label: {
                        PremiumChip(label: item.rawValue, variant: filter == item ? .primary : .neutral)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func previewSheet(_ entry: ClipboardEntryResponse) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                Text("Preview")
                    .font(DS.Font.titleSm())
                Spacer()
                AppButton(title: "Done", variant: .ghost) { preview = nil }
            }
            if entry.contentType.hasPrefix("image/") {
                ClipboardImageThumb(entry: entry, maxHeight: 320)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    Text(ClipboardDisplay.previewText(for: entry, maxLength: 8000))
                        .font(DS.Font.body())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
            }
            AppButton(title: entry.contentType.hasPrefix("image/") ? "Copy image" : "Copy", variant: .primary) {
                copy(entry)
                preview = nil
            }
        }
        .padding(DS.Space.lg)
        .frame(minWidth: 360, minHeight: 240)
    }

    private func copy(_ entry: ClipboardEntryResponse) {
        appState.copyToClipboard(entry)
        copiedId = entry.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            if copiedId == entry.id { copiedId = nil }
        }
    }

    private func deviceName(for entry: ClipboardEntryResponse) -> String? {
        appState.devices.first { $0.id == entry.sourceDeviceId }?.name
    }

    private func transferMode(for entry: ClipboardEntryResponse) -> String {
        appState.networkManager.peers.contains(where: { $0.deviceId == entry.sourceDeviceId }) ? "direct_lan" : "relay"
    }

    private func matchesFilter(_ entry: ClipboardEntryResponse) -> Bool {
        switch filter {
        case .all: return true
        case .images: return entry.contentType.hasPrefix("image/")
        case .text: return !entry.contentType.hasPrefix("image/")
        }
    }

    private func matchesSearch(_ entry: ClipboardEntryResponse) -> Bool {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if entry.contentType.hasPrefix("image/") { return "image".contains(q) }
        return entry.content.lowercased().contains(q)
    }

    private func dayLabel(_ iso: String) -> String {
        let date = clipboardDate(iso)
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if let days = cal.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: date)
        }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

private func clipboardDate(_ isoString: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: isoString) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: isoString) ?? .distantPast
}
