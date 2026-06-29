// PremiumComponents.swift — Phase 3 non-default UI primitives (iOS)

import SwiftUI

// MARK: - Search

struct PremiumSearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    var placeholder: String = "Search…"

    var body: some View {
        HStack(spacing: SyncTokens.space2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SyncTokens.slateMuted)
            TextField(placeholder, text: $text)
                .font(SyncFont.bodySm())
                .foregroundStyle(AppSurfaces.onSurface(colorScheme))
        }
        .padding(.horizontal, SyncTokens.space4)
        .frame(height: 44)
        .background(AppSurfaces.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusInput))
        .overlay(
            RoundedRectangle(cornerRadius: SyncTokens.radiusInput)
                .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Progress

struct PremiumLinearProgress: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SyncTokens.cardBorder)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [SyncTokens.teal, SyncTokens.tealLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Chips

enum PremiumChipVariant { case success, warning, danger, primary, neutral }

struct PremiumChip: View {
    let label: String
    var variant: PremiumChipVariant = .neutral

    private var colors: (bg: Color, fg: Color) {
        switch variant {
        case .success: return (SyncTokens.success.opacity(0.12), SyncTokens.success)
        case .warning: return (SyncTokens.warning.opacity(0.12), SyncTokens.warning)
        case .danger: return (SyncTokens.danger.opacity(0.12), SyncTokens.danger)
        case .primary: return (SyncTokens.teal.opacity(0.12), SyncTokens.teal)
        case .neutral: return (SyncTokens.slateMuted.opacity(0.12), SyncTokens.slateSecondary)
        }
    }

    var body: some View {
        Text(label)
            .font(SyncFont.caption().weight(.semibold))
            .foregroundStyle(colors.fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colors.bg)
            .clipShape(Capsule())
    }
}

// MARK: - Skeleton

struct PremiumSkeleton: View {
    var rows: Int = 4
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: SyncTokens.space3) {
            RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                .fill(shimmer)
                .frame(width: 140, height: 24)
            ForEach(0..<rows, id: \.self) { _ in
                RoundedRectangle(cornerRadius: SyncTokens.radiusCard)
                    .fill(shimmer)
                    .frame(height: 56)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private var shimmer: LinearGradient {
        LinearGradient(
            colors: [
                SyncTokens.slateMuted.opacity(0.15),
                SyncTokens.slateMuted.opacity(0.28),
                SyncTokens.slateMuted.opacity(0.15),
            ],
            startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
            endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
        )
    }
}

// MARK: - Bottom sheet

struct PremiumBottomSheet<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var visible: Bool
    var title: String?
    var onDismiss: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            if visible {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }
                    .transition(.opacity)

                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: SyncTokens.space4) {
                        Capsule()
                            .fill(SyncTokens.cardBorder)
                            .frame(width: 36, height: 4)
                        if let title {
                            HStack {
                                Text(title).font(SyncFont.titleLg())
                                Spacer()
                                PremiumIconButton(systemName: "xmark", action: onDismiss)
                            }
                        }
                        content
                    }
                    .padding(SyncTokens.space6)
                    .frame(maxWidth: .infinity)
                    .background(AppSurfaces.card(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusCard, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SyncTokens.radiusCard, style: .continuous)
                            .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: SyncTokens.durationNormal), value: visible)
    }
}

// MARK: - Icon button

struct PremiumIconButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    var tint: Color = SyncTokens.slateSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modal overlay

struct PremiumAppModalOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let message: String
    let confirmText: String
    let dismissText: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: SyncTokens.space4) {
                Text(title).font(SyncFont.titleLg()).foregroundStyle(AppSurfaces.onSurface(colorScheme))
                Text(message)
                    .font(SyncFont.bodySm())
                    .foregroundStyle(SyncTokens.slateSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: SyncTokens.space3) {
                    GhostButton(title: dismissText, action: onDismiss)
                    PrimaryButton(text: confirmText, action: onConfirm)
                }
            }
            .padding(SyncTokens.space6)
            .frame(maxWidth: 340)
            .background(AppSurfaces.card(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusDialog))
            .overlay(
                RoundedRectangle(cornerRadius: SyncTokens.radiusDialog)
                    .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
        }
    }
}

typealias AppSkeleton = PremiumSkeleton
