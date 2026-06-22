// HomeView.swift — Recent clipboard and files (matches web HomePage).

import SwiftUI

struct HomeView: View {

    @EnvironmentObject var appState: AppState
    var onSeeAllFiles: () -> Void

    private var recentClipboard: [ClipboardEntryResponse] {
        appState.clipboardHistory.filter { !$0.pinned }.prefix(6).map { $0 }
    }

    private var recentFiles: [FileResponse] {
        appState.files.filter { !$0.isPinned && $0.status == "ready" }.prefix(5).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                sectionTitle("Recent clipboard")
                if recentClipboard.isEmpty {
                    AppCard {
                        Text("No clipboard items yet.")
                            .font(DS.Font.body())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: DS.Space.sm) {
                        ForEach(recentClipboard) { entry in
                            ClipboardEntryRow(entry: entry)
                        }
                    }
                }

                HStack {
                    sectionTitle("Recent files")
                    Spacer()
                    Button("See all", action: onSeeAllFiles)
                        .font(DS.Font.label())
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.Color.primary)
                }

                if recentFiles.isEmpty {
                    AppCard {
                        Text("No files yet.")
                            .font(DS.Font.body())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: DS.Space.sm) {
                        ForEach(recentFiles) { file in
                            FileRowView(file: file)
                        }
                    }
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
}
