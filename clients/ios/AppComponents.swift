// AppComponents.swift — Shared UI matching Android AppComponents.kt

import SwiftUI

// MARK: - Cards

struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var accentBorder: Color? = nil
    var hero: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space4) {
            content
        }
        .padding(SyncTokens.space6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .floatingCard(hero: hero || accentBorder != nil)
        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusContainerLg))
        .overlay(
            RoundedRectangle(cornerRadius: SyncTokens.radiusContainerLg)
                .stroke(accentBorder ?? Color.clear, lineWidth: accentBorder == nil ? 0 : 1)
        )
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
        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusContainer))
        .overlay(
            RoundedRectangle(cornerRadius: SyncTokens.radiusContainer)
                .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.05), radius: 6, y: 2)
    }
}

/** One UI — multiple rows inside a single large rounded container. */
struct ContainerGroup<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, SyncTokens.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .floatingCard()
        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusContainerLg))
        .overlay(
            RoundedRectangle(cornerRadius: SyncTokens.radiusContainerLg)
                .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
        )
    }
}

struct ContainerGroupItem<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var showDivider: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, SyncTokens.space5)
                .padding(.vertical, SyncTokens.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showDivider {
                Divider()
                    .overlay(AppSurfaces.cardBorder(colorScheme))
                    .padding(.horizontal, SyncTokens.space5)
            }
        }
    }
}

struct AppSectionTitle: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(SyncFont.label())
            .tracking(1.2)
            .foregroundStyle(SyncTokens.slateMuted)
            .padding(.bottom, SyncTokens.space2)
    }
}

/// Web ds-btn--ghost.ds-btn--sm
struct GhostButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SyncFont.caption())
                .foregroundStyle(SyncTokens.slateSecondary)
                .padding(.vertical, SyncTokens.space2)
                .padding(.horizontal, SyncTokens.space4)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: SyncTokens.radiusSm)
                        .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct AppCardTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var body: some View {
        Text(title)
            .font(SyncFont.titleLg())
            .foregroundStyle(AppSurfaces.onSurface(colorScheme))
    }
}

struct AppCardDesc: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        Text(text)
            .font(SyncFont.bodySm())
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
                    .font(SyncFont.body().weight(.semibold))
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
            .font(SyncFont.bodySm().weight(.semibold))
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
                    .font(SyncFont.caption())
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
                    HStack(spacing: SyncTokens.space2) {
                        ProgressView().tint(.white)
                        Text(text)
                            .font(SyncFont.body().weight(.semibold))
                            .foregroundStyle(.white)
                    }
                } else {
                    Text(text)
                        .font(SyncFont.body().weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: enabled && !loading
                        ? [SyncTokens.teal, SyncTokens.tealLight]
                        : [SyncTokens.teal.opacity(0.4), SyncTokens.tealLight.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusButton))
            .shadow(color: SyncTokens.teal.opacity(0.25), radius: 8, y: 4)
        }
        .disabled(!enabled || loading)
        .buttonStyle(PressableButtonStyle())
    }
}

struct LoginHero: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: SyncTokens.space4) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        colors: [SyncTokens.teal.opacity(0.12), Color.white.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusXl))
                .overlay(
                    RoundedRectangle(cornerRadius: SyncTokens.radiusXl)
                        .stroke(Color.white.opacity(0.85), lineWidth: 1)
                )
                .shadow(color: SyncTokens.teal.opacity(0.15), radius: 12, y: 6)

            Text("SyncBridge")
                .font(SyncFont.title2xl())
                .tracking(-0.3)
                .foregroundStyle(AppSurfaces.onSurface(colorScheme))

            Text("Enter your PIN to unlock")
                .font(SyncFont.bodySm())
                .foregroundStyle(SyncTokens.slateSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, SyncTokens.space3)
    }
}

struct LoginPinField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space2) {
            SecureField("PIN", text: $text)
                .keyboardType(.numberPad)
                .font(SyncFont.bodySm())
                .padding(.horizontal, SyncTokens.space4)
                .padding(.vertical, SyncTokens.space3)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusInput))
                .overlay(
                    RoundedRectangle(cornerRadius: SyncTokens.radiusInput)
                        .stroke(error != nil ? SyncTokens.danger : AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                )

            if let error {
                Text(error)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SyncTokens.danger)
            }
        }
    }
}

struct LoginCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space5) {
            content
        }
        .padding(.horizontal, SyncTokens.space6)
        .padding(.vertical, SyncTokens.space8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurfaces.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: SyncTokens.radiusCard)
                .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.55 : 0.18), radius: 24, y: 12)
    }
}

