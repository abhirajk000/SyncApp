// DockBottomBar.swift — Matches Android dock navigation

import SwiftUI

enum MainTab: String, CaseIterable {
    case clipboard = "Clipboard"
    case pinned = "Pinned"
    case send = "Send"
    case files = "Files"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .pinned: return "pin"
        case .send: return "paperplane"
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
            HStack(spacing: 0) {
                HStack {
                    dockItem(.clipboard)
                    dockItem(.pinned)
                }
                .frame(maxWidth: .infinity)
                Spacer().frame(width: 56)
                HStack {
                    dockItem(.files)
                    dockItem(.settings)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: SyncTokens.dockHeight)
            .padding(.horizontal, 12)
            .background(AppSurfaces.dock(colorScheme))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .padding(.horizontal, SyncTokens.space4)

            Button { onNavigate(.send) } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.39, green: 0.40, blue: 0.95), SyncTokens.violet],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(y: -4)
        }
        .padding(.bottom, SyncTokens.space3)
    }

    private func dockItem(_ tab: MainTab) -> some View {
        let selected = current == tab
        return Button { onNavigate(tab) } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 9, weight: selected ? .bold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? SyncTokens.dockActiveGreen : SyncTokens.dockInactive)
            .frame(width: 72, height: 52)
            .background(selected ? SyncTokens.dockActiveBg : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(selected ? SyncTokens.dockActiveBorder : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
