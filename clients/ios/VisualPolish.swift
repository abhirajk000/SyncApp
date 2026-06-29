// VisualPolish.swift — Phase 4 depth, motion, atmosphere (iOS)

import SwiftUI

// MARK: - Button press style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: SyncTokens.durationFast), value: configuration.isPressed)
    }
}

// MARK: - Card modifiers

struct FloatingCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var hero: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if hero {
                    RoundedRectangle(cornerRadius: SyncTokens.radiusContainerLg)
                        .fill(
                            LinearGradient(
                                colors: [SyncTokens.teal.opacity(0.14), SyncTokens.indigo.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: SyncTokens.radiusContainerLg)
                        .fill(AppSurfaces.card(colorScheme))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: SyncTokens.radiusContainerLg)
                    .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
            )
            .shadow(
                color: hero ? SyncTokens.teal.opacity(0.16) : .black.opacity(colorScheme == .dark ? 0.32 : 0.08),
                radius: hero ? 16 : 10,
                y: hero ? 8 : 4
            )
    }
}

extension View {
    func floatingCard(hero: Bool = false) -> some View {
        modifier(FloatingCardModifier(hero: hero))
    }
}

// MARK: - Empty illustration

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
            .foregroundStyle(SyncTokens.teal)
            .frame(width: 88, height: 88)
            .background(
                LinearGradient(
                    colors: [SyncTokens.teal.opacity(0.14), SyncTokens.indigo.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusCard))
            .shadow(color: SyncTokens.teal.opacity(0.18), radius: 14, y: 6)
    }
}

// MARK: - Image placeholder

struct ImagePlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme
    var height: CGFloat = 120

    var body: some View {
        RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
            .fill(
                LinearGradient(
                    colors: [
                        SyncTokens.slateMuted.opacity(0.14),
                        AppSurfaces.card(colorScheme),
                        SyncTokens.slateMuted.opacity(0.14),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                    .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
            )
    }
}
