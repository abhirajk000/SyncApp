// ClipboardHubView.swift — Clipboard history + Pinned segmented hub

import SwiftUI

private enum ClipboardSection: String, CaseIterable {
    case history = "Clipboard"
    case pinned = "Pinned"
}

struct ClipboardHubView: View {
    @State private var section: ClipboardSection = .history

    var body: some View {
        VStack(spacing: DS.Space.md) {
            Picker("Section", selection: $section) {
                ForEach(ClipboardSection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.md)

            switch section {
            case .history:
                ClipboardTimelineView(embedded: true)
            case .pinned:
                PinnedClipboardView(embedded: true)
            }
        }
    }
}
