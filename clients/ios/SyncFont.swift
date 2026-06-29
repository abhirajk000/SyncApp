// SyncFont.swift — Outfit typography (design/tokens.json)

import SwiftUI

enum SyncFont {
    private static let family = "Outfit"

    static func outfit(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let w: CGFloat = switch weight {
        case .bold, .heavy, .black: 700
        case .semibold: 600
        case .medium: 500
        default: 400
        }
        return .custom(family, size: size).weight(weight)
    }

    static func display() -> Font { outfit(size: 40, weight: .bold) }
    static func title2xl() -> Font { outfit(size: 24, weight: .bold) }
    static func titleXl() -> Font { outfit(size: 20, weight: .semibold) }
    static func titleLg() -> Font { outfit(size: 18, weight: .semibold) }
    static func body() -> Font { outfit(size: 16, weight: .regular) }
    static func bodySm() -> Font { outfit(size: 14, weight: .regular) }
    static func caption() -> Font { outfit(size: 12, weight: .medium) }
    static func label() -> Font { outfit(size: 11, weight: .bold) }
    static func micro() -> Font { outfit(size: 9, weight: .medium) }
    static func dockIcon(selected: Bool) -> Font { outfit(size: 18, weight: selected ? .bold : .semibold) }
    static func dockFab() -> Font { outfit(size: 22, weight: .semibold) }
}
