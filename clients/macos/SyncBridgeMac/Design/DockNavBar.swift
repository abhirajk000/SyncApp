// DockNavBar.swift — App navigation tabs (shared with DockBottomBar)

import SwiftUI

enum AppNavTab: String, Hashable {
    case cloudSend = "Cloud Send"
    case localSend = "Local Send"
    case clipboard = "Clipboard"
    case files = "Files"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .cloudSend: return "icloud.and.arrow.up"
        case .localSend: return "wifi"
        case .clipboard: return "doc.on.clipboard.fill"
        case .files: return "folder"
        case .settings: return "gearshape"
        }
    }
}

// Top-mounted dock (popover layout — optional)
struct DockNavBar: View {

    @Environment(\.colorScheme) private var colorScheme
    @Binding var selected: AppNavTab

    private let leftTabs: [AppNavTab] = [.cloudSend, .localSend]
    private let rightTabs: [AppNavTab] = [.files, .settings]

    var body: some View {
        ZStack(alignment: .top) {
            dockBar
            clipboardFab
        }
        .frame(height: MenuBarLayout.dockNavHeight)
        .padding(.horizontal, DS.Space.sm)
        .padding(.top, DS.Space.xs)
    }

    private var dockBar: some View {
        ZStack(alignment: .bottom) {
            TopDockBarShape()
                .fill(dockFill)
                .overlay {
                    TopDockBarShape()
                        .stroke(dockStroke, lineWidth: 1)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.42 : 0.14), radius: 18, y: 8)

            HStack(alignment: .bottom, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(leftTabs, id: \.self) { tab in
                        dockItem(tab)
                    }
                }
                .frame(maxWidth: .infinity)

                Color.clear.frame(width: MenuBarLayout.dockFabSlotWidth)

                HStack(spacing: 0) {
                    ForEach(rightTabs, id: \.self) { tab in
                        dockItem(tab)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 8)
        }
        .frame(height: MenuBarLayout.dockBarHeight)
    }

    private var clipboardFab: some View {
        let selected = selected == .clipboard
        return Button {
            self.selected = .clipboard
        } label: {
            ZStack {
                Circle()
                    .fill(DS.Color.primary)
                    .frame(width: MenuBarLayout.dockFabSize, height: MenuBarLayout.dockFabSize)
                    .shadow(color: DS.Color.primary.opacity(selected ? 0.55 : 0.4), radius: selected ? 16 : 12, y: 6)
                    .overlay {
                        if selected {
                            Circle()
                                .stroke(DS.Color.primary.opacity(0.35), lineWidth: 4)
                                .frame(width: MenuBarLayout.dockFabSize + 8, height: MenuBarLayout.dockFabSize + 8)
                        }
                    }

                Image(systemName: AppNavTab.clipboard.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(selected ? 1.06 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
        }
        .buttonStyle(.plain)
        .offset(y: MenuBarLayout.dockFabSize * 0.28)
        .help("Clipboard")
    }

    private func dockItem(_ tab: AppNavTab) -> some View {
        Button {
            selected = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: selected == tab ? .bold : .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 9, weight: selected == tab ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 68, height: 50)
            .foregroundStyle(selected == tab ? activeLabel : inactiveLabel)
            .background {
                if selected == tab {
                    Capsule()
                        .fill(activePillFill)
                        .overlay {
                            Capsule()
                                .stroke(activePillBorder, lineWidth: 1)
                        }
                        .shadow(color: DS.Color.activeGreen.opacity(colorScheme == .dark ? 0.22 : 0.18), radius: 6, y: 2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
    }

    private var dockFill: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.13, blue: 0.20).opacity(0.92),
                    Color(red: 0.05, green: 0.06, blue: 0.11).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color.white.opacity(0.94),
                Color(red: 0.97, green: 0.98, blue: 0.99).opacity(0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var dockStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.85)
    }

    private var inactiveLabel: Color {
        colorScheme == .dark ? Color(red: 0.39, green: 0.45, blue: 0.55) : Color(red: 0.58, green: 0.64, blue: 0.74)
    }

    private var activeLabel: Color {
        colorScheme == .dark ? Color(red: 0.53, green: 0.94, blue: 0.67) : DS.Color.activeGreen
    }

    private var activePillFill: some ShapeStyle {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.28),
                    Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.99, blue: 0.91).opacity(0.95),
                Color(red: 0.73, green: 0.97, blue: 0.82).opacity(0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var activePillBorder: Color {
        Color(red: 0.29, green: 0.87, blue: 0.50).opacity(colorScheme == .dark ? 0.35 : 0.55)
    }
}

// MARK: - Top dock bar shape (web dock flipped for top placement)

private struct TopDockBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 420
        let sy = rect.height / 64

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: (64 - y) * sy)
        }

        var path = Path()
        path.move(to: p(36, 0))
        path.addCurve(to: p(4, 32), control1: p(18, 0), control2: p(4, 14))
        path.addLine(to: p(4, 42))
        path.addCurve(to: p(26, 64), control1: p(4, 54), control2: p(14, 64))
        path.addLine(to: p(148, 64))
        path.addCurve(to: p(178, 56), control1: p(162, 64), control2: p(172, 61))
        path.addCurve(to: p(210, 39.5), control1: p(186, 51), control2: p(196, 43))
        path.addCurve(to: p(242, 56), control1: p(224, 43), control2: p(234, 48))
        path.addCurve(to: p(272, 64), control1: p(248, 61), control2: p(258, 64))
        path.addLine(to: p(394, 64))
        path.addCurve(to: p(416, 32), control1: p(406, 64), control2: p(416, 54))
        path.addLine(to: p(416, 22))
        path.addCurve(to: p(384, 0), control1: p(416, 10), control2: p(402, 0))
        path.addLine(to: p(36, 0))
        path.closeSubpath()
        return path
    }
}
