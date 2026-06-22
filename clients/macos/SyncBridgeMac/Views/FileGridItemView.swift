// FileGridItemView.swift — Preview card for temporary files grid.

import SwiftUI

struct FileGridItemView: View {

    @EnvironmentObject var appState: AppState
    let file: FileResponse

    @State private var image: NSImage?
    @State private var textPreview: String?

    var body: some View {
        VStack(spacing: DS.Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    .aspectRatio(1, contentMode: .fit)

                previewContent
            }

            Text(file.name)
                .font(DS.Font.label())
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            TransferBadgeView(transferMode: file.transferMode)

            Button("Pin") {
                Task { await appState.pinFile(file, pinned: true) }
            }
            .font(DS.Font.label())
            .buttonStyle(.plain)
            .foregroundStyle(DS.Color.primary)
        }
        .task { await loadPreview() }
    }

    @ViewBuilder
    private var previewContent: some View {
        if file.status != "ready" {
            ProgressView()
        } else if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(6)
        } else if let textPreview {
            ScrollView {
                Text(textPreview)
                    .font(.system(size: 7))
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.23))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        } else {
            VStack(spacing: DS.Space.xs) {
                Image(systemName: fileIcon(file.mimeType))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(fileExtension(file.name))
                    .font(DS.Font.label())
                    .fontWeight(.bold)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func loadPreview() async {
        guard file.status == "ready" else { return }
        let api = APIClient.shared
        if file.mimeType.hasPrefix("image/") {
            if let data = await api.downloadThumbnailData(fileId: file.id),
               let img = NSImage(data: data) {
                image = img
                return
            }
            if file.totalSize <= 2 * 1024 * 1024,
               let data = await api.downloadFileData(fileId: file.id, maxBytes: 2 * 1024 * 1024),
               let img = NSImage(data: data) {
                image = img
            }
        } else if isTextMime(file.mimeType) || ["md", "txt", "csv", "json"].contains(fileExtension(file.name).lowercased()) {
            if file.totalSize <= 512 * 1024,
               let data = await api.downloadFileData(fileId: file.id, maxBytes: 4096) {
                textPreview = String(data: data, encoding: .utf8).map { String($0.prefix(1200)) }
            }
        }
    }

    private func isTextMime(_ mime: String) -> Bool {
        mime.hasPrefix("text/") || mime == "application/json"
    }

    private func fileExtension(_ name: String) -> String {
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? "" : ext.uppercased()
    }

    private func fileIcon(_ mimeType: String) -> String {
        switch mimeType {
        case let t where t.hasPrefix("image/"): return "photo"
        case let t where t.hasPrefix("video/"): return "film"
        case "application/pdf": return "doc.richtext"
        case let t where t.contains("zip"): return "archivebox"
        default: return "doc"
        }
    }
}
