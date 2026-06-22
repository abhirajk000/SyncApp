// APIClient.swift
// Typed async/await REST client for the SyncBridge backend.
//
// Design decisions:
//   • No third-party libraries — URLSession + JSONDecoder/Encoder only.
//   • 7-day device tokens — no refresh endpoint; re-unlock with PIN when expired.
//   • All calls are async; call sites use try await.

import Foundation

// ── APIClient ─────────────────────────────────────────────────────────────────

final class APIClient {

    private let keychain = KeychainService.shared
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // Shared singleton; use `init(session:)` in tests.
    static let shared = APIClient()

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // ── Base URL ──────────────────────────────────────────────────────────────

    var baseURL: String {
        get { keychain.serverURL }
        set { keychain.serverURL = newValue }
    }

    // ── Core request builder ──────────────────────────────────────────────────

    /// Performs an authenticated HTTP request. Throws on 401 (token expired or revoked).
    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (some Encodable)? = nil as EmptyBody?,
        contentType: String = "application/json"
    ) async throws -> T {
        let (data, response) = try await perform(
            path: path, method: method,
            body: body, contentType: contentType,
            token: keychain.accessToken
        )

        if (response as? HTTPURLResponse)?.statusCode == 401 {
            throw APIError(error: "session expired", requestId: nil)
        }
        return try decode(data)
    }

    /// Unauthenticated request (PIN unlock).
    func publicRequest<T: Decodable>(
        _ path: String,
        method: String = "POST",
        body: some Encodable
    ) async throws -> T {
        let (data, _) = try await perform(
            path: path, method: method,
            body: body, contentType: "application/json",
            token: nil
        )
        return try decode(data)
    }

    // ── Raw data upload (chunks) ──────────────────────────────────────────────

    func uploadChunk(
        fileId: String,
        chunkIndex: Int,
        data chunkData: Data,
        chunkHash: String
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/files/\(fileId)/chunks/\(chunkIndex)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.setValue(chunkHash, forHTTPHeaderField: "X-Chunk-Hash")
        if let token = keychain.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = chunkData

        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 {
            throw APIError(error: "session expired", requestId: nil)
        } else if !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    // ── Download streaming ────────────────────────────────────────────────────

    func downloadFile(fileId: String, to destination: URL) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/files/\(fileId)/download") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        if let token = keychain.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (tempURL, _) = try await session.download(for: req)
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private func perform(
        path: String,
        method: String,
        body: (some Encodable)?,
        contentType: String,
        token: String?
    ) async throws -> (Data, URLResponse) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            // Try to decode API error body.
            if let apiErr = try? decoder.decode(APIError.self, from: data) {
                throw apiErr
            }
        }
        return (data, response)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        return try decoder.decode(T.self, from: data)
    }
}

// Placeholder for when a request has no body.
private struct EmptyBody: Encodable {}
