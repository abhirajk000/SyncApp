// FileGridItemView.swift — File preview card with action menu.

import SwiftUI

struct FileGridItemView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    let file: FileItem
    var compact: Bool = false

    @State private var image: UIImage?
    @State private var textPreview: String?

    private var ready: Bool { file.status == "ready" }
    private var cornerRadius: CGFloat { compact ? SyncTokens.radiusLg : SyncTokens.radiusXl }

    var body: some View {
        VStack(spacing: compact ? SyncTokens.space1 : SyncTokens.space2) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppSurfaces.card(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 2, y: 1)

                previewContent

                ItemActionMenu(
                    showDownload: ready,
                    showCopy: canCopyFile(file),
                    showPin: true,
                    showDelete: true,
                    isPinned: file.isPinned,
                    onDownload: { Task { await appState.downloadFile(file) } },
                    onCopy: { Task { await appState.copyFileToClipboard(file) } },
                    onPin: { Task { await appState.pinFile(file, pinned: !file.isPinned) } },
                    onDelete: { Task { await appState.deleteFile(file) } }
                )
                .padding(SyncTokens.space2)
                .zIndex(10)
            }

            Text(file.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, SyncTokens.space1)

            if !compact {
                TransferBadge(transferMode: file.transferMode)
            }
        }
        .task { await loadPreview() }
    }

    @ViewBuilder
    private var previewContent: some View {
        if !ready {
            Text("Uploading…")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(6)
        } else if let textPreview {
            ScrollView {
                Text(textPreview)
                    .font(.system(size: 7))
                    .lineSpacing(2)
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.23))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: fileIcon(file.mimeType))
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
                let ext = fileExtension(file.name)
                if !ext.isEmpty {
                    Text(ext)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.58, green: 0.64, blue: 0.72))
                }
            }
        }
    }

    private func loadPreview() async {
        guard ready, let token = appState.accessToken else { return }
        do {
            if file.mimeType.hasPrefix("image/") {
                let data = try await FileAPI.downloadData(
                    serverURL: appState.serverURL,
                    accessToken: token,
                    fileId: file.id
                )
                if file.totalSize <= 2 * 1024 * 1024 {
                    image = UIImage(data: data)
                }
            } else if isTextMime(file.mimeType) || isTextExtension(file.name),
                      file.totalSize <= 512 * 1024 {
                let data = try await FileAPI.downloadData(
                    serverURL: appState.serverURL,
                    accessToken: token,
                    fileId: file.id
                )
                textPreview = String(data: data.prefix(1200), encoding: .utf8)
            }
        } catch {}
    }

    private func isTextExtension(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["txt", "md", "csv", "json", "log"].contains(ext)
    }

    private func fileExtension(_ name: String) -> String {
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? "" : ext.uppercased()
    }

    private func fileIcon(_ mimeType: String) -> String {
        switch mimeType {
        case let t where t.hasPrefix("video/"): return "film"
        case let t where t.contains("zip") || t.contains("tar"): return "archivebox"
        case let t where t.contains("pdf") || t.contains("word"): return "doc.richtext"
        case let t where t.hasPrefix("image/"): return "photo"
        default: return "doc"
        }
    }
}

#if os(iOS)
import UIKit
#endif
