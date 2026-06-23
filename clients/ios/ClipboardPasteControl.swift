// ClipboardPasteControl.swift — UIPasteControl sync button (no system paste permission prompt).

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ClipboardSyncPasteButton: UIViewRepresentable {
    @EnvironmentObject private var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeUIView(context: Context) -> UIPasteControl {
        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconAndLabel
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor(red: 0.05, green: 0.58, blue: 0.53, alpha: 1)
        configuration.baseForegroundColor = .white

        let control = UIPasteControl(configuration: configuration)
        control.target = context.coordinator.target
        return control
    }

    func updateUIView(_ uiView: UIPasteControl, context: Context) {
        context.coordinator.appState = appState
        context.coordinator.target.onProviders = { [weak appState] providers in
            guard let appState else { return }
            await appState.uploadFromPasteProviders(providers)
        }
    }

    final class Coordinator {
        var appState: AppState
        let target = PasteSyncTarget()

        init(appState: AppState) {
            self.appState = appState
            target.onProviders = { [weak appState] providers in
                guard let appState else { return }
                await appState.uploadFromPasteProviders(providers)
            }
        }
    }
}

final class PasteSyncTarget: UIView {
    var onProviders: (([NSItemProvider]) async -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [
            UTType.plainText.identifier,
            UTType.utf8PlainText.identifier,
            UTType.text.identifier,
            UTType.url.identifier,
            UTType.image.identifier,
            UTType.png.identifier,
            UTType.jpeg.identifier,
            UTType.heic.identifier,
            "public.plain-text",
            "public.utf8-plain-text",
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
        itemProviders.contains { provider in
            provider.canLoadObject(ofClass: UIImage.self)
                || provider.canLoadObject(ofClass: String.self)
        }
    }

    override func paste(itemProviders: [NSItemProvider]) {
        guard let onProviders else { return }
        Task { await onProviders(itemProviders) }
    }
}

/// Shown on home when iOS blocked a silent clipboard read (e.g. copied from Messages).
struct ClipboardPasteBanner: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        AppCard(accentBorder: SyncTokens.teal.opacity(0.25)) {
            VStack(alignment: .leading, spacing: SyncTokens.space3) {
                HStack(spacing: SyncTokens.space2) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(SyncTokens.teal)
                    Text("New copy detected")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text("iOS needs permission to read clipboard from Messages and other apps. Tap Paste to sync now.")
                    .font(.system(size: 13))
                    .foregroundStyle(SyncTokens.slateSecondary)
                ClipboardSyncPasteButton()
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("Allow automatic sync…") {
                    Task { await appState.requestPasteAccess() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SyncTokens.teal)
            }
        }
    }
}
