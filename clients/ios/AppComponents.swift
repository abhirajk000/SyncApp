// AppComponents.swift — Shared UI matching Android AppComponents.kt

import SwiftUI

// MARK: - Cards

struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var accentBorder: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space4) {
            content
        }
        .padding(SyncTokens.space5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurfaces.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: SyncTokens.radiusLg)
                .stroke(accentBorder ?? AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 2, y: 1)
    }
}

struct GlassListRow<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space1) {
            content
        }
        .padding(.horizontal, SyncTokens.space5)
        .padding(.vertical, SyncTokens.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurfaces.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: SyncTokens.radiusLg)
                .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
        )
    }
}

struct AppSectionTitle: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(SyncTokens.slateMuted)
            .padding(.bottom, SyncTokens.space2)
    }
}

struct AppCardTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(AppSurfaces.onSurface(colorScheme))
    }
}

struct AppCardDesc: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))
            .padding(.top, SyncTokens.space1)
            .padding(.bottom, SyncTokens.space3)
    }
}

struct DestructiveFullWidthButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SyncTokens.space2) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(SyncTokens.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(SyncTokens.danger.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeaderRow: View {
    let title: String
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            AppSectionTitle(title: title)
            Spacer()
            if let actionLabel, let onAction {
                Button(actionLabel, action: onAction)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(SyncTokens.teal)
            }
        }
    }
}

struct IconBadge: View {
    let systemName: String
    var tint: Color = SyncTokens.teal

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusSm))
    }
}

struct ConnectionChip: View {
    let connected: Bool
    let onTap: () -> Void

    var body: some View {
        let color = connected ? SyncTokens.teal : SyncTokens.danger
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(connected ? "Connected" : "Offline")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    let text: String
    var loading: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if loading {
                    ProgressView().tint(.white)
                } else {
                    Text(text)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(SyncTokens.teal.opacity(enabled && !loading ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
        }
        .disabled(!enabled || loading)
        .buttonStyle(.plain)
    }
}

struct AppEmptyState: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        AppCard {
            VStack(spacing: SyncTokens.space4) {
                IconBadge(systemName: icon)
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(SyncTokens.slateSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SyncTokens.space6)
        }
    }
}

struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SyncTokens.space3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(SyncTokens.teal)
                    .frame(width: 44, height: 44)
                    .background(SyncTokens.teal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(SyncTokens.slateSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(SyncTokens.slateMuted)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Latest cards

struct LatestTextCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry?
    var title: String = "Latest text"
    let onCopy: () -> Void

    var body: some View {
        LatestCardShell(
            empty: entry == nil,
            accent: SyncTokens.teal,
            icon: "textformat",
            title: title,
            emptyMessage: "No text yet — copy on any device to sync here."
        ) {
            if let entry {
                Button(action: onCopy) {
                    VStack(alignment: .leading, spacing: SyncTokens.space3) {
                        Text(clipboardDisplayText(entry.content, max: 500))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(AppSurfaces.onSurface(colorScheme))
                            .lineLimit(8)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(SyncTokens.space4)
                            .background(AppSurfaces.surfaceVariant(colorScheme).opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))

                        HStack(spacing: SyncTokens.space2) {
                            Text(relativeTime(entry.createdAt))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))
                            Text("·").foregroundStyle(SyncTokens.slateMuted)
                            Text("Tap to copy")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SyncTokens.teal)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct LatestImageCard: View {
    let entry: ClipboardEntry?
    let serverURL: String
    let accessToken: String?
    var title: String = "Latest image"
    let onCopy: () -> Void

    var body: some View {
        LatestCardShell(
            empty: entry == nil,
            accent: SyncTokens.violet,
            icon: "photo",
            title: title,
            emptyMessage: "No image yet — screenshots and photos sync automatically."
        ) {
            if let entry {
                Button(action: onCopy) {
                    VStack(alignment: .leading, spacing: SyncTokens.space2) {
                        ClipboardImageThumb(
                            entry: entry,
                            serverURL: serverURL,
                            accessToken: accessToken,
                            maxHeight: 200
                        )
                        Text("\(relativeTime(entry.createdAt)) · Tap to copy")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SyncTokens.violet)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LatestCardShell<Content: View>: View {
    let empty: Bool
    let accent: Color
    let icon: String
    let title: String
    let emptyMessage: String
    @ViewBuilder var content: Content

    var body: some View {
        AppCard(accentBorder: empty ? nil : accent.opacity(0.22)) {
            HStack(spacing: SyncTokens.space3) {
                IconBadge(systemName: icon, tint: empty ? SyncTokens.slateMuted : accent)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            if empty {
                Text(emptyMessage)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(SyncTokens.slateSecondary)
                    .padding(.top, SyncTokens.space3)
            } else {
                content.padding(.top, SyncTokens.space3)
            }
        }
    }
}

struct EarlierTextRow: View {
    let entry: ClipboardEntry
    let onCopy: () -> Void

    var body: some View {
        GlassListRow(onTap: onCopy) {
            Text(clipboardDisplayText(entry.content, max: 280))
                .font(.system(size: 14, design: .rounded))
                .lineLimit(3)
            Text(relativeTime(entry.createdAt))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SyncTokens.slateSecondary)
                .padding(.top, SyncTokens.space1)
        }
    }
}

struct EarlierImageRow: View {
    let entry: ClipboardEntry
    let serverURL: String
    let accessToken: String?
    let onCopy: () -> Void

    var body: some View {
        GlassListRow(onTap: onCopy) {
            ClipboardImageThumb(
                entry: entry,
                serverURL: serverURL,
                accessToken: accessToken,
                maxHeight: 120
            )
            Text("Image · \(relativeTime(entry.createdAt)) · Tap to copy")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SyncTokens.violet)
                .padding(.top, SyncTokens.space2)
        }
    }
}

struct SegmentedTabs: View {
    @Environment(\.colorScheme) private var colorScheme
    let options: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: SyncTokens.space2) {
            ForEach(options.indices, id: \.self) { index in
                let selected = index == selectedIndex
                Button {
                    selectedIndex = index
                } label: {
                    Text(options[index])
                        .font(.system(size: 14, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .white : AppSurfaces.onSurfaceVariant(colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? SyncTokens.teal : AppSurfaces.card(colorScheme))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                selected ? SyncTokens.teal : AppSurfaces.cardBorder(colorScheme),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
