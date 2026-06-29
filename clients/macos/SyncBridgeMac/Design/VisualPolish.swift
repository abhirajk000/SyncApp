// VisualPolish.swift — Phase 4 (macOS)

import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: DS.Duration.fast), value: configuration.isPressed)
    }
}

enum EmptyArt { case clipboard, files, send, devices, pinned, inbox }

struct EmptyIllustration: View {
    var variant: EmptyArt = .inbox

    private var symbol: String {
        switch variant {
        case .clipboard: return "doc.on.clipboard"
        case .files: return "folder"
        case .send: return "paperplane.fill"
        case .devices: return "laptopcomputer.and.iphone"
        case .pinned: return "pin.fill"
        case .inbox: return "tray"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(DS.Color.primary)
            .frame(width: 88, height: 88)
            .glassCard(cornerRadius: DS.Radius.card, hero: true)
            .shadow(color: DS.Color.primary.opacity(0.18), radius: 14, y: 6)
    }
}

struct ImagePlaceholder: View {
    var height: CGFloat = 120

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md)
            .fill(
                LinearGradient(
                    colors: [DS.Color.muted.opacity(0.14), DS.Color.cardAdaptive(.light), DS.Color.muted.opacity(0.14)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .glassCard(cornerRadius: DS.Radius.md)
    }
}
