// PremiumComponents.swift — Phase 3 non-default UI primitives (macOS)

import SwiftUI

struct PremiumSearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    var placeholder: String = "Search…"

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DS.Color.muted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.Font.body())
        }
        .padding(.horizontal, DS.Space.lg)
        .frame(height: 44)
        .glassCard(cornerRadius: DS.Radius.input)
    }
}

struct PremiumLinearProgress: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DS.Color.borderAdaptive(.light).opacity(0.5))
                Capsule()
                    .fill(LinearGradient(colors: [DS.Color.primary, DS.Color.primaryLight], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: 6)
    }
}

enum PremiumChipVariant { case success, warning, danger, primary, neutral }

struct PremiumChip: View {
    let label: String
    var variant: PremiumChipVariant = .neutral

    var body: some View {
        let (bg, fg): (Color, Color) = {
            switch variant {
            case .success: return (DS.Color.success.opacity(0.12), DS.Color.success)
            case .warning: return (DS.Color.warning.opacity(0.12), DS.Color.warning)
            case .danger: return (DS.Color.danger.opacity(0.12), DS.Color.danger)
            case .primary: return (DS.Color.primary.opacity(0.12), DS.Color.primary)
            case .neutral: return (DS.Color.muted.opacity(0.12), DS.Color.muted)
            }
        }()
        Text(label)
            .font(DS.Font.caption().weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bg)
            .clipShape(Capsule())
    }
}

struct PremiumSkeleton: View {
    var rows: Int = 4
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            RoundedRectangle(cornerRadius: DS.Radius.md).fill(shimmer).frame(width: 140, height: 24)
            ForEach(0..<rows, id: \.self) { _ in
                RoundedRectangle(cornerRadius: DS.Radius.card).fill(shimmer).frame(height: 56)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }

    private var shimmer: LinearGradient {
        LinearGradient(
            colors: [DS.Color.muted.opacity(0.15), DS.Color.muted.opacity(0.28), DS.Color.muted.opacity(0.15)],
            startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
            endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
        )
    }
}

struct PremiumIconButton: View {
    let systemName: String
    var tint: Color = DS.Color.muted
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .glassCard(cornerRadius: DS.Radius.full)
        }
        .buttonStyle(.plain)
    }
}

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
            VStack(spacing: DS.Space.lg) {
                Text(title).font(DS.Font.title())
                Text(message).font(DS.Font.caption()).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack(spacing: DS.Space.md) {
                    AppButton(title: dismissText, variant: .ghost, action: onDismiss)
                    AppButton(title: confirmText, variant: .primary, action: onConfirm)
                }
            }
            .padding(DS.Space.xl)
            .frame(maxWidth: 360)
            .adaptiveGlassCard(cornerRadius: DS.Radius.dialog)
        }
    }
}

typealias AppSkeleton = PremiumSkeleton
