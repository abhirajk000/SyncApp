// DockBottomBar.swift — SyncBridge 5-tab premium dock

import SwiftUI

enum MainTab: String, CaseIterable {
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

struct DockBottomBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let current: MainTab
    let onNavigate: (MainTab) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottom) {
                BottomDockBarShape()
                    .fill(
                        LinearGradient(
                            colors: [AppSurfaces.dockFillTop(colorScheme), AppSurfaces.dockFillBottom(colorScheme)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        BottomDockBarShape()
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.85), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.42), radius: 20, y: 10)

                HStack(spacing: 0) {
                    HStack {
                        dockItem(.cloudSend)
                        dockItem(.localSend)
                    }
                    .frame(maxWidth: .infinity)
                    Color.clear.frame(width: 76)
                    HStack {
                        dockItem(.files)
                        dockItem(.settings)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .frame(height: SyncTokens.dockHeight)
            .padding(.horizontal, SyncTokens.space4)

            clipboardFab
        }
        .padding(.bottom, SyncTokens.space3)
    }

    private var clipboardFab: some View {
        let selected = current == .clipboard
        return Button { onNavigate(.clipboard) } label: {
            ZStack {
                Circle()
                    .fill(SyncTokens.teal)
                    .frame(width: 64, height: 64)
                    .shadow(color: SyncTokens.teal.opacity(selected ? 0.55 : 0.4), radius: selected ? 16 : 12, y: 6)
                    .overlay {
                        if selected {
                            Circle()
                                .stroke(SyncTokens.teal.opacity(0.35), lineWidth: 3)
                                .frame(width: 72, height: 72)
                        }
                    }
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(selected ? 1.06 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: selected)
        }
        .buttonStyle(.plain)
        .offset(y: -10)
    }

    private func dockItem(_ tab: MainTab) -> some View {
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
            .foregroundStyle(selected ? activeLabel : SyncTokens.dockInactive)
            .frame(width: 72, height: 52)
            .background {
                if selected {
                    Capsule()
                        .fill(activePillFill)
                        .overlay(Capsule().stroke(activePillBorder, lineWidth: 1))
                        .shadow(color: SyncTokens.teal.opacity(colorScheme == .dark ? 0.22 : 0.18), radius: 6, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var activeLabel: Color {
        colorScheme == .dark ? Color(red: 0.53, green: 0.94, blue: 0.67) : SyncTokens.dockActiveGreen
    }

    private var activePillFill: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.28),
                    Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.99, blue: 0.91).opacity(0.95),
                Color(red: 0.73, green: 0.97, blue: 0.82).opacity(0.88),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var activePillBorder: Color {
        Color(red: 0.29, green: 0.87, blue: 0.50).opacity(colorScheme == .dark ? 0.35 : 0.55)
    }
}
