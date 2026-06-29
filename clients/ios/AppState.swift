// AppState.swift
// Auth state and PIN unlock — mirrors macOS AppState / AuthService.

import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
final class AppState: ObservableObject {
    static let defaultServerURL = "https://sync.abhiraj.xyz"

    @Published var isAuthenticated = false
    @Published var isConnecting = false
    @Published var errorMessage: String?
    @Published var latestClipboardPopup: ClipboardEntry?
    @Published var files: [FileItem] = []
    @Published var clipboardHistory: [ClipboardEntry] = []
    @Published var uploads: [UploadProgressItem] = []

    private let clipboardMonitor = ClipboardMonitor()
    /// At most one latest-clipboard popup per foreground session (not on every WS event).
    private var latestPopupShownThisSession = false
    @Published var isRefreshing = false
    /// Clipboard changed while SyncBridge was inactive — iOS needs Paste tap or Allow permission.
    @Published var clipboardPastePending = false

    var serverURL: String { Self.defaultServerURL }

    var accessToken: String? {
        UserDefaults.standard.string(forKey: Keys.accessToken)
    }

    private var accessTokenStorage: String? {
        get { UserDefaults.standard.string(forKey: Keys.accessToken) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.accessToken) }
    }

    init() {
        isAuthenticated = accessToken != nil
        clipboardMonitor.serverURL = serverURL
        clipboardMonitor.accessToken = accessToken
        clipboardMonitor.onLocalSync = { [weak self] entry in
            self?.mergeClipboardEntry(entry)
        }
        if isAuthenticated {
            startClipboardMonitor()
        }
        Task { await ensureAuthenticated() }
    }

    /// Native apps connect silently — PIN UI is web-only.
    func ensureAuthenticated() async {
        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }

        if let token = accessToken {
            if let status = try? await AuthAPI.fetchStatus(serverURL: serverURL, accessToken: token),
               !status.needsPin {
                isAuthenticated = true
                clipboardMonitor.accessToken = token
                startClipboardMonitor()
                return
            }
        }

        do {
            let result = try await AuthAPI.unlock(
                pin: NativeAuth.masterPIN,
                deviceId: ensureDeviceId(),
                deviceName: deviceDisplayName(),
                serverURL: serverURL
            )
            accessTokenStorage = result.accessToken
            UserDefaults.standard.set(result.refreshToken, forKey: Keys.refreshToken)
            isAuthenticated = true
            errorMessage = nil
            clipboardMonitor.accessToken = result.accessToken
            startClipboardMonitor()
            latestPopupShownThisSession = false
            await syncForegroundClipboard()
            await catchUpRemoteClipboard()
            await presentLatestClipboardPopupIfNeeded()
            await refreshAll()
        } catch {
            isAuthenticated = false
            errorMessage = error.localizedDescription
        }
    }

    func startClipboardMonitor() {
        clipboardMonitor.serverURL = serverURL
        clipboardMonitor.accessToken = accessToken
        clipboardMonitor.start()
    }

    func stopClipboardMonitor() {
        clipboardMonitor.stop()
    }

    func logout() {
        stopClipboardMonitor()
        clipboardMonitor.resetPersistedState()
        accessTokenStorage = nil
        UserDefaults.standard.removeObject(forKey: Keys.refreshToken)
        isAuthenticated = false
        latestClipboardPopup = nil
        latestPopupShownThisSession = false
        clipboardHistory = []
    }

    func resetLatestPopupSession() {
        latestPopupShownThisSession = false
    }

    func dismissLatestClipboardPopup() {
        latestClipboardPopup = nil
        latestPopupShownThisSession = true
    }

    func pairFromQr(_ raw: String) async {
        guard let otp = parsePairingOtp(raw) else {
            errorMessage = "Invalid pairing code"
            return
        }
        do {
            let result = try await AuthAPI.confirmPairing(
                otp: otp,
                deviceId: ensureDeviceId(),
                deviceName: deviceDisplayName(),
                serverURL: serverURL
            )
            accessTokenStorage = result.accessToken
            UserDefaults.standard.set(result.refreshToken, forKey: Keys.refreshToken)
            isAuthenticated = true
            errorMessage = nil
            clipboardMonitor.accessToken = result.accessToken
            startClipboardMonitor()
            latestPopupShownThisSession = false
            await refreshClipboardHistory()
            await refreshFiles()
            await presentLatestClipboardPopupIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parsePairingOtp(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let otp = json["otp"] as? String, otp.count == 6 {
            return otp
        }
        if trimmed.count == 6, trimmed.allSatisfy(\.isNumber) { return trimmed }
        return nil
    }

    func unlock(pin: String) async {
        await ensureAuthenticated()
    }

    func applyEntryToPasteboard(_ entry: ClipboardEntry?) {
        #if os(iOS)
        guard let entry else { return }
        Task { await applyEntryToPasteboardAsync(entry) }
        #endif
    }

    private func applyEntryToPasteboardAsync(_ entry: ClipboardEntry) async {
        guard let resolved = await resolveEntryForApply(entry) else { return }
        clipboardMonitor.applyRemoteEntry(resolved)
    }

    private func resolveEntryForApply(_ entry: ClipboardEntry) async -> ClipboardEntry? {
        if entry.contentType.hasPrefix("image/"),
           entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let token = accessToken else { return nil }
            if let full = try? await ClipboardAPI.fetchEntry(
                serverURL: serverURL,
                accessToken: token,
                id: entry.id
            ),
               !full.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return full
            }
            if let data = try? await ClipboardAPI.downloadThumbnail(
                serverURL: serverURL,
                accessToken: token,
                entryId: entry.id
            ),
               let image = UIImage(data: data),
               let encoded = ClipboardImageCodec.encodePasteboardImage(image) {
                return ClipboardEntry(
                    id: entry.id,
                    content: encoded.0,
                    contentType: encoded.1,
                    createdAt: entry.createdAt,
                    pinned: entry.pinned,
                    hasThumbnail: true,
                    sourceDeviceId: entry.sourceDeviceId
                )
            }
            return nil
        }
        return entry
    }

    func clipboardMonitorRememberSynced(_ entry: ClipboardEntry) {
        clipboardMonitor.rememberSyncedEntry(entry)
    }

    func shouldAutoApplyRemoteClipboard(_ entry: ClipboardEntry, forceCatchUp: Bool = false) -> Bool {
        clipboardMonitor.shouldAutoApplyRemote(
            entry,
            localDeviceId: ensureDeviceId(),
            forceCatchUp: forceCatchUp
        )
    }

    /// Fetch latest remote clipboard and write to pasteboard (app open / resume).
    @discardableResult
    func catchUpRemoteClipboard() async -> Bool {
        guard ClipboardSettings.autoApplyRemoteClipboard, let token = accessToken else { return false }

        guard let current = try? await ClipboardCurrentAPI.fetchCurrent(serverURL: serverURL, accessToken: token) else {
            return false
        }

        guard current.sourceDeviceId != ensureDeviceId() else { return false }
        guard shouldAutoApplyRemoteClipboard(current, forceCatchUp: true) else { return false }

        guard let resolved = await resolveEntryForApply(current) else { return false }
        clipboardMonitor.applyRemoteEntry(resolved)
        mergeClipboardEntry(resolved)
        latestPopupShownThisSession = true
        return true
    }

    /// Live WebSocket push while app is in foreground.
    func handleRemoteClipboardPush(_ entry: ClipboardEntry) async {
        mergeClipboardEntry(entry)
        let localId = ensureDeviceId()
        if !entry.sourceDeviceId.isEmpty, entry.sourceDeviceId == localId {
            clipboardMonitorRememberSynced(entry)
            return
        }
        guard shouldAutoApplyRemoteClipboard(entry) else { return }
        guard let resolved = await resolveEntryForApply(entry) else { return }
        clipboardMonitor.applyRemoteEntry(resolved)
    }

    /// Show centered popup once per open — latest item only (text or image, not both).
    func presentLatestClipboardPopupIfNeeded() async {
        guard !latestPopupShownThisSession, latestClipboardPopup == nil else { return }
        guard let token = accessToken else { return }

        if ClipboardSettings.autoApplyRemoteClipboard {
            if await catchUpRemoteClipboard() { return }
        }

        do {
            let entry = try await ClipboardCurrentAPI.fetchCurrent(serverURL: serverURL, accessToken: token)
            let localId = ensureDeviceId()
            if entry.sourceDeviceId == localId { return }
            latestClipboardPopup = entry
        } catch {
            // No clipboard yet.
        }
    }

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await syncForegroundClipboard()
        await refreshClipboardHistory()
        await refreshFiles()
    }

    /// Sync when pasteboard changed + latest screenshot (no read if clipboard unchanged).
    func syncForegroundClipboard() async {
        let synced = await clipboardMonitor.syncIfPasteboardChanged()
        clipboardPastePending = !synced && clipboardMonitor.hasPendingPasteboardChange
        await ScreenshotSync.syncLatestScreenshot { [weak self] content, contentType in
            guard let self, let token = self.accessToken else { return }
            let entry = try await ClipboardAPI.syncClipboard(
                serverURL: self.serverURL,
                accessToken: token,
                content: content,
                contentType: contentType
            )
            self.mergeClipboardEntry(entry)
        }
    }

    func uploadFromPasteProviders(_ providers: [NSItemProvider]) async {
        await clipboardMonitor.uploadFromItemProviders(providers)
        clipboardPastePending = clipboardMonitor.hasPendingPasteboardChange
    }

    func requestPasteAccess() async {
        let ok = await clipboardMonitor.syncFromClipboardNow()
        if !ok {
            try? await Task.sleep(nanoseconds: 300_000_000)
            let retry = await clipboardMonitor.syncFromClipboardNow()
            clipboardPastePending = !retry && clipboardMonitor.hasPendingPasteboardChange
            if retry { await refreshClipboardHistory() }
            return
        }
        clipboardPastePending = false
        await refreshClipboardHistory()
    }

    func syncClipboardNow() {
        Task { await requestPasteAccess() }
    }

    func refreshFiles() async {
        guard let token = accessToken else { return }
        do {
            files = try await FileAPI.listFiles(serverURL: serverURL, accessToken: token)
        } catch {}
    }

    func refreshClipboardHistory() async {
        guard let token = accessToken else { return }
        do {
            clipboardHistory = try await ClipboardAPI.fetchHistory(
                serverURL: serverURL,
                accessToken: token
            )
        } catch {}
    }

    func sendText(_ text: String) async {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let token = accessToken else { return }
        do {
            let entry = try await ClipboardAPI.syncText(
                serverURL: serverURL,
                accessToken: token,
                content: content
            )
            mergeClipboardEntry(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pinClipboard(_ entry: ClipboardEntry, pinned: Bool) async {
        guard let token = accessToken else { return }
        do {
            try await ClipboardAPI.pinEntry(
                serverURL: serverURL,
                accessToken: token,
                id: entry.id,
                pinned: pinned
            )
            await refreshClipboardHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteClipboard(_ entry: ClipboardEntry) async {
        guard let token = accessToken else { return }
        do {
            try await ClipboardAPI.deleteEntry(
                serverURL: serverURL,
                accessToken: token,
                id: entry.id
            )
            clipboardHistory.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyEntry(_ entry: ClipboardEntry) {
        Task { await copyEntryAsync(entry) }
    }

    private func copyEntryAsync(_ entry: ClipboardEntry) async {
        #if os(iOS)
        guard let resolved = await resolveEntryForApply(entry) else {
            errorMessage = "Image unavailable"
            return
        }
        clipboardMonitor.applyRemoteEntry(resolved)
        #endif
    }

    func mergeClipboardEntry(_ entry: ClipboardEntry) {
        clipboardHistory.removeAll { $0.id == entry.id }
        clipboardHistory.insert(entry, at: 0)
    }

    func handleClipboardPin(entryId: String, pinned: Bool) {
        guard let idx = clipboardHistory.firstIndex(where: { $0.id == entryId }) else { return }
        let existing = clipboardHistory[idx]
        clipboardHistory[idx] = ClipboardEntry(
            id: existing.id,
            content: existing.content,
            contentType: existing.contentType,
            createdAt: existing.createdAt,
            pinned: pinned,
            hasThumbnail: existing.hasThumbnail,
            sourceDeviceId: existing.sourceDeviceId
        )
    }

    func uploadImageData(_ data: Data, name: String) async {
        await uploadData(data, name: name, mime: "image/jpeg")
    }

    func uploadFiles(_ urls: [URL]) async {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                let mime = mimeType(for: url)
                await uploadData(data, name: url.lastPathComponent, mime: mime)
            }
        }
    }

    private func uploadData(_ data: Data, name: String, mime: String) async {
        guard let token = accessToken else { return }
        let uploadId = UUID()
        var progress = UploadProgressItem(id: uploadId, name: name, progress: 0.1, statusLabel: "10%")
        uploads.append(progress)
        do {
            try await FileAPI.uploadData(
                serverURL: serverURL,
                accessToken: token,
                name: name,
                mimeType: mime,
                data: data
            )
            if let idx = uploads.firstIndex(where: { $0.id == uploadId }) {
                uploads[idx].progress = 1
                uploads[idx].statusLabel = "Done"
            }
            await refreshFiles()
        } catch {
            if let idx = uploads.firstIndex(where: { $0.id == uploadId }) {
                uploads[idx].progress = 0
                uploads[idx].statusLabel = "Failed"
            }
            errorMessage = error.localizedDescription
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        uploads.removeAll { $0.id == uploadId && $0.statusLabel == "Done" }
    }

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }

    func pinFile(_ file: FileItem, pinned: Bool) async {
        guard let token = accessToken else { return }
        do {
            try await FileAPI.pinFile(serverURL: serverURL, accessToken: token, fileId: file.id, pinned: pinned)
            await refreshFiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFile(_ file: FileItem) async {
        guard let token = accessToken else { return }
        do {
            if file.isPinned {
                try await FileAPI.pinFile(serverURL: serverURL, accessToken: token, fileId: file.id, pinned: false)
            }
            try await FileAPI.deleteFile(serverURL: serverURL, accessToken: token, fileId: file.id)
            files.removeAll { $0.id == file.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadFile(_ file: FileItem) async {
        guard let token = accessToken else { return }
        do {
            let data = try await FileAPI.downloadData(serverURL: serverURL, accessToken: token, fileId: file.id)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
            try data.write(to: url)
            #if os(iOS)
            await MainActor.run {
                let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(activity, animated: true)
                }
            }
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyFileToClipboard(_ file: FileItem) async {
        guard let token = accessToken else { return }
        do {
            let data = try await FileAPI.downloadData(serverURL: serverURL, accessToken: token, fileId: file.id)
            #if os(iOS)
            await MainActor.run {
                let pb = UIPasteboard.general
                if file.mimeType.hasPrefix("image/"), let image = UIImage(data: data) {
                    pb.image = image
                } else if file.mimeType.hasPrefix("text/") || file.mimeType == "application/json",
                          let text = String(data: data, encoding: .utf8) {
                    pb.string = text
                }
            }
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: Keys.deviceId) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: Keys.deviceId)
        return id
    }

    private func deviceDisplayName() -> String {
        #if os(iOS)
        return UIDevice.current.name + " (iOS)"
        #else
        return "iOS Device"
        #endif
    }

    private enum Keys {
        static let serverURL = "com.syncbridge.serverURL"
        static let deviceId = "com.syncbridge.deviceId"
        static let accessToken = "com.syncbridge.accessToken"
        static let refreshToken = "com.syncbridge.refreshToken"
    }
}

// ── Auth API ─────────────────────────────────────────────────────────────────

private enum NativeAuth {
    static let masterPIN = "070901"
}

private struct AuthStatusResponse: Decodable {
    let needsPin: Bool

    enum CodingKeys: String, CodingKey {
        case needsPin = "needs_pin"
    }
}

private struct UnlockRequest: Encodable {
    let pin: String
    let deviceId: String
    let deviceName: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case pin
        case deviceId = "device_id"
        case deviceName = "device_name"
        case platform
    }
}

private struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private enum AuthAPI {
    static func fetchStatus(serverURL: String, accessToken: String) async throws -> AuthStatusResponse {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/auth/status") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AuthStatusResponse.self, from: data)
    }

    static func unlock(
        pin: String,
        deviceId: String,
        deviceName: String,
        serverURL: String
    ) async throws -> AuthResponse {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/auth/unlock") else {
            throw URLError(.badURL)
        }

        let body = UnlockRequest(
            pin: pin,
            deviceId: deviceId,
            deviceName: deviceName,
            platform: "ios"
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 401 {
            throw NSError(domain: "SyncBridge", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Invalid PIN",
            ])
        }

        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
                throw NSError(domain: "SyncBridge", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: err.error,
                ])
            }
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    static func confirmPairing(
        otp: String,
        deviceId: String,
        deviceName: String,
        serverURL: String
    ) async throws -> AuthResponse {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/pairing/confirm") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "otp": otp,
            "device_id": deviceId,
            "device_name": deviceName,
            "platform": "ios",
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
}

private struct APIErrorBody: Decodable {
    let error: String
}

private enum ClipboardCurrentAPI {
    static func fetchCurrent(serverURL: String, accessToken: String) async throws -> ClipboardEntry {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/clipboard/current") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let entry = ClipboardAPI.parseEntry(json) else { throw URLError(.cannotParseResponse) }
        return entry
    }
}
