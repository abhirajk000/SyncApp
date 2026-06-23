// ClipboardImageThumb.swift — Inline image preview for clipboard entries.

import AppKit
import SwiftUI

struct ClipboardImageThumb: View {

    @EnvironmentObject private var appState: AppState
    let entry: ClipboardEntryResponse
    var maxHeight: CGFloat = 120

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: min(maxHeight, 72))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(id: entry.id) { await loadImage() }
    }

    private func loadImage() async {
        guard entry.contentType.hasPrefix("image/") else { return }

        let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           let data = Data(base64Encoded: trimmed),
           let img = NSImage(data: data) {
            image = img
            return
        }

        if let data = await appState.api.downloadClipboardThumbnail(entryId: entry.id),
           let img = NSImage(data: data) {
            image = img
            return
        }

        if let full = try? await appState.authService.getClipboardEntry(id: entry.id),
           !full.content.isEmpty,
           let data = Data(base64Encoded: full.content.trimmingCharacters(in: .whitespacesAndNewlines)),
           let img = NSImage(data: data) {
            image = img
        }
    }
}
