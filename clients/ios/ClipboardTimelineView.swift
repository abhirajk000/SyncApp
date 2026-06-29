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
    let items: [ClipboardEntry]
}

struct ClipboardTimelineView: View {
    var embedded: Bool = false
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var search = ""
    @State private var filter: ClipboardFilter = .all
    @State private var copiedId: String?
    @State private var preview: ClipboardEntry?
    @State private var devices: [DeviceItem] = []
    @State private var insertingId: String?
    @State private var lastHeadId: String?

    private var sorted: [ClipboardEntry] {
        appState.clipboardHistory.sorted { $0.createdAt > $1.createdAt }
    }

    private var filtered: [ClipboardEntry] {
        sorted.filter { matchesFilter($0) && matchesSearch($0) }
    }

    private var groups: [DayGroup] {
        var map: [(String, [ClipboardEntry])] = []
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
        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space6) {
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
                        VStack(alignment: .leading, spacing: SyncTokens.space3) {
                            Text(group.label.uppercased())
                                .font(SyncFont.label())
                                .tracking(1.2)
                                .foregroundStyle(SyncTokens.slateMuted)

                            ContainerGroup {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, entry in
                                    ClipboardCard(
                                        entry: entry,
                                        onCopy: { copy(entry) },
                                        onDelete: { Task { await appState.deleteClipboard(entry) } },
                                        serverURL: appState.serverURL,
                                        accessToken: appState.accessToken,
                                        deviceName: deviceName(for: entry),
                                        transferMode: transferMode(for: entry),
                                        copied: copiedId == entry.id,
                                        embeddedInGroup: true,
                                        onPin: { Task { await appState.pinClipboard(entry, pinned: !entry.pinned) } },
                                        onPreview: { preview = entry }
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                    .id(entry.id)
                                    if index < group.items.count - 1 {
                                        Divider()
                                            .overlay(AppSurfaces.cardBorder(colorScheme))
                                            .padding(.horizontal, SyncTokens.space5)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, embedded ? SyncTokens.space2 : SyncTokens.space4)
            .padding(.bottom, embedded ? SyncTokens.space6 : SyncTokens.space10 + SyncTokens.dockHeight)
        }
        .animation(.easeOut(duration: SyncTokens.durationNormal), value: filtered.map(\.id))
        .task {
            await loadDevices()
            await appState.refreshAll()
        }
        .onChange(of: sorted.first?.id) { newId in
            guard let newId, newId != lastHeadId, lastHeadId != nil else {
                lastHeadId = newId
                return
            }
            insertingId = newId
            lastHeadId = newId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { insertingId = nil }
        }
        .sheet(item: $preview) { entry in
            previewSheet(entry)
        }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space3) {
            PremiumSearchField(text: $search, placeholder: "Search clipboard…")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SyncTokens.space2) {
                    ForEach(ClipboardFilter.allCases, id: \.self) { item in
                        Button {
                            filter = item
                        } label: {
                            PremiumChip(
                                label: item.rawValue,
                                variant: filter == item ? .primary : .neutral
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func previewSheet(_ entry: ClipboardEntry) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SyncTokens.space4) {
                    if isImageContentType(entry.contentType) {
                        ClipboardImageThumb(
                            entry: entry,
                            serverURL: appState.serverURL,
                            accessToken: appState.accessToken,
                            maxHeight: 360
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(entry.content)
                            .font(SyncFont.body())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    PrimaryButton(text: isImageContentType(entry.contentType) ? "Copy image" : "Copy") {
                        copy(entry)
                        preview = nil
                    }
                }
                .padding(SyncTokens.space4)
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { preview = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func copy(_ entry: ClipboardEntry) {
        appState.copyEntry(entry)
        copiedId = entry.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            if copiedId == entry.id { copiedId = nil }
        }
    }

    private func loadDevices() async {
        guard let token = appState.accessToken else { return }
        devices = (try? await DeviceAPI.fetchDevices(serverURL: appState.serverURL, accessToken: token)) ?? []
    }

    private func deviceName(for entry: ClipboardEntry) -> String? {
        devices.first { $0.id == entry.sourceDeviceId }?.name
    }

    private func transferMode(for entry: ClipboardEntry) -> String {
        if devices.first(where: { $0.id == entry.sourceDeviceId })?.online == true {
            return "direct_lan"
        }
        return "relay"
    }

    private func matchesFilter(_ entry: ClipboardEntry) -> Bool {
        switch filter {
        case .all: return true
        case .images: return isImageContentType(entry.contentType)
        case .text: return !isImageContentType(entry.contentType)
        }
    }

    private func matchesSearch(_ entry: ClipboardEntry) -> Bool {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if isImageContentType(entry.contentType) { return "image".contains(q) }
        return entry.content.lowercased().contains(q)
    }

    private func dayLabel(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? Date()
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