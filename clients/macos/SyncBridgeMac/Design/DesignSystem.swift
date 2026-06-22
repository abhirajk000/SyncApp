// DesignSystem.swift — Premium SyncBridge tokens

import SwiftUI

enum DS {
    enum Color {
        static let primary = SwiftUI.Color(red: 0.05, green: 0.58, blue: 0.53)
        static let primaryLight = SwiftUI.Color(red: 0.08, green: 0.72, blue: 0.65)
        static let primaryDark = SwiftUI.Color(red: 0.18, green: 0.83, blue: 0.75)
        static let secondary = SwiftUI.Color(red: 0.31, green: 0.27, blue: 0.90)
        static let success = SwiftUI.Color(red: 0.02, green: 0.59, blue: 0.41)
        static let warning = SwiftUI.Color(red: 0.85, green: 0.47, blue: 0.02)
        static let danger = SwiftUI.Color(red: 0.86, green: 0.15, blue: 0.15)
        static let bg = SwiftUI.Color(red: 0.96, green: 0.97, blue: 0.99)
        static let card = SwiftUI.Color.white
        static let text = SwiftUI.Color(red: 0.05, green: 0.07, blue: 0.13)
        static let muted = SwiftUI.Color(red: 0.39, green: 0.45, blue: 0.55)
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
    }

    enum Font {
        static func display() -> SwiftUI.Font { .system(size: 22, weight: .bold, design: .rounded) }
        static func title() -> SwiftUI.Font { .system(size: 18, weight: .bold, design: .rounded) }
        static func headline() -> SwiftUI.Font { .system(size: 15, weight: .semibold, design: .rounded) }
        static func body() -> SwiftUI.Font { .system(size: 14, weight: .regular, design: .rounded) }
        static func caption() -> SwiftUI.Font { .system(size: 12, weight: .medium, design: .rounded) }
        static func label() -> SwiftUI.Font { .system(size: 11, weight: .bold, design: .rounded) }
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color.primary, Color.primaryLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color.primary.opacity(0.14), Color.secondary.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Premium components

struct AppCard<Content: View>: View {
    var hero: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(DS.Space.lg)
            .background {
                if hero {
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(DS.heroGradient)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(.background)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(hero ? DS.Color.primary.opacity(0.2) : Color.primary.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: hero ? DS.Color.primary.opacity(0.12) : .black.opacity(0.05), radius: hero ? 12 : 6, y: hero ? 6 : 3)
    }
}

struct AppButton: View {
    enum Variant { case primary, secondary, ghost, danger }
    let title: String
    var variant: Variant = .primary
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Font.body().weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Space.sm + 2)
                .padding(.horizontal, DS.Space.lg)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background { background }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: variant == .primary ? DS.Color.primary.opacity(0.25) : .clear, radius: 8, y: 4)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.primaryGradient)
        case .secondary:
            RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.Color.secondary.opacity(0.12))
        case .ghost:
            RoundedRectangle(cornerRadius: DS.Radius.md).fill(Color.primary.opacity(0.05))
        case .danger:
            RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.Color.danger.opacity(0.12))
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return DS.Color.secondary
        case .ghost: return .primary
        case .danger: return DS.Color.danger
        }
    }
}

struct AppBadge: View {
    enum Status { case connected, disconnected, syncing, online, offline }
    let status: Status
    var label: String?

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            Circle().fill(bg).frame(width: 6, height: 6)
            Text(label ?? defaultLabel)
                .font(DS.Font.label())
        }
        .padding(.horizontal, DS.Space.sm + 2)
        .padding(.vertical, DS.Space.xs + 2)
        .background(bg.opacity(0.12))
        .foregroundStyle(bg)
        .clipShape(Capsule())
    }

    private var bg: Color {
        switch status {
        case .connected, .online: return DS.Color.success
        case .disconnected, .offline: return DS.Color.danger
        case .syncing: return DS.Color.warning
        }
    }

    private var defaultLabel: String {
        switch status {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .syncing: return "Syncing"
        case .online: return "Online"
        case .offline: return "Offline"
        }
    }
}

struct AppEmptyState: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(DS.Color.primary)
                .frame(width: 64, height: 64)
                .background(DS.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Color.primary.opacity(0.15)))
            Text(title).font(DS.Font.title())
            Text(description)
                .font(DS.Font.caption())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
            if let actionTitle, let action {
                AppButton(title: actionTitle, action: action).frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Space.xl)
    }
}

struct AppSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(DS.Font.label())
            .foregroundStyle(.secondary)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Space.lg)
            .padding(.top, DS.Space.md)
            .padding(.bottom, DS.Space.xs)
    }
}

struct PremiumTextField: View {
    var label: String = ""
    @Binding var text: String
    var secure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if !label.isEmpty {
                Text(label).font(DS.Font.caption()).foregroundStyle(.secondary)
            }
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(DS.Font.body())
            .padding(DS.Space.md)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(Color.primary.opacity(0.08)))
        }
    }
}
