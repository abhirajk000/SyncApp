// AuthService.swift
// PIN unlock, session status, and logout.

import Foundation

final class AuthService {

    private let api: APIClient
    private let keychain = KeychainService.shared

    init(api: APIClient = .shared) {
        self.api = api
    }

    // ── Unlock ────────────────────────────────────────────────────────────────

    /// Validates the master PIN on the server and registers this device if needed.
    func unlock(pin: String) async throws -> AuthResponse {
        let deviceId = keychain.ensureDeviceId()
        let hostname = Host.current().localizedName ?? "Mac"
        let req = UnlockRequest(
            pin: pin,
            deviceId: deviceId,
            deviceName: "\(hostname) (macOS)",
            platform: "macos"
        )
        let resp: AuthResponse = try await api.publicRequest("/api/v1/auth/unlock", body: req)
        storeTokens(from: resp)
        return resp
    }

    // ── Session status ────────────────────────────────────────────────────────

    /// Returns whether this device still has an active trust window (no PIN needed).
    func checkStatus() async throws -> AuthStatusResponse {
        try await api.request("/api/v1/auth/status")
    }

    // ── Pairing ───────────────────────────────────────────────────────────────

    func initiatePairing() async throws -> PairingInitResponse {
        try await api.request("/api/v1/devices/pair/initiate", method: "POST", body: EmptyBody())
    }

    // ── Logout ────────────────────────────────────────────────────────────────

    func logout() async {
        _ = try? await api.request("/api/v1/auth/logout", method: "POST", body: EmptyBody()) as EmptyResponse
        keychain.clearAll()
    }

    // ── Clipboard operations ──────────────────────────────────────────────────

    func syncClipboard(contentType: String, content: String) async throws -> ClipboardEntryResponse {
        guard let deviceId = keychain.deviceId else {
            throw APIError(error: "Device not registered", requestId: nil)
        }
        let req = ClipboardSyncRequest(
            contentType: contentType,
            content: content,
            sourceDeviceId: deviceId
        )
        return try await api.request("/api/v1/clipboard", method: "POST", body: req)
    }

    func getClipboardHistory(limit: Int = 50, offset: Int = 0) async throws -> ClipboardHistoryResponse {
        try await api.request("/api/v1/clipboard?limit=\(limit)&offset=\(offset)")
    }

    func getCurrentClipboard() async throws -> ClipboardEntryResponse {
        try await api.request("/api/v1/clipboard/current")
    }

    func getClipboardEntry(id: String) async throws -> ClipboardEntryResponse {
        try await api.request("/api/v1/clipboard/\(id)")
    }

    func deleteClipboardEntry(id: String) async throws {
        let _: EmptyResponse = try await api.request("/api/v1/clipboard/\(id)", method: "DELETE")
    }

    // ── Device list ───────────────────────────────────────────────────────────

    func listDevices() async throws -> DeviceListResponse {
        try await api.request("/api/v1/devices/")
    }

    func revokeDevice(id: String) async throws {
        let _: EmptyResponse = try await api.request("/api/v1/devices/\(id)", method: "DELETE")
    }

    // ── File operations ───────────────────────────────────────────────────────

    func initFileUpload(_ req: FileInitRequest) async throws -> FileInitResponse {
        try await api.request("/api/v1/files/init", method: "POST", body: req)
    }

    func completeFileUpload(fileId: String) async throws -> FileResponse {
        try await api.request("/api/v1/files/\(fileId)/complete", method: "POST", body: EmptyBody())
    }

    func getFileUploadStatus(fileId: String) async throws -> FileStatusResponse {
        try await api.request("/api/v1/files/\(fileId)/status")
    }

    func listFiles() async throws -> FileListResponse {
        try await api.request("/api/v1/files")
    }

    func deleteFile(id: String) async throws {
        let _: EmptyResponse = try await api.request("/api/v1/files/\(id)", method: "DELETE")
    }

    func pinClipboardEntry(id: String, pinned: Bool) async throws {
        let _: EmptyResponse = try await api.request("/api/v1/clipboard/\(id)/pin", method: "POST", body: PinRequest(pinned: pinned))
    }

    func pinFile(id: String, pinned: Bool) async throws {
        let _: EmptyResponse = try await api.request("/api/v1/files/\(id)/pin", method: "POST", body: PinRequest(pinned: pinned))
    }

    func markFileDelivered(id: String) async throws {
        let _: EmptyResponse = try await api.request("/api/v1/files/\(id)/delivered", method: "POST", body: EmptyBody())
    }

    // ── Network / diagnostics ─────────────────────────────────────────────────

    func fetchDiagnostics() async throws -> DiagnosticsResponse {
        try await api.request("/api/v1/diagnostics")
    }

    func fetchLocalPeers(addrs: String = "") async throws -> LocalPeersResponse {
        let q = addrs.isEmpty ? "" : "?addrs=\(addrs.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? addrs)"
        return try await api.request("/api/v1/local/peers\(q)")
    }

    func advertiseLocalAddrs(_ addrs: [String], port: Int = 0) async throws {
        let _: EmptyResponse = try await api.request(
            "/api/v1/local/advertise",
            method: "POST",
            body: AdvertiseRequest(addrs: addrs, port: port)
        )
    }

    // ── Private ───────────────────────────────────────────────────────────────

    private func storeTokens(from resp: AuthResponse) {
        keychain.accessToken = resp.accessToken
        keychain.refreshToken = resp.refreshToken
        keychain.userId = resp.userId
        keychain.deviceId = resp.deviceId
        keychain.trustedUntil = resp.trustedUntil
    }
}

private struct EmptyBody: Encodable {}
