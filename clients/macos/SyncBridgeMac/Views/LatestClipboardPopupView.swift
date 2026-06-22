// LatestClipboardPopupView.swift — Premium modal

import SwiftUI

struct LatestClipboardPopupView: View {

    let entry: ClipboardEntryResponse
    let onDismiss: () -> Void

    @State private var copied = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            AppCard(hero: true) {
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
                        .foregroundStyle(DS.Color.primary)

                    Button { copyContent() } label: {
                        Text(displayContent)
                            .font(DS.Font.body())
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Space.md)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)

                    if copied {
                        Label("Copied", systemImage: "checkmark.circle.fill")
                            .font(DS.Font.caption())
                            .foregroundStyle(DS.Color.success)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(width: 320)
        }
    }

    private var displayContent: String {
        let text = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 500 { return String(text.prefix(500)) + "…" }
        return text.isEmpty ? "(empty)" : text
    }

    private func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.content, forType: .string)
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
