// ClipboardHubView.swift — Clipboard history + Pinned segmented hub

import SwiftUI

private enum ClipboardSection: String, CaseIterable {
    case history = "Clipboard"
    case pinned = "Pinned"
}

struct ClipboardHubView: View {
    @State private var section: ClipboardSection = .history

    var body: some View {
        VStack(spacing: SyncTokens.space4) {
            Picker("Section", selection: $section) {
                ForEach(ClipboardSection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)

            switch section {
            case .history:
                ClipboardTimelineView(embedded: true)
            case .pinned:
                PinnedView(embedded: true)
            }
        }
    }
}
