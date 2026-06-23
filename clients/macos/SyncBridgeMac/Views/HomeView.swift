// HomeView.swift — Latest highlights + chronological clipboard feed (matches web home).

import SwiftUI

private let recentFilesLimit = 12

struct HomeView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    var onSeeAllFiles: () -> Void

    private var unpinnedClipboard: [ClipboardEntryResponse] {
        appState.clipboardHistory
            .filter { !$0.pinned }
            .sorted { clipboardDate($0.createdAt) > clipboardDate($1.createdAt) }
    }

    private var latest: ClipboardEntryResponse? { unpinnedClipboard.first }
    private var earlierEntries: [ClipboardEntryResponse] { Array(unpinnedClipboard.dropFirst()) }

    private var recentFiles: [FileResponse] {
        appState.files
            .filter { !$0.isPinned && $0.status == "ready" }
            .sorted { clipboardDate($0.createdAt) > clipboardDate($1.createdAt) }
            .prefix(recentFilesLimit)
            .map { $0 }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack(alignment: .top) {
                    OnlineDevicesBar()
                    Spacer(minLength: DS.Space.sm)
                    HomeRefreshButton(isRefreshing: appState.isRefreshing) {
                        Task { await appState.refreshHome() }
                    }
                }

                if latest == nil && earlierEntries.isEmpty && recentFiles.isEmpty {
                    AppEmptyState(
                        icon: "doc.on.clipboard",
                        title: "Nothing synced yet",
                        description: "Copy text or an image on any device — it appears here automatically."
                    )
                    .padding(.top, DS.Space.lg)
                } else {
                    if let entry = latest {
                        if entry.contentType.hasPrefix("image/") {
                            homeSection("Latest") {
                                LatestImageCard(entry: entry) {
                                    appState.copyToClipboard(entry)
                                }
                            }
                        } else {
                            homeSection("Latest") {
                                LatestClipboardCard(entry: entry) {
                                    appState.copyToClipboard(entry)
                                }
                            }
                        }
                    }

                    if !earlierEntries.isEmpty {
                        homeSection("Earlier") {
                            VStack(spacing: DS.Space.sm) {
                                ForEach(earlierEntries) { entry in
                                    if entry.contentType.hasPrefix("image/") {
                                        EarlierImageRow(entry: entry) {
                                            appState.copyToClipboard(entry)
                                        }
                                    } else {
                                        EarlierTextRow(entry: entry) {
                                            appState.copyToClipboard(entry)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !recentFiles.isEmpty {
                        HStack(alignment: .firstTextBaseline) {
                            sectionTitle("Recent files")
                            Spacer()
                            Button("See all", action: onSeeAllFiles)
                                .font(DS.Font.label())
                                .buttonStyle(.plain)
                                .foregroundStyle(DS.Color.primaryAdaptive(colorScheme))
                        }

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 88), spacing: DS.Space.sm)],
                            spacing: DS.Space.sm
                        ) {
                            ForEach(recentFiles) { file in
                                FileGridItemView(file: file)
                            }
                        }
                    }
                }
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await appState.refreshHome()
        }
    }

    private func homeSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            sectionTitle(title)
            content()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(DS.Font.label())
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }
}

// MARK: - Featured cards

private struct LatestClipboardCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntryResponse
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(ClipboardDisplay.previewText(for: entry, maxLength: 160))
                        .font(DS.Font.body())
                        .foregroundStyle(DS.Color.textAdaptive(colorScheme))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(relativeTimeShort(entry.createdAt))
                        .font(DS.Font.caption())
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveGlassCard(cornerRadius: DS.Radius.md)
            }
            .buttonStyle(.plain)

            ClipboardItemActionMenu(entry: entry)
                .padding(DS.Space.sm)
                .zIndex(10)
        }
    }
}

private struct LatestImageCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntryResponse
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    ClipboardImageThumb(entry: entry, maxHeight: 100)
                        .frame(maxWidth: .infinity)

                    Text("Tap to copy · \(relativeTimeShort(entry.createdAt))")
                        .font(DS.Font.caption())
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveGlassCard(cornerRadius: DS.Radius.md)
            }
            .buttonStyle(.plain)

            ClipboardItemActionMenu(entry: entry)
                .padding(DS.Space.sm)
                .zIndex(10)
        }
    }
}

// MARK: - Earlier rows (chronological feed)

private struct EarlierTextRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntryResponse
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: DS.Space.sm) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.primaryAdaptive(colorScheme))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text(ClipboardDisplay.previewText(for: entry, maxLength: 200))
                            .font(DS.Font.body())
                            .foregroundStyle(DS.Color.textAdaptive(colorScheme))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(relativeTimeShort(entry.createdAt))
                            .font(DS.Font.caption())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(DS.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveGlassCard(cornerRadius: DS.Radius.md)
            }
            .buttonStyle(.plain)

            ClipboardItemActionMenu(entry: entry)
                .padding(DS.Space.sm)
                .zIndex(10)
        }
    }
}

private struct EarlierImageRow: View {
    let entry: ClipboardEntryResponse
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    ClipboardImageThumb(entry: entry, maxHeight: 80)
                        .frame(maxWidth: .infinity)

                    Text("Image · \(relativeTimeShort(entry.createdAt))")
                        .font(DS.Font.caption())
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .adaptiveGlassCard(cornerRadius: DS.Radius.md)
            }
            .buttonStyle(.plain)

            ClipboardItemActionMenu(entry: entry)
                .padding(DS.Space.sm)
                .zIndex(10)
        }
    }
}

// MARK: - Helpers

private struct HomeRefreshButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Color.primaryAdaptive(colorScheme))
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                .frame(width: 32, height: 32)
                .background(DS.Color.cardAdaptive(colorScheme), in: Circle())
                .overlay(Circle().stroke(DS.Color.borderAdaptive(colorScheme).opacity(0.4)))
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .help("Refresh sync")
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
