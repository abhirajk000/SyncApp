// FileAPI.swift — File list + chunked upload (matches Android/macOS backend).

import CryptoKit
import Foundation

struct FileItem: Identifiable, Decodable {
    let id: String
    let name: String
    let mimeType: String
    let totalSize: Int64
    let status: String
    let isPinned: Bool
    let createdAt: String
    let transferMode: String

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case mimeType = "mime_type"
        case totalSize = "total_size"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
        case transferMode = "transfer_mode"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType) ?? "application/octet-stream"
        totalSize = try c.decodeIfPresent(Int64.self, forKey: .totalSize) ?? 0
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        transferMode = try c.decodeIfPresent(String.self, forKey: .transferMode) ?? "relay"
    }
}

enum FileAPI {
    private static let chunkSize = 4 * 1024 * 1024

    static func listFiles(serverURL: String, accessToken: String) async throws -> [FileItem] {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/files?limit=100") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let files = json["files"] as? [[String: Any]] ?? []
        let decoder = JSONDecoder()
        return try files.compactMap { dict in
            let itemData = try JSONSerialization.data(withJSONObject: dict)
            return try? decoder.decode(FileItem.self, from: itemData)
        }
    }

    static func downloadData(serverURL: String, accessToken: String, fileId: String) async throws -> Data {
        try await authorizedData(
            serverURL: serverURL,
            accessToken: accessToken,
            path: "/api/v1/files/\(fileId)/download",
            method: "GET"
        )
    }

    static func pinFile(serverURL: String, accessToken: String, fileId: String, pinned: Bool) async throws {
        _ = try await authorizedData(
            serverURL: serverURL,
            accessToken: accessToken,
            path: "/api/v1/files/\(fileId)/pin",
            method: "POST",
            jsonBody: ["pinned": pinned]
        )
    }

    static func uploadData(serverURL: String, accessToken: String, name: String, mimeType: String, data: Data) async throws {
        let fileHash = sha256Hex(data)
        let chunkCount = max(1, (data.count + chunkSize - 1) / chunkSize)

        let initData = try await authorizedData(
            serverURL: serverURL,
            accessToken: accessToken,
            path: "/api/v1/files/init",
            method: "POST",
            jsonBody: [
                "name": name,
                "mime_type": mimeType,
                "total_size": data.count,
                "chunk_size": chunkSize,
                "file_hash": fileHash,
                "transfer_mode": "relay",
                "force_relay": false,
            ]
        )
        let initJson = try JSONSerialization.jsonObject(with: initData) as? [String: Any] ?? [:]
        guard let fileId = initJson["file_id"] as? String else {
            throw URLError(.badServerResponse)
        }

        for index in 0..<chunkCount {
            let start = index * chunkSize
            let end = min(start + chunkSize, data.count)
            let chunk = data.subdata(in: start..<end)
            try await uploadChunk(
                serverURL: serverURL,
                accessToken: accessToken,
                fileId: fileId,
                index: index,
                chunk: chunk
            )
        }

        _ = try await authorizedData(
            serverURL: serverURL,
            accessToken: accessToken,
            path: "/api/v1/files/\(fileId)/complete",
            method: "POST",
            jsonBody: [:] as [String: Any]
        )
    }

    private static func uploadChunk(
        serverURL: String,
        accessToken: String,
        fileId: String,
        index: Int,
        chunk: Data
    ) async throws {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/files/\(fileId)/chunks/\(index)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(sha256Hex(chunk), forHTTPHeaderField: "X-Chunk-Hash")
        request.httpBody = chunk
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func deleteFile(serverURL: String, accessToken: String, fileId: String) async throws {
        _ = try await authorizedData(
            serverURL: serverURL,
            accessToken: accessToken,
            path: "/api/v1/files/\(fileId)",
            method: "DELETE"
        )
    }

    private static func authorizedData(
        serverURL: String,
        accessToken: String,
        path: String,
        method: String,
        jsonBody: [String: Any]? = nil
    ) async throws -> Data {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)\(path)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
                throw NSError(domain: "SyncBridge", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [
                    NSLocalizedDescriptionKey: err.error,
                ])
            }
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct APIErrorBody: Decodable {
    let error: String
}
