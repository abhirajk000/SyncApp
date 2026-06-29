// MenuBarLayout.swift — Shell dimensions (Phase 2 — bottom dock on all platforms)

import CoreGraphics

enum MenuBarLayout {
    static let width: CGFloat = 420
    static let height: CGFloat = 648
    static let headerHeight: CGFloat = 64
    static let dockHeight: CGFloat = 90
    static let windowDefaultWidth: CGFloat = 440
    static let windowDefaultHeight: CGFloat = 720
    static let windowMinWidth: CGFloat = 380
    static let windowMinHeight: CGFloat = 560
    static let popoverContentHeight: CGFloat = height
    static var contentHeight: CGFloat {
        popoverContentHeight - headerHeight - dockHeight - 2
    }
}
