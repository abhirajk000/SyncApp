// DesignSystem.swift — SyncBridge global tokens (design/tokens.json)

import SwiftUI

enum SyncTokens {
    // Colors — light (dark via AppSurfaces)
    static let primary = Color(red: 0.05, green: 0.58, blue: 0.53)
    static let teal = primary
    static let tealLight = Color(red: 0.08, green: 0.72, blue: 0.65)
    static let tealDark = Color(red: 0.18, green: 0.83, blue: 0.75)
    static let secondary = Color(red: 0.31, green: 0.27, blue: 0.90)
    static let indigo = secondary
    static let success = Color(red: 0.02, green: 0.59, blue: 0.41)
    static let warning = Color(red: 0.85, green: 0.47, blue: 0.02)
    static let danger = Color(red: 0.86, green: 0.15, blue: 0.15)
    static let background = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let slateBg = background
    static let textPrimary = Color(red: 0.05, green: 0.07, blue: 0.13)
    static let slateText = textPrimary
    static let textSecondary = Color(red: 0.36, green: 0.42, blue: 0.51)
    static let slateSecondary = textSecondary
    static let textMuted = Color(red: 0.55, green: 0.61, blue: 0.71)
    static let slateMuted = textMuted
    static let cardBorder = Color(red: 0.89, green: 0.91, blue: 0.94)
    static let accent = Color(red: 0.49, green: 0.23, blue: 0.93)
    static let violet = accent
    static let dockInactive = Color(red: 0.58, green: 0.64, blue: 0.72)
    static let dockActiveGreen = Color(red: 0.08, green: 0.50, blue: 0.24)
    static let dockActiveBg = Color(red: 0.73, green: 0.97, blue: 0.82, opacity: 0.9)
    static let dockActiveBorder = Color(red: 0.29, green: 0.87, blue: 0.50, opacity: 0.55)

    // Spacing — 8pt grid
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space8: CGFloat = 32
    static let space10: CGFloat = 40
    static let space12: CGFloat = 48

    // Layout
    static let headerHeight: CGFloat = 64
    static let dockHeight: CGFloat = 66
    static let bottomNavHeight: CGFloat = 72

    // Radius
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 14
    static let radiusInput: CGFloat = 18
    static let radiusButton: CGFloat = 20
    static let radiusLg: CGFloat = 20
    static let radiusContainerInner: CGFloat = 20
    static let radiusContainerSm: CGFloat = 24
    static let radiusCard: CGFloat = 28
    static let radiusContainer: CGFloat = 28
    static let radiusDialog: CGFloat = 32
    static let radiusContainerLg: CGFloat = 32
    static let radiusXl: CGFloat = 32
    static let radiusChip: CGFloat = 9999

    // Shadows
    static let shadowSmallRadius: CGFloat = 4
    static let shadowMediumRadius: CGFloat = 12
    static let shadowLargeRadius: CGFloat = 24
    static let shadowFloatingRadius: CGFloat = 32

    // Icon sizes
    static let iconSm: CGFloat = 16
    static let iconMd: CGFloat = 20
    static let iconBase: CGFloat = 24
    static let iconLg: CGFloat = 28
    static let iconXl: CGFloat = 32
    static let icon2xl: CGFloat = 40

    // Animation (seconds)
    static let durationFast: Double = 0.15
    static let durationNormal: Double = 0.25
    static let durationSlow: Double = 0.35
    static let durationSlower: Double = 0.5
}

enum AppSurfaces {
    static func pageBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.03, green: 0.05, blue: 0.09) : SyncTokens.background
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.07, green: 0.09, blue: 0.15).opacity(0.72) : Color.white.opacity(0.72)
    }

    static func cardBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.08)
    }

    static func surfaceVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.10, green: 0.14, blue: 0.20) : Color(red: 0.93, green: 0.95, blue: 0.97)
    }

    static func dockFillTop(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.11, green: 0.13, blue: 0.20).opacity(0.92) : Color.white.opacity(0.92)
    }

    static func dockFillBottom(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.05, green: 0.06, blue: 0.11).opacity(0.96) : Color(red: 0.97, green: 0.98, blue: 0.99).opacity(0.88)
    }

    static func onSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.95, green: 0.96, blue: 0.99) : SyncTokens.textPrimary
    }

    static func onSurfaceVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.58, green: 0.64, blue: 0.72) : SyncTokens.textSecondary
    }
}

