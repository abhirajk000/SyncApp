// HomeView.swift — Chronological feed aligned with macOS home.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let onNavigate: (MainTab) -> Void

    private var unpinnedSorted: [ClipboardEntry] {
        appState.clipboardHistory
            .filter { !$0.pinned }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var recentFiles: [FileItem] {
        appState.files
            .filter { !$0.isPinned && $0.status == "ready" }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(12)
            .map { $0 }
    }

    var body: some View {
        let latest = unpinnedSorted.first
        let earlier = Array(unpinnedSorted.dropFirst())
        let isEmpty = latest == nil && recentFiles.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: SyncTokens.space4) {
                HStack(alignment: .top) {
                    TrustedDevicesBar(
                        serverURL: appState.serverURL,
                        accessToken: appState.accessToken
                    )
                    Spacer(minLength: SyncTokens.space2)
                    HomeRefreshButton(isRefreshing: appState.isRefreshing) {
                        Task { await appState.refreshAll() }
                    }
                }

                if appState.clipboardPastePending {
                    ClipboardPasteBanner()
                }

                if isEmpty {
                    AppEmptyState(
                        icon: "doc.on.clipboard",
                        title: "Nothing synced yet",
                        description: "Copy text or an image on any device — it appears here automatically."
                    )
                    .padding(.top, SyncTokens.space4)
                } else {
                    if let latest {
                        homeSection("Latest") {
                            if isImageContentType(latest.contentType) {
                                HomeLatestImageCard(
                                    entry: latest,
                                    serverURL: appState.serverURL,
                                    accessToken: appState.accessToken
                                ) {
                                    appState.copyEntry(latest)
                                }
                            } else {
                                HomeLatestTextCard(entry: latest) {
                                    appState.copyEntry(latest)
                                }
                            }
                        }
                    }

                    if !earlier.isEmpty {
                        homeSection("Earlier") {
                            VStack(spacing: SyncTokens.space2) {
                                ForEach(earlier) { entry in
                                    if isImageContentType(entry.contentType) {
                                        HomeEarlierImageRow(
                                            entry: entry,
                                            serverURL: appState.serverURL,
                                            accessToken: appState.accessToken
                                        ) {
                                            appState.copyEntry(entry)
                                        }
                                    } else {
                                        HomeEarlierTextRow(entry: entry) {
                                            appState.copyEntry(entry)
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
                            Button("See all") { onNavigate(.files) }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(SyncTokens.teal)
                        }
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 88), spacing: SyncTokens.space2)],
                            spacing: SyncTokens.space2
                        ) {
                            ForEach(recentFiles) { file in
                                FileGridItemView(file: file, compact: true)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)
            .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
        }
        .task {
            await appState.refreshAll()
        }
    }

    private func homeSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SyncTokens.space2) {
            sectionTitle(title)
            content()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(SyncTokens.slateMuted)
    }
}

// MARK: - Refresh

struct HomeRefreshButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SyncTokens.teal)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                .frame(width: 36, height: 36)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .accessibilityLabel("Refresh")
    }
}

// MARK: - Cards (macOS-aligned)

private struct HomeLatestTextCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: SyncTokens.space1) {
                    Text(clipboardDisplayText(entry.content, max: 160))
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(AppSurfaces.onSurface(colorScheme))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, SyncTokens.space6)
                    Text(relativeTime(entry.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SyncTokens.slateSecondary)
                }
                .padding(SyncTokens.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                        .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            ClipboardItemActionMenu(entry: entry)
                .padding(SyncTokens.space2)
                .zIndex(10)
        }
    }
}

private struct HomeLatestImageCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry
    let serverURL: String
    let accessToken: String?
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: SyncTokens.space2) {
                    ClipboardImageThumb(
                        entry: entry,
                        serverURL: serverURL,
                        accessToken: accessToken,
                        maxHeight: 100
                    )
                    .frame(maxWidth: .infinity)
                    Text("Tap to copy · \(relativeTime(entry.createdAt))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SyncTokens.slateSecondary)
                }
                .padding(SyncTokens.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                        .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            ClipboardItemActionMenu(entry: entry)
                .padding(SyncTokens.space2)
                .zIndex(10)
        }
    }
}

private struct HomeEarlierTextRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: SyncTokens.space2) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SyncTokens.teal)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: SyncTokens.space1) {
                        Text(clipboardDisplayText(entry.content, max: 200))
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppSurfaces.onSurface(colorScheme))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, SyncTokens.space6)
                        Text(relativeTime(entry.createdAt))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SyncTokens.slateSecondary)
                    }
                }
                .padding(SyncTokens.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                        .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            ClipboardItemActionMenu(entry: entry)
                .padding(SyncTokens.space2)
                .zIndex(10)
        }
    }
}

private struct HomeEarlierImageRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry
    let serverURL: String
    let accessToken: String?
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: SyncTokens.space2) {
                    ClipboardImageThumb(
                        entry: entry,
                        serverURL: serverURL,
                        accessToken: accessToken,
                        maxHeight: 80
                    )
                    .frame(maxWidth: .infinity)
                    Text("Image · \(relativeTime(entry.createdAt))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SyncTokens.slateSecondary)
                }
                .padding(SyncTokens.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                        .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            ClipboardItemActionMenu(entry: entry)
                .padding(SyncTokens.space2)
                .zIndex(10)
        }
    }
}
