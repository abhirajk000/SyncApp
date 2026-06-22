// TransferBadgeView.swift — Transfer route badge (Phase 2)

import SwiftUI

enum TransferRoute {
    case cloud, directLan, webrtc

    static func from(_ mode: String) -> TransferRoute {
        switch mode {
        case "webrtc": return .webrtc
        case "direct_lan": return .directLan
        default: return .cloud
        }
    }

    var emoji: String {
        switch self {
        case .cloud: return "☁"
        case .directLan: return "⚡"
        case .webrtc: return "🌐"
        }
    }

    var label: String {
        switch self {
        case .cloud: return "Cloud Relay"
        case .directLan: return "Direct LAN"
        case .webrtc: return "WebRTC"
        }
    }
}

struct TransferBadgeView: View {
    let transferMode: String

    private var route: TransferRoute { TransferRoute.from(transferMode) }

    var body: some View {
        HStack(spacing: 4) {
            Text(route.emoji).font(.system(size: 11))
            Text(route.label)
                .font(DS.Font.label())
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badgeBackground)
        .overlay(Capsule().stroke(badgeBorder, lineWidth: 1))
        .clipShape(Capsule())
    }

    private var badgeBackground: Color {
        switch route {
        case .cloud: return Color(red: 0.23, green: 0.51, blue: 0.96, opacity: 0.12)
        case .directLan: return Color(red: 0.13, green: 0.77, blue: 0.37, opacity: 0.12)
        case .webrtc: return Color(red: 0.55, green: 0.36, blue: 0.96, opacity: 0.12)
        }
    }

    private var badgeBorder: Color {
        switch route {
        case .cloud: return Color(red: 0.23, green: 0.51, blue: 0.96, opacity: 0.25)
        case .directLan: return Color(red: 0.13, green: 0.77, blue: 0.37, opacity: 0.3)
        case .webrtc: return Color(red: 0.55, green: 0.36, blue: 0.96, opacity: 0.25)
        }
    }
}