typealias DS = DesignTokensLegacy

enum DesignTokensLegacy {
    enum Color {
        static let primary = SyncTokens.primary
        static let danger = SyncTokens.danger
        static let success = SyncTokens.success
        static let warning = SyncTokens.warning
    }
    enum Space {
        static let sm = SyncTokens.space2
        static let md = SyncTokens.space3
        static let lg = SyncTokens.space4
        static let xl = SyncTokens.space6
        static let xxl = SyncTokens.space8
    }
    enum Radius {
        static let sm = SyncTokens.radiusSm
        static let md = SyncTokens.radiusMd
        static let lg = SyncTokens.radiusButton
        static let xl = SyncTokens.radiusCard
    }
    enum Font {
        static func display() -> SwiftUI.Font { .system(size: 24, weight: .bold, design: .rounded) }
        static func title() -> SwiftUI.Font { .system(size: 18, weight: .semibold, design: .rounded) }
        static func body() -> SwiftUI.Font { .system(size: 16, weight: .regular, design: .rounded) }
        static func caption() -> SwiftUI.Font { .system(size: 12, weight: .medium, design: .rounded) }
        static func label() -> SwiftUI.Font { .system(size: 11, weight: .bold, design: .rounded) }
    }
}

struct LiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var drift: CGFloat = 0

    var body: some View {
        AppSurfaces.pageBackground(colorScheme)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [SyncTokens.teal.opacity(colorScheme == .dark ? 0.10 : 0.14), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geo.size.width * 0.55
                                )
                            )
                            .frame(width: geo.size.width * 1.1, height: geo.size.width * 1.1)
                            .position(x: geo.size.width * 0.12 + drift, y: geo.size.height * 0.08)
                            .blur(radius: 48)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [SyncTokens.indigo.opacity(0.10), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geo.size.width * 0.45
                                )
                            )
                            .frame(width: geo.size.width * 0.95, height: geo.size.width * 0.95)
                            .position(x: geo.size.width * 0.88 - drift * 0.6, y: geo.size.height * 0.92)
                            .blur(radius: 42)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [SyncTokens.accent.opacity(0.07), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: geo.size.width * 0.35
                                )
                            )
                            .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                            .position(x: geo.size.width * 0.78, y: geo.size.height * 0.18 + drift * 0.4)
                            .blur(radius: 36)
                    }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: true)) {
                    drift = 18
                }
            }
            .ignoresSafeArea()
    }
}

struct AppBackground: View {
    var body: some View {
        LiquidBackground()
    }
}

struct BottomDockBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 420
        let sy = rect.height / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }
        var path = Path()
        path.move(to: p(36, 64))
        path.addCurve(to: p(4, 32), control1: p(18, 64), control2: p(4, 50))
        path.addLine(to: p(4, 22))
        path.addCurve(to: p(26, 0), control1: p(4, 10), control2: p(14, 0))
        path.addLine(to: p(148, 0))
        path.addCurve(to: p(178, 8), control1: p(162, 0), control2: p(172, 3))
        path.addCurve(to: p(210, 24.5), control1: p(186, 16), control2: p(196, 21))
        path.addCurve(to: p(242, 8), control1: p(224, 21), control2: p(234, 16))
        path.addCurve(to: p(272, 0), control1: p(248, 3), control2: p(258, 0))
        path.addLine(to: p(394, 0))
        path.addCurve(to: p(416, 22), control1: p(406, 0), control2: p(416, 10))
        path.addLine(to: p(416, 32))
        path.addCurve(to: p(384, 64), control1: p(416, 50), control2: p(402, 64))
        path.addLine(to: p(36, 64))
        path.closeSubpath()
        return path
    }
}
