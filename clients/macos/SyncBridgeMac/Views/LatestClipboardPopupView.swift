// LatestClipboardPopupView.swift — Premium modal

import AppKit
import SwiftUI

struct LatestClipboardPopupView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntryResponse
    let onDismiss: () -> Void

    @State private var copied = false

    private var isImage: Bool { entry.contentType.hasPrefix("image/") }

    var body: some View {
        ZStack {
            DS.Color.bgAdaptive(colorScheme)
                .opacity(0.97)

            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack {
                    Text("Latest Clipboard").font(DS.Font.title())
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Text(relativeTime(entry.createdAt))
                    .font(DS.Font.label())
                    .foregroundStyle(DS.Color.primaryAdaptive(colorScheme))

                Button { copyContent() } label: {
                    if isImage {
                        ClipboardImageThumb(entry: entry, maxHeight: 160)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(displayContent)
                            .font(DS.Font.body())
                            .foregroundStyle(DS.Color.textAdaptive(colorScheme))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Space.md)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .fill(DS.Color.bgAdaptive(colorScheme))
                            )
                    }
                }
                .buttonStyle(.plain)

                if copied {
                    Label(isImage ? "Copied image" : "Copied", systemImage: "checkmark.circle.fill")
                        .font(DS.Font.caption())
                        .foregroundStyle(DS.Color.success)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(DS.Space.lg)
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(solidCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Color.borderAdaptive(colorScheme).opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.12), radius: 12, y: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var solidCardFill: Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.14, blue: 0.20)
            : .white
    }

    private var displayContent: String {
        ClipboardDisplay.previewText(for: entry, maxLength: 500)
    }

    private func copyContent() {
        appState.copyToClipboard(entry)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDismiss() }
    }

    private func relativeTime(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return "just now" }
        let s = Int(-date.timeIntervalSinceNow)
        if s < 5 { return "just now" }
        if s < 60 { return "\(s) seconds ago" }
        return "\(s / 60) minutes ago"
    }
}
