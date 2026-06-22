// LatestClipboardView.swift — DesignSystem modal

import SwiftUI

struct LatestClipboardView: View {
    let content: String
    let createdAt: String
    let onDismiss: () -> Void

    @State private var copied = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            AppCard {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    HStack {
                        Text("Latest Clipboard").font(DS.Font.title())
                        Spacer()
                        Button("✕") { onDismiss() }
                            .foregroundStyle(.secondary)
                    }

                    Text(relativeTime(createdAt))
                        .font(DS.Font.caption())
                        .foregroundStyle(.secondary)

                    Button {
                        UIPasteboard.general.string = content
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDismiss() }
                    } label: {
                        Text(displayContent)
                            .font(DS.Font.body())
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Space.md)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plain)

                    if copied {
                        Label("Copied", systemImage: "checkmark")
                            .font(DS.Font.caption())
                            .foregroundStyle(DS.Color.success)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: 340)
        }
    }

    private var displayContent: String {
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > 500 { return String(t.prefix(500)) + "…" }
        return t.isEmpty ? "(empty)" : t
    }

    private func relativeTime(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return "just now"
        }
        let s = Int(-date.timeIntervalSinceNow)
        if s < 5 { return "just now" }
        if s < 60 { return "\(s) seconds ago" }
        return "\(s / 60) minutes ago"
    }
}

#if os(iOS)
import UIKit
#endif
