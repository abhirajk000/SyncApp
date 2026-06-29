// DesignSystem.swift — Premium SyncBridge tokens + glass

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
        static let accent = SwiftUI.Color(red: 0.49, green: 0.23, blue: 0.93)
        static let bgLight = SwiftUI.Color(red: 0.96, green: 0.97, blue: 0.99)
        static let bgDark = SwiftUI.Color(red: 0.03, green: 0.05, blue: 0.09)
        static let cardLight = SwiftUI.Color.white.opacity(0.72)
        static let cardDark = SwiftUI.Color(red: 0.07, green: 0.09, blue: 0.15).opacity(0.72)
        static let textLight = SwiftUI.Color(red: 0.05, green: 0.07, blue: 0.13)
        static let textDark = SwiftUI.Color(red: 0.95, green: 0.96, blue: 0.99)
        static let muted = SwiftUI.Color(red: 0.55, green: 0.61, blue: 0.71)
        static let activeGreen = SwiftUI.Color(red: 0.08, green: 0.50, blue: 0.24)
        static let activeGreenBg = SwiftUI.Color(red: 0.73, green: 0.97, blue: 0.82)
        static let activeGreenBgDark = SwiftUI.Color(red: 0.08, green: 0.35, blue: 0.18)

        static func bgAdaptive(_ scheme: ColorScheme) -> SwiftUI.Color {
            scheme == .dark ? bgDark : bgLight
        }

        static func cardAdaptive(_ scheme: ColorScheme) -> SwiftUI.Color {
            scheme == .dark ? cardDark : cardLight
        }

        static func textAdaptive(_ scheme: ColorScheme) -> SwiftUI.Color {
            scheme == .dark ? textDark : textLight
        }

        static func primaryAdaptive(_ scheme: ColorScheme) -> SwiftUI.Color {
            scheme == .dark ? primaryDark : primary
        }

        static func borderAdaptive(_ scheme: ColorScheme) -> SwiftUI.Color {
            scheme == .dark ? SwiftUI.Color.white.opacity(0.12) : SwiftUI.Color.white.opacity(0.85)
        }
    }

    enum Glass {
        static let border = SwiftUI.Color.white.opacity(0.85)
        static let borderDark = SwiftUI.Color.white.opacity(0.1)
        static let shadow = SwiftUI.Color.black.opacity(0.08)
        static let highlight = SwiftUI.Color.white.opacity(0.65)
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let space5: CGFloat = 20
        static let space10: CGFloat = 40
        static let space12: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let input: CGFloat = 18
        static let button: CGFloat = 20
        static let lg: CGFloat = 20
        static let containerInner: CGFloat = 20
        static let containerSm: CGFloat = 24
        static let card: CGFloat = 28
        static let container: CGFloat = 28
        static let dialog: CGFloat = 32
        static let containerLg: CGFloat = 32
        static let xl: CGFloat = 32
        static let chip: CGFloat = 9999
        static let full: CGFloat = 9999
    }

    enum Icon {
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let base: CGFloat = 24
        static let lg: CGFloat = 28
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
    }

    enum Duration {
        static let fast: Double = 0.15
        static let normal: Double = 0.25
        static let slow: Double = 0.35
        static let slower: Double = 0.5
    }

    enum Font {
        static func display() -> SwiftUI.Font { SyncFont.title2xl() }
        static func title() -> SwiftUI.Font { SyncFont.titleLg() }
        static func titleSm() -> SwiftUI.Font { SyncFont.bodySm().weight(.semibold) }
        static func bodySm() -> SwiftUI.Font { SyncFont.bodySm() }
        static func headline() -> SwiftUI.Font { SyncFont.titleLg() }
        static func body() -> SwiftUI.Font { SyncFont.body() }
        static func caption() -> SwiftUI.Font { SyncFont.caption() }
        static func label() -> SwiftUI.Font { SyncFont.label() }
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

// MARK: - Liquid background

struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var drift: CGFloat = 0

    var body: some View {
        DS.Color.bgAdaptive(colorScheme)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [DS.Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.14), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geo.size.width * 0.55
                                )
                            )
                            .frame(width: geo.size.width * 1.1, height: geo.size.width * 1.1)
                            .position(x: geo.size.width * 0.2 + drift, y: geo.size.height * 0.12)
                            .blur(radius: 48)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [DS.Color.secondary.opacity(0.10), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geo.size.width * 0.45
                                )
                            )
                            .frame(width: geo.size.width * 0.95, height: geo.size.width * 0.95)
                            .position(x: geo.size.width * 0.82 - drift * 0.5, y: geo.size.height * 0.88)
                            .blur(radius: 42)
                    }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: true)) {
                    drift = 16
                }
            }
            .clipped()
    }
}

