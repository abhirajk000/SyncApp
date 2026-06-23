// LatestClipboardView.swift — Popup on app open (matches Android/macOS)

import SwiftUI

struct LatestClipboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry
    let onDismiss: () -> Void

    @State private var copied = false

    private var isImage: Bool { isImageContentType(entry.contentType) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            AppCard(accentBorder: SyncTokens.teal.opacity(0.22)) {
                VStack(alignment: .leading, spacing: SyncTokens.space3) {
                    HStack {
                        Text("Latest Clipboard")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Spacer()
                        Button("✕", action: onDismiss)
                            .foregroundStyle(SyncTokens.slateMuted)
                    }
                    Text(relativeTime(entry.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(SyncTokens.slateSecondary)

                    Button {
                        appState.copyEntry(entry)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDismiss() }
                    } label: {
                        Group {
                            if isImage {
                                ClipboardImageThumb(
                                    entry: entry,
                                    serverURL: appState.serverURL,
                                    accessToken: appState.accessToken,
                                    maxHeight: 180
                                )
                            } else {
                                Text(clipboardDisplayText(entry.content, max: 500))
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(SyncTokens.space3)
                        .background(AppSurfaces.surfaceVariant(colorScheme).opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
                    }
                    .buttonStyle(.plain)

                    if copied {
                        Label(isImage ? "Copied image" : "Copied", systemImage: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SyncTokens.success)
                    }
                }
            }
            .frame(maxWidth: 340)
            .padding(SyncTokens.space4)
        }
    }
}