struct AppEmptyState: View {
    var illustration: EmptyArt = .inbox
    let title: String
    let description: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        AppCard(hero: true) {
            VStack(spacing: SyncTokens.space4) {
                EmptyIllustration(variant: illustration)
                Text(title)
                    .font(SyncFont.titleLg())
                    .multilineTextAlignment(.center)
                Text(description)
                    .font(SyncFont.bodySm())
                    .foregroundStyle(SyncTokens.slateSecondary)
                    .multilineTextAlignment(.center)
                if let actionTitle, let action {
                    PrimaryButton(text: actionTitle, action: action)
                }
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
                    .font(SyncFont.bodySm())
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
                .font(SyncFont.bodySm())
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

struct ClipboardCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry
    let onCopy: () -> Void
    let onDelete: () -> Void
    var serverURL: String? = nil
    var accessToken: String? = nil
    var deviceName: String? = nil
    var transferMode: String? = nil
    var copied: Bool = false
    var embeddedInGroup: Bool = false
    var onPin: (() -> Void)? = nil
    var onPreview: (() -> Void)? = nil

    private var isImage: Bool { isImageContentType(entry.contentType) }
    private var large: Bool { !isImage && entry.content.count > 180 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: SyncTokens.space2) {
                if deviceName != nil || entry.pinned || transferMode != nil || onPin != nil || onPreview != nil {
                    HStack {
                        HStack(spacing: SyncTokens.space2) {
                            if let deviceName {
                                PremiumChip(label: deviceName, variant: .neutral)
                            }
                            if entry.pinned {
                                PremiumChip(label: "Pinned", variant: .primary)
                            }
                            if let transferMode {
                                TransferBadge(transferMode: transferMode)
                            }
                        }
                        Spacer()
                        HStack(spacing: SyncTokens.space1) {
                            if let onPreview {
                                GhostButton(title: "Preview", action: onPreview)
                            }
                            if let onPin {
                                GhostButton(title: entry.pinned ? "Unpin" : "Pin", action: onPin)
                            }
                        }
                    }
                }

                Button(action: onCopy) {
                    VStack(alignment: .leading, spacing: SyncTokens.space2) {
                        if isImage, let serverURL, let accessToken {
                            ClipboardImageThumb(
                                entry: entry,
                                serverURL: serverURL,
                                accessToken: accessToken,
                                maxHeight: 180
                            )
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusLg))
                        } else {
                            Text(clipboardDisplayText(entry.content, max: large ? 480 : 160))
                                .font(large ? SyncFont.body() : SyncFont.bodySm())
                                .lineLimit(large ? 8 : 4)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("\(relativeTime(entry.createdAt)) · \(isImage ? "Image" : "Text") · Tap to copy")
                            .font(SyncFont.caption())
                            .foregroundStyle(SyncTokens.slateMuted)
                    }
                    .padding(embeddedInGroup ? SyncTokens.space5 : SyncTokens.space4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(ClipboardCardSurfaceModifier(
                        colorScheme: colorScheme,
                        embeddedInGroup: embeddedInGroup,
                        copied: copied,
                        pinned: entry.pinned
                    ))
                }
                .buttonStyle(PressableButtonStyle())
            }

            if copied {
                ZStack {
                    if !embeddedInGroup {
                        RoundedRectangle(cornerRadius: SyncTokens.radiusContainer)
                            .fill(SyncTokens.success.opacity(0.12))
                    }
                    Text("✓ Copied")
                        .font(SyncFont.bodySm().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, SyncTokens.space4)
                        .padding(.vertical, SyncTokens.space2)
                        .background(SyncTokens.success)
                        .clipShape(Capsule())
                }
                .allowsHitTesting(false)
            }

            ItemDeleteButton(overlay: true, action: onDelete)
                .padding(SyncTokens.space2)
        }
        .if(!embeddedInGroup) { view in
            view.floatingCard()
        }
    }
}

private struct ClipboardCardSurfaceModifier: ViewModifier {
    let colorScheme: ColorScheme
    let embeddedInGroup: Bool
    let copied: Bool
    let pinned: Bool

    func body(content: Content) -> some View {
        if embeddedInGroup {
            content
        } else {
            content
                .background(AppSurfaces.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusContainer))
                .overlay(
                    RoundedRectangle(cornerRadius: SyncTokens.radiusContainer)
                        .stroke(
                            copied ? SyncTokens.success : (pinned ? SyncTokens.indigo.opacity(0.35) : AppSurfaces.cardBorder(colorScheme)),
                            lineWidth: 1
                        )
                )
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
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
                        .font(SyncFont.bodySm().weight(selected ? .semibold : .regular))
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
