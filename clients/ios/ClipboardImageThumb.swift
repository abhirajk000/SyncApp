// ClipboardImageThumb.swift — Image preview for clipboard entries

import SwiftUI

#if os(iOS)
import UIKit
#endif

struct ClipboardImageThumb: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntry
    let serverURL: String
    let accessToken: String?
    var maxHeight: CGFloat = 200

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxHeight)
            } else {
                RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                    .fill(AppSurfaces.surfaceVariant(colorScheme).opacity(0.4))
                    .frame(height: maxHeight)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
        .task(id: entry.id) { await loadImage() }
        .onDisappear { image = nil }
    }

    private func loadImage() async {
        // Prefer embedded data only when already small (inline preview).
        if let data = ClipboardImageCodec.decodeImageData(from: entry),
           data.count <= 256 * 1024,
           let img = ImageThumbDecode.decode(data) {
            image = img
            return
        }
        guard let token = accessToken else { return }
        if let data = try? await ClipboardAPI.downloadThumbnail(
            serverURL: serverURL,
            accessToken: token,
            entryId: entry.id
        ), let img = ImageThumbDecode.decode(data) {
            image = img
        }
    }
}

enum ClipboardAPI {
    static func fetchHistory(serverURL: String, accessToken: String, limit: Int = 100) async throws -> [ClipboardEntry] {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/clipboard?limit=\(limit)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let entries = json["entries"] as? [[String: Any]] ?? []
        return entries.compactMap { parseEntry($0) }
    }

    static func fetchEntry(serverURL: String, accessToken: String, id: String) async throws -> ClipboardEntry {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/clipboard/\(id)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let entry = parseEntry(json) else { throw URLError(.cannotParseResponse) }
        return entry
    }

    static func syncClipboard(
        serverURL: String,
        accessToken: String,
        content: String,
        contentType: String
    ) async throws -> ClipboardEntry {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/clipboard") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "content_type": contentType,
            "content": content,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return parseEntry(json) ?? ClipboardEntry(
            id: UUID().uuidString,
            content: content,
            contentType: contentType,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            pinned: false
        )
    }

    static func syncText(serverURL: String, accessToken: String, content: String) async throws -> ClipboardEntry {
        try await syncClipboard(
            serverURL: serverURL,
            accessToken: accessToken,
            content: content,
            contentType: "text/plain"
        )
    }

    static func pinEntry(serverURL: String, accessToken: String, id: String, pinned: Bool) async throws {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/clipboard/\(id)/pin") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["pinned": pinned])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func deleteEntry(serverURL: String, accessToken: String, id: String) async throws {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/clipboard/\(id)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func downloadThumbnail(serverURL: String, accessToken: String, entryId: String) async throws -> Data {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/clipboard/\(entryId)/thumbnail") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    static func parseEntry(_ json: [String: Any]) -> ClipboardEntry? {
        guard let id = json["id"] as? String else { return nil }
        let contentType = json["content_type"] as? String ?? "text/plain"
        return ClipboardEntry(
            id: id,
            content: json["content"] as? String ?? "",
            contentType: contentType,
            createdAt: json["created_at"] as? String ?? "",
            pinned: json["pinned"] as? Bool ?? false,
            hasThumbnail: json["has_thumbnail"] as? Bool ?? contentType.hasPrefix("image/"),
            sourceDeviceId: json["source_device_id"] as? String ?? ""
        )
    }
}
