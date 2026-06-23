// PinnedClipboardView.swift — Pinned clipboard entries only.

import SwiftUI

struct PinnedClipboardView: View {

    @EnvironmentObject var appState: AppState

    private var pinned: [ClipboardEntryResponse] {
        appState.clipboardHistory.filter { $0.pinned }
    }

    var body: some View {
        Group {
            if pinned.isEmpty {
                AppEmptyState(
                    icon: "pin.fill",
                    title: "No pinned items",
                    description: "Pin clipboard entries to keep them synced across devices."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(pinned) { entry in
                            ClipboardEntryRow(entry: entry)
                            Divider().opacity(0.35)
                        }
                    }
                    .padding(.horizontal, DS.Space.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await appState.refreshClipboardHistory() }
    }
}
