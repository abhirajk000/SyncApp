// DesignSystem.swift — Premium (iOS) + glass

import SwiftUI

typealias DS = DesignTokens

enum DesignTokens {
    enum Color {
        static let primary = SwiftUI.Color(red: 0.05, green: 0.58, blue: 0.53)
        static let primaryLight = SwiftUI.Color(red: 0.08, green: 0.72, blue: 0.65)
        static let secondary = SwiftUI.Color(red: 0.31, green: 0.27, blue: 0.90)
        static let success = SwiftUI.Color(red: 0.02, green: 0.59, blue: 0.41)
        static let danger = SwiftUI.Color(red: 0.86, green: 0.15, blue: 0.15)
        static let bg = SwiftUI.Color(red: 0.96, green: 0.97, blue: 0.99)
        static let activeGreen = SwiftUI.Color(red: 0.08, green: 0.50, blue: 0.24)
        static let activeGreenBg = SwiftUI.Color(red: 0.73, green: 0.97, blue: 0.82)
    }
    enum Glass {
        static let border = SwiftUI.Color.white.opacity(0.85)
        static let shadow = SwiftUI.Color.black.opacity(0.08)
    }
    enum Space {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    enum Radius {
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let full: CGFloat = 9999
    }
    enum Font {
        static func display() -> SwiftUI.Font { .system(size: 22, weight: .bold, design: .rounded) }
        static func title() -> SwiftUI.Font { .system(size: 18, weight: .bold, design: .rounded) }
        static func body() -> SwiftUI.Font { .system(size: 14, weight: .regular, design: .rounded) }
        static func caption() -> SwiftUI.Font { .system(size: 12, weight: .medium, design: .rounded) }
        static func label() -> SwiftUI.Font { .system(size: 11, weight: .bold, design: .rounded) }
    }
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [Color.primary, Color.primaryLight], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [Color.primary.opacity(0.14), Color.secondary.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct LiquidBackground: View {
    var body: some View {
        ZStack {
            DS.Color.bg.ignoresSafeArea()
            Circle()
                .fill(RadialGradient(colors: [DS.Color.primary.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 260))
                .frame(width: 520, height: 520)
                .offset(x: -120, y: -180)
                .blur(radius: 40)
            Circle()
                .fill(RadialGradient(colors: [DS.Color.secondary.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: 220))
                .frame(width: 440, height: 440)
                .offset(x: 140, y: 220)
                .blur(radius: 36)
        }
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DS.Radius.lg
    var hero: Bool = false
    func body(content: Content) -> some View {
        content
            .background {
                if hero {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(DS.heroGradient)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(.ultraThinMaterial)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(hero ? DS.Color.primary.opacity(0.22) : DS.Glass.border.opacity(0.55), lineWidth: 1))
            .shadow(color: hero ? DS.Color.primary.opacity(0.14) : DS.Glass.shadow, radius: hero ? 14 : 10, y: hero ? 6 : 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = DS.Radius.lg, hero: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, hero: hero))
    }
}

struct AppCard<Content: View>: View {
    var hero: Bool = false
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(DS.Space.lg).glassCard(hero: hero)
    }
}

struct AppButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(DS.Font.body().weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, DS.Space.md)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.primaryGradient))
        .shadow(color: DS.Color.primary.opacity(0.25), radius: 8, y: 4)
        .disabled(disabled).opacity(disabled ? 0.45 : 1)
    }
}

struct AppEmptyState: View {
    let icon: String
    let title: String
    let description: String
    var body: some View {
        VStack(spacing: DS.Space.lg) {
            Image(systemName: icon).font(.title2).foregroundStyle(DS.Color.primary)
                .frame(width: 56, height: 56)
                .glassCard(cornerRadius: DS.Radius.lg, hero: true)
            Text(title).font(DS.Font.title())
            Text(description).font(DS.Font.caption()).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(DS.Space.xl)
    }
}

struct PremiumTextField: View {
    var label: String = ""
    @Binding var text: String
    var secure: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label).font(DS.Font.caption()).foregroundStyle(.secondary)
            }
            Group {
                if secure { SecureField("", text: $text) } else { TextField("", text: $text) }
            }
            .padding(DS.Space.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Glass.border.opacity(0.45)))
        }
    }
}

struct GlassListRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.md)
            .glassCard(cornerRadius: DS.Radius.md)
    }
}
