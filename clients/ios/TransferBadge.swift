// TransferBadge.swift — Matches Android TransferBadge.kt

import SwiftUI

enum TransferRoute {
    case cloud
    case directLan
    case webRtc

    var emoji: String {
        switch self {
        case .cloud: return "☁"
        case .directLan: return "⚡"
        case .webRtc: return "🌐"
        }
    }

    var label: String {
        switch self {
        case .cloud: return "Cloud Relay"
        case .directLan: return "Direct LAN"
        case .webRtc: return "WebRTC"
        }
    }

    static func from(_ mode: String?) -> TransferRoute {
        switch mode {
        case "webrtc": return .webRtc
        case "direct_lan": return .directLan
        default: return .cloud
        }
    }
}

struct TransferBadge: View {
    let transferMode: String?

    private var route: TransferRoute { TransferRoute.from(transferMode) }

    private var colors: (bg: Color, fg: Color, border: Color) {
        switch route {
        case .cloud:
            return (Color(red: 0.23, green: 0.51, blue: 0.96, opacity: 0.12),
                    Color(red: 0.15, green: 0.39, blue: 0.92),
                    Color(red: 0.23, green: 0.51, blue: 0.96, opacity: 0.2))
        case .directLan:
            return (Color(red: 0.13, green: 0.77, blue: 0.37, opacity: 0.12),
                    Color(red: 0.08, green: 0.50, blue: 0.24),
                    Color(red: 0.13, green: 0.77, blue: 0.37, opacity: 0.25))
        case .webRtc:
            return (Color(red: 0.55, green: 0.36, blue: 0.96, opacity: 0.12),
                    Color(red: 0.49, green: 0.23, blue: 0.93),
                    Color(red: 0.55, green: 0.36, blue: 0.96, opacity: 0.2))
        }
    }

    var body: some View {
        let c = colors
        HStack(spacing: 4) {
            Text(route.emoji).font(.system(size: 11))
            Text(route.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(c.fg)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(c.bg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(c.border, lineWidth: 1))
    }
}
