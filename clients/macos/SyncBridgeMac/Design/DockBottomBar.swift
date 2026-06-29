// DockBottomBar.swift — Floating glass bottom nav (matches iOS/Web/Android)

import SwiftUI

struct DockBottomBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let current: AppNavTab
    let onNavigate: (AppNavTab) -> Void

    private let leftTabs: [AppNavTab] = [.cloudSend, .localSend]
    private let rightTabs: [AppNavTab] = [.files, .settings]

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottom) {
                BottomDockBarShape()
                    .fill(
                        LinearGradient(
                            colors: [dockFillTop, dockFillBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        BottomDockBarShape()
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.85), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.42 : 0.14), radius: 20, y: 10)

                HStack(spacing: 0) {
                    HStack {
                        ForEach(leftTabs, id: \.self) { dockItem($0) }
                    }
                    .frame(maxWidth: .infinity)
                    Color.clear.frame(width: 76)
                    HStack {
                        ForEach(rightTabs, id: \.self) { dockItem($0) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }
            .frame(height: DS.Space.space10 + 26)
            .padding(.horizontal, DS.Space.lg)

            clipboardFab
        }
        .padding(.bottom, DS.Space.sm)
    }

    private var clipboardFab: some View {
        let selected = current == .clipboard
        return Button { onNavigate(.clipboard) } label: {
            ZStack {
                Circle()
                    .fill(DS.Color.primary)
                    .frame(width: 64, height: 64)
                    .shadow(color: DS.Color.primary.opacity(selected ? 0.55 : 0.4), radius: selected ? 16 : 12, y: 6)
                    .overlay {
                        if selected {
                            Circle()
                                .stroke(DS.Color.primary.opacity(0.35), lineWidth: 3)
                                .frame(width: 72, height: 72)
                        }
                    }
                Image(systemName: AppNavTab.clipboard.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(selected ? 1.06 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
        }
        .buttonStyle(.plain)
        .offset(y: -10)
        .help("Clipboard")
    }

    private func dockItem(_ tab: AppNavTab) -> some View {
        let selected = current == tab
        return Button { onNavigate(tab) } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(SyncFont.dockIcon(selected: selected))
                Text(tab.rawValue)
                    .font(SyncFont.micro().weight(selected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(selected ? activeLabel : inactiveLabel)
            .frame(width: 72, height: 52)
            .background {
                if selected {
                    Capsule()
                        .fill(activePillFill)
                        .overlay(Capsule().stroke(activePillBorder, lineWidth: 1))
                        .shadow(color: DS.Color.success.opacity(colorScheme == .dark ? 0.22 : 0.18), radius: 6, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
    }

    private var dockFillTop: Color {
        colorScheme == .dark ? Color(red: 0.11, green: 0.13, blue: 0.20).opacity(0.92) : Color.white.opacity(0.92)
    }

    private var dockFillBottom: Color {
        colorScheme == .dark ? Color(red: 0.05, green: 0.06, blue: 0.11).opacity(0.96) : Color(red: 0.97, green: 0.98, blue: 0.99).opacity(0.9)
    }

    private var inactiveLabel: Color {
        colorScheme == .dark ? Color(red: 0.39, green: 0.45, blue: 0.55) : DS.Color.muted
    }

    private var activeLabel: Color {
        colorScheme == .dark ? Color(red: 0.53, green: 0.94, blue: 0.67) : DS.Color.activeGreen
    }

    private var activePillFill: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.28), Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color(red: 0.86, green: 0.99, blue: 0.91).opacity(0.95), Color(red: 0.73, green: 0.97, blue: 0.82).opacity(0.88)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var activePillBorder: Color {
        Color(red: 0.29, green: 0.87, blue: 0.50).opacity(colorScheme == .dark ? 0.35 : 0.55)
    }
}

// Bottom dock shape (same as iOS)
struct BottomDockBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 420
        let sy = rect.height / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
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
