// MenuBarLayout.swift — Popover dimensions and spacing tuned for menu bar use.

import CoreGraphics

enum MenuBarLayout {
    static let width: CGFloat = 420
    static let height: CGFloat = 648
    static let headerHeight: CGFloat = 44
    static let dockBarHeight: CGFloat = 58
    static let dockFabSize: CGFloat = 52
    static let dockFabSlotWidth: CGFloat = 72
    static let dockNavHeight: CGFloat = 78
    static let windowDefaultWidth: CGFloat = 440
    static let windowDefaultHeight: CGFloat = 720
    static let windowMinWidth: CGFloat = 380
    static let windowMinHeight: CGFloat = 560
    static let popoverContentHeight: CGFloat = height
    static let contentHeight: CGFloat = popoverContentHeight - headerHeight - dockNavHeight - 2
}