// MARK: - Glass modifier

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = DS.Radius.containerLg
    var hero: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                if hero {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(DS.heroGradient)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(DS.Color.cardAdaptive(colorScheme))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        hero ? DS.Color.primary.opacity(0.22) : DS.Color.borderAdaptive(colorScheme).opacity(0.55),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: hero ? DS.Color.primary.opacity(0.14) : .black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                radius: hero ? 14 : 8,
                y: hero ? 6 : 3
            )
    }
}

extension View {
    func adaptiveGlassCard(cornerRadius: CGFloat = DS.Radius.containerLg, hero: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, hero: hero))
    }

    func glassCard(cornerRadius: CGFloat = DS.Radius.containerLg, hero: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, hero: hero))
    }
}

// MARK: - Premium components

struct AppCard<Content: View>: View {
    var hero: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(DS.Space.lg)
            .glassCard(hero: hero)
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
        .buttonStyle(PressableButtonStyle())
        .background { background }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button))
        .shadow(color: variant == .primary ? DS.Color.primary.opacity(0.25) : .clear, radius: 8, y: 4)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: DS.Radius.button).fill(DS.primaryGradient)
        case .secondary:
            RoundedRectangle(cornerRadius: DS.Radius.button).fill(DS.Color.secondary.opacity(0.12))
        case .ghost:
            RoundedRectangle(cornerRadius: DS.Radius.button).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.button).stroke(DS.Glass.border.opacity(0.4)))
        case .danger:
            RoundedRectangle(cornerRadius: DS.Radius.button).fill(DS.Color.danger.opacity(0.12))
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
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(bg.opacity(0.25)))
        .foregroundStyle(bg)
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
    var illustration: EmptyArt = .inbox
    let title: String
    let description: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.Space.md) {
            EmptyIllustration(variant: illustration)
            Text(title).font(DS.Font.title())
            Text(description)
                .font(DS.Font.caption())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            if let actionTitle, let action {
                AppButton(title: actionTitle, action: action).frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Space.xl)
        .adaptiveGlassCard(cornerRadius: DS.Radius.containerLg, hero: true)
    }
}

/** One UI — grouped rows in one large rounded container. */
struct ContainerGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.vertical, DS.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: DS.Radius.containerLg)
    }
}

struct ContainerGroupItem<Content: View>: View {
    var showDivider: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, DS.Space.space5)
                .padding(.vertical, DS.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showDivider {
                Divider().padding(.horizontal, DS.Space.space5)
            }
        }
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

struct GlassListRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.md)
            .glassCard(cornerRadius: DS.Radius.container)
    }
}

struct PremiumTextField: View {
    @Environment(\.colorScheme) private var colorScheme
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
            .background(DS.Color.cardAdaptive(colorScheme), in: RoundedRectangle(cornerRadius: DS.Radius.containerSm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.containerSm)
                    .stroke(DS.Color.borderAdaptive(colorScheme).opacity(0.45))
            )
        }
    }
}

// MARK: - Segmented tabs

struct SegmentedTabs: View {
    @Environment(\.colorScheme) private var colorScheme
    let options: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            ForEach(options.indices, id: \.self) { index in
                let selected = index == selectedIndex
                Button { selectedIndex = index } label: {
                    Text(options[index])
                        .font(SyncFont.bodySm().weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .white : DS.Color.textAdaptive(colorScheme).opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? DS.Color.primary : DS.Color.cardAdaptive(colorScheme))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selected ? DS.Color.primary : DS.Color.borderAdaptive(colorScheme), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
