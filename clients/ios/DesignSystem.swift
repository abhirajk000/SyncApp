// DesignSystem.swift — Matches Android SyncTokens + solid surfaces (no glass blur).

import SwiftUI

enum SyncTokens {
    static let teal = Color(red: 0.05, green: 0.58, blue: 0.53)
    static let tealLight = Color(red: 0.08, green: 0.72, blue: 0.65)
    static let tealDark = Color(red: 0.18, green: 0.83, blue: 0.75)
    static let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    static let success = Color(red: 0.02, green: 0.59, blue: 0.41)
    static let danger = Color(red: 0.86, green: 0.15, blue: 0.15)
    static let slateBg = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let slateText = Color(red: 0.05, green: 0.07, blue: 0.13)
    static let slateSecondary = Color(red: 0.36, green: 0.42, blue: 0.51)
    static let slateMuted = Color(red: 0.55, green: 0.61, blue: 0.71)
    static let cardBorder = Color(red: 0.89, green: 0.91, blue: 0.94)
    static let violet = Color(red: 0.49, green: 0.23, blue: 0.93)
    static let dockInactive = Color(red: 0.58, green: 0.64, blue: 0.72)
    static let dockActiveGreen = Color(red: 0.08, green: 0.50, blue: 0.24)
    static let dockActiveBg = Color(red: 0.73, green: 0.97, blue: 0.82, opacity: 0.9)
    static let dockActiveBorder = Color(red: 0.29, green: 0.87, blue: 0.50, opacity: 0.55)

    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space8: CGFloat = 32
    static let space10: CGFloat = 40
    static let headerHeight: CGFloat = 64
    static let dockHeight: CGFloat = 66

    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 14
    static let radiusLg: CGFloat = 20
    static let radiusXl: CGFloat = 28
}

enum AppSurfaces {
    static func pageBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.03, green: 0.05, blue: 0.09) : SyncTokens.slateBg
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.07, green: 0.09, blue: 0.15) : .white
    }

    static func cardBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.12, green: 0.16, blue: 0.23) : SyncTokens.cardBorder
    }

    static func surfaceVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.10, green: 0.14, blue: 0.20) : Color(red: 0.93, green: 0.95, blue: 0.97)
    }

    static func dock(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.07, green: 0.09, blue: 0.15) : .white
    }

    static func onSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.95, green: 0.96, blue: 0.99) : SyncTokens.slateText
    }

    static func onSurfaceVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.58, green: 0.64, blue: 0.72) : SyncTokens.slateSecondary
    }
}

// Legacy alias
typealias DS = DesignTokensLegacy

enum DesignTokensLegacy {
    enum Color {
        static let primary = SyncTokens.teal
        static let danger = SyncTokens.danger
        static let success = SyncTokens.success
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
        static let lg = SyncTokens.radiusLg
    }
    enum Font {
        static func display() -> SwiftUI.Font { .system(size: 22, weight: .bold, design: .rounded) }
        static func title() -> SwiftUI.Font { .system(size: 18, weight: .bold, design: .rounded) }
        static func body() -> SwiftUI.Font { .system(size: 14, weight: .regular, design: .rounded) }
        static func caption() -> SwiftUI.Font { .system(size: 12, weight: .medium, design: .rounded) }
        static func label() -> SwiftUI.Font { .system(size: 11, weight: .bold, design: .rounded) }
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        AppSurfaces.pageBackground(colorScheme).ignoresSafeArea()
    }
}
