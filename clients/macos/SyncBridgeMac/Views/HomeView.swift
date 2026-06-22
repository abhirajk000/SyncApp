// HomeView.swift — Latest text, image, and file (product dashboard priority).

import SwiftUI

struct HomeView: View {

    @EnvironmentObject var appState: AppState
    var onSeeAllFiles: () -> Void

    private var latestText: ClipboardEntryResponse? {
        appState.clipboardHistory.first { !$0.pinned && !$0.contentType.hasPrefix("image/") }
    }

    private var latestImage: ClipboardEntryResponse? {
        appState.clipboardHistory.first { !$0.pinned && $0.contentType.hasPrefix("image/") }
    }

    private var latestFile: FileResponse? {
        appState.files.first { !$0.isPinned && $0.status == "ready" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                sectionTitle("Latest text")
                if let entry = latestText {
                    ClipboardEntryRow(entry: entry)
                } else {
                    emptyCard("No text yet.")
                }

                sectionTitle("Latest image")
                if let entry = latestImage {
                    ClipboardEntryRow(entry: entry)
                } else {
                    emptyCard("No images yet.")
                }

                HStack {
                    sectionTitle("Latest file")
                    Spacer()
                    Button("See all", action: onSeeAllFiles)
                        .font(DS.Font.label())
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.Color.primary)
                }

                if let file = latestFile {
                    FileRowView(file: file)
                } else {
                    emptyCard("No files yet.")
                }
            }
            .padding(DS.Space.md)
        }
        .task { await appState.refreshClipboardHistory(); await appState.refreshFiles() }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(DS.Font.label())
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    private func emptyCard(_ message: String) -> some View {
        AppCard {
            Text(message)
                .font(DS.Font.body())
                .foregroundStyle(.secondary)
        }
    }
}
