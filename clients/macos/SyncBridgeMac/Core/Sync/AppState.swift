// AppState.swift
// The single source of truth for all runtime state in the app.
//
// Ownership hierarchy:
//   AppState (ObservableObject)
//     ├── APIClient          (stateless HTTP client)
//     ├── AuthService        (depends on APIClient)
//     ├── WSClient           (WebSocket; receives events, dispatches to AppState)
//     ├── ClipboardMonitor   (depends on AuthService)
//     └── FileTransferService
//
// SwiftUI views observe @EnvironmentObject<AppState> and react to @Published
// properties.  All mutations happen on the main actor.

import Foundation
import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // ── Auth ──────────────────────────────────────────────────────────────────
    @Published var authState: AuthState = .loggedOut
    @Published var syncStatus: SyncStatus = .disconnected

    // ── Latest clipboard popup ────────────────────────────────────────────────
    @Published var latestClipboardPopup: ClipboardEntryResponse? = nil
    /// One popup per unlock / window open — WS events do not stack popups.
    private var latestPopupShownThisSession = false
    @Published var isRefreshing = false

    @AppStorage("syncEnabled") private var syncEnabled = true
    @AppStorage("autoApplyRemoteClipboard") private var autoApplyRemoteClipboard = true
    @AppStorage("autoSyncImages") private var autoSyncImages = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("historyLimit") private var historyLimit = 100

    // ── Clipboard ─────────────────────────────────────────────────────────────
    @Published var clipboardHistory: [ClipboardEntryResponse] = []

    // ── Devices ───────────────────────────────────────────────────────────────
    @Published var devices: [DeviceResponse] = []

    // ── Files ─────────────────────────────────────────────────────────────────
    @Published var files: [FileResponse] = []
    @Published var activeTransfers: [TransferItem] = []

    // ── Services ──────────────────────────────────────────────────────────────
    let api = APIClient.shared
    let authService: AuthService
    let wsClient: WSClient
    let clipboardMonitor: ClipboardMonitor
    let fileTransferService: FileTransferService
    let networkManager: NetworkManager

    // ── Error banner ──────────────────────────────────────────────────────────
    @Published var errorMessage: String? = nil

    // ── Pairing ───────────────────────────────────────────────────────────────
    @Published var pairingQrPayload: String? = nil
    @Published var pairingOtp: String? = nil
    @Published var pairingExpiresAt: String? = nil
    @Published var isPairingActive: Bool = false

    /// Set by AppDelegate — opens the standalone app window (not the menu bar popover).
    var openMainWindowHandler: (() -> Void)?

    func requestOpenMainWindow() {
        openMainWindowHandler?()
    }

    init() {
        let authService = AuthService(api: .shared)
        let networkManager = NetworkManager(auth: authService)
        let wsClient = WSClient()
        let clipboardMonitor = ClipboardMonitor(authService: authService)
        let fileTransferService = FileTransferService(api: .shared, authService: authService, networkManager: networkManager)

        self.authService = authService
        self.networkManager = networkManager
        self.wsClient = wsClient
        self.clipboardMonitor = clipboardMonitor
        self.fileTransferService = fileTransferService

        clipboardMonitor.onLocalSync = { [weak self] entry in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let idx = self.clipboardHistory.firstIndex(where: { $0.id == entry.id }) {
                    self.clipboardHistory[idx] = entry
                } else {
                    self.clipboardHistory.insert(entry, at: 0)
                }
                let limit = max(10, min(self.historyLimit, 500))
                if self.clipboardHistory.count > limit {
                    self.clipboardHistory.removeLast(self.clipboardHistory.count - limit)
                }
                self.networkManager.markSync()
            }
        }

        wireWSClient()

        // Restore session if tokens exist; verify trust window on appear.
        if KeychainService.shared.isAuthenticated {
            let userId = KeychainService.shared.userId ?? ""
            let deviceId = KeychainService.shared.deviceId ?? ""
            authState = .loggedIn(userId: userId, deviceId: deviceId)
        }
    }

    // ── Startup / shutdown ────────────────────────────────────────────────────

    func onAppear() {
        Task { await restoreSession() }
    }

    /// Restore trust or silently re-unlock — PIN UI is web-only.
    func restoreSession() async {
        if !KeychainService.shared.isAuthenticated {
            await silentUnlock()
            return
        }
        do {
            let status = try await authService.checkStatus()
            if status.needsPin {
                await silentUnlock()
                return
            }
            if case .loggedIn = authState {
                startServices()
                await refreshAll()
                _ = await catchUpRemoteClipboard()
                await presentLatestClipboardPopup()
            }
        } catch {
            await silentUnlock()
        }
    }

    private func silentUnlock() async {
        authState = .loggingIn
        do {
            let resp = try await authService.silentUnlock()
            authState = .loggedIn(userId: resp.userId, deviceId: resp.deviceId)
            latestPopupShownThisSession = false
            startServices()
            await refreshAll()
            await presentLatestClipboardPopup()
        } catch {
            authState = .loggedOut
            errorMessage = errorDescription(error)
        }
    }

    func onDisappear() {
        // Don't stop services — app stays in background.
    }

    func startServices() {
        syncStatus = .connecting
        networkManager.start()
        wsClient.connect()
        clipboardMonitor.autoSyncEnabled = syncEnabled
        clipboardMonitor.autoSyncImagesEnabled = autoSyncImages
        if syncEnabled {
            clipboardMonitor.start()
        }
        NotificationService.requestPermission()
    }

    func stopServices() {
        wsClient.disconnect()
        networkManager.stop()
        clipboardMonitor.stop()
        syncStatus = .disconnected
    }

    // ── Auth actions ──────────────────────────────────────────────────────────

    func unlock(pin: String) async {
        await silentUnlock()
    }

    func logout() async {
        stopServices()
        await authService.logout()
        authState = .loggedOut
        latestClipboardPopup = nil
        latestPopupShownThisSession = false
        clipboardHistory = []
        devices = []
        files = []
    }

    // ── Pairing ───────────────────────────────────────────────────────────────

    func initiatePairing() async {
        do {
            let resp = try await authService.initiatePairing()
            pairingQrPayload = resp.qrPayload
            pairingOtp = resp.otp
            pairingExpiresAt = resp.expiresAt
            isPairingActive = true
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    // ── Data refresh ──────────────────────────────────────────────────────────

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshClipboardHistory() }
            group.addTask { await self.refreshDevices() }
            group.addTask { await self.refreshFiles() }
        }
    }

    func refreshHome() async {
        await refreshAll()
    }

    func refreshClipboardHistory() async {
        do {
            let limit = max(10, min(historyLimit, 500))
            let resp = try await authService.getClipboardHistory(limit: limit)
            clipboardHistory = resp.entries
        } catch {
            if handleAuthError(error) { return }
        }
    }

    /// Fetch and show the latest clipboard entry after auth (centered popup, once per session).
    func presentLatestClipboardPopup() async {
        guard !latestPopupShownThisSession, latestClipboardPopup == nil else { return }
        do {
            let entry = try await authService.getCurrentClipboard()
            latestClipboardPopup = entry
        } catch {
            // No clipboard yet — skip popup.
        }
    }

    func resetLatestPopupSession() {
        latestPopupShownThisSession = false
    }

    func dismissLatestClipboardPopup() {
        latestClipboardPopup = nil
        latestPopupShownThisSession = true
    }

    func refreshDevices() async {
        do {
            let resp = try await authService.listDevices()
            devices = resp.devices
        } catch {}
    }

    func refreshFiles() async {
        do {
            let resp = try await authService.listFiles()
            files = resp.files
        } catch {}
    }

    /// Fetch latest remote clipboard and write to pasteboard (app open / resume).
    @discardableResult
    func catchUpRemoteClipboard() async -> Bool {
        guard autoApplyRemoteClipboard else { return false }
        guard let current = try? await authService.getCurrentClipboard() else { return false }
        let localId = KeychainService.shared.deviceId ?? ""
        guard current.sourceDeviceId != localId else { return false }
        guard clipboardMonitor.shouldAutoApplyRemote(current, localDeviceId: localId, forceCatchUp: true) else {
            return false
        }
        guard let resolved = await resolveEntryForApply(current) else { return false }
        clipboardMonitor.applyRemoteEntry(resolved)
        mergeClipboardEntry(resolved)
        return true
    }

    private func mergeClipboardEntry(_ entry: ClipboardEntryResponse) {
        if let idx = clipboardHistory.firstIndex(where: { $0.id == entry.id }) {
            clipboardHistory[idx] = entry
        } else {
            clipboardHistory.insert(entry, at: 0)
        }
        let limit = max(10, min(historyLimit, 500))
        if clipboardHistory.count > limit { clipboardHistory.removeLast() }
    }

    private func resolveEntryForApply(_ entry: ClipboardEntryResponse) async -> ClipboardEntryResponse? {
        if entry.contentType.hasPrefix("image/"),
           entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let full = try? await authService.getClipboardEntry(id: entry.id),
               !full.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return full
            }
            if let data = await api.downloadClipboardThumbnail(entryId: entry.id),
               let image = NSImage(data: data),
               let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                let b64 = jpeg.base64EncodedString()
                return ClipboardEntryResponse(
                    id: entry.id, contentType: "image/jpeg", content: b64,
                    sourceDeviceId: entry.sourceDeviceId, createdAt: entry.createdAt,
                    pinned: entry.pinned, expiresAt: entry.expiresAt, hasThumbnail: true
                )
            }
            return nil
        }
        return entry
    }

    // ── Clipboard actions ─────────────────────────────────────────────────────

    func copyToClipboard(_ entry: ClipboardEntryResponse) {
        if entry.contentType.hasPrefix("image/"),
           entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                if let full = try? await authService.getClipboardEntry(id: entry.id),
                   !full.content.isEmpty {
                    clipboardMonitor.applyRemoteEntry(full)
                    return
                }
                if let data = await api.downloadClipboardThumbnail(entryId: entry.id),
                   let image = NSImage(data: data) {
                    await MainActor.run {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.writeObjects([image])
                    }
                    return
                }
                errorMessage = "Image unavailable"
            }
            return
        }
        clipboardMonitor.applyRemoteEntry(entry)
    }

    func deleteClipboardEntry(_ entry: ClipboardEntryResponse) async {
        do {
            try await authService.deleteClipboardEntry(id: entry.id)
            clipboardHistory.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    func pinClipboardEntry(_ entry: ClipboardEntryResponse, pinned: Bool) async {
        do {
            try await authService.pinClipboardEntry(id: entry.id, pinned: pinned)
            if let idx = clipboardHistory.firstIndex(where: { $0.id == entry.id }) {
                var updated = clipboardHistory[idx]
                clipboardHistory[idx] = ClipboardEntryResponse(
                    id: updated.id, contentType: updated.contentType, content: updated.content,
                    sourceDeviceId: updated.sourceDeviceId, createdAt: updated.createdAt,
                    pinned: pinned, expiresAt: updated.expiresAt,
                    hasThumbnail: updated.hasThumbnail
                )
            }
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    func pinFile(_ file: FileResponse, pinned: Bool) async {
        do {
            try await authService.pinFile(id: file.id, pinned: pinned)
            await refreshFiles()
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    func deleteFile(_ file: FileResponse) async {
        do {
            if file.isPinned {
                try await authService.pinFile(id: file.id, pinned: false)
            }
            try await authService.deleteFile(id: file.id)
            files.removeAll { $0.id == file.id }
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    func copyFileToClipboard(_ file: FileResponse) async {
        guard file.status == "ready" else { return }
        if file.mimeType.hasPrefix("image/") {
            if let data = await api.downloadFileData(fileId: file.id, maxBytes: 10 * 1024 * 1024),
               let image = NSImage(data: data) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([image])
            }
            return
        }
        if isTextFileMime(file.mimeType) || ["md", "txt", "csv", "json"].contains((file.name as NSString).pathExtension.lowercased()) {
            if let data = await api.downloadFileData(fileId: file.id, maxBytes: 512 * 1024),
               let text = String(data: data, encoding: .utf8) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
            }
        }
    }

    private func isTextFileMime(_ mime: String) -> Bool {
        mime.hasPrefix("text/") || mime == "application/json"
    }

    @discardableResult
    private func handleAuthError(_ error: Error) -> Bool {
        if let apiErr = error as? APIError, apiErr.error == "session expired" {
            stopServices()
            Task { await silentUnlock() }
            return true
        }
        return false
    }

    // ── File actions ──────────────────────────────────────────────────────────

    func uploadFiles(_ urls: [URL]) {
        let isFolder = urls.contains {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        let count = urls.count
        for url in urls {
            uploadFile(url, fileCount: count, isFolder: isFolder)
        }
    }

    func uploadFile(_ url: URL, fileCount: Int = 1, isFolder: Bool = false) {
        let item = TransferItem(
            id: UUID().uuidString,
            name: url.lastPathComponent,
            totalSize: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0,
            progress: 0,
            status: .uploading
        )
        activeTransfers.append(item)
        let transferId = item.id

        fileTransferService.upload(
            fileURL: url,
            fileCount: fileCount,
            isFolder: isFolder,
            onProgress: { [weak self] pct in
                Task { @MainActor [weak self] in
                    if let idx = self?.activeTransfers.firstIndex(where: { $0.id == transferId }) {
                        self?.activeTransfers[idx].progress = pct
                    }
                }
            },
            onComplete: { [weak self] result in
                Task { @MainActor [weak self] in
                    if let idx = self?.activeTransfers.firstIndex(where: { $0.id == transferId }) {
                        switch result {
                        case .success(let file):
                            self?.activeTransfers[idx].status = .ready
                            self?.files.insert(file, at: 0)
                        case .failure:
                            self?.activeTransfers[idx].status = .failed
                        }
                    }
                }
            }
        )
    }

    func downloadFile(_ file: FileResponse) {
        let item = TransferItem(
            id: file.id,
            name: file.name,
            totalSize: file.totalSize,
            progress: 0,
            status: .downloading
        )
        activeTransfers.append(item)

        fileTransferService.download(
            fileId: file.id,
            fileName: file.name,
            onProgress: { [weak self] pct in
                Task { @MainActor [weak self] in
                    if let idx = self?.activeTransfers.firstIndex(where: { $0.id == file.id }) {
                        self?.activeTransfers[idx].progress = pct
                    }
                }
            },
            onComplete: { [weak self] result in
                Task { @MainActor [weak self] in
                    if let idx = self?.activeTransfers.firstIndex(where: { $0.id == file.id }) {
                        switch result {
                        case .success(let url):
                            self?.activeTransfers[idx].status = .ready
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        case .failure:
                            self?.activeTransfers[idx].status = .failed
                        }
                    }
                }
            }
        )
    }

    // ── WebSocket wiring ──────────────────────────────────────────────────────

    private func wireWSClient() {
        wsClient.onConnectionChange = { [weak self] connected in
            Task { @MainActor [weak self] in
                self?.syncStatus = connected ? .connected : .connecting
                self?.networkManager.wsConnected = connected
            }
        }
        wsClient.onMessage = { [weak self] envelope in
            Task { @MainActor [weak self] in
                self?.handleWSMessage(envelope)
            }
        }
    }

    private func handleWSMessage(_ envelope: WSEnvelope) {
        switch envelope.type {

        case "clipboard.new":
            guard let payload = envelope.payload?.value as? [String: Any],
                  let id = payload["entry_id"] as? String,
                  let contentType = payload["content_type"] as? String,
                  let sourceDeviceId = payload["source_device_id"] as? String,
                  let createdAt = payload["created_at"] as? String else { return }

            let content = payload["content"] as? String ?? ""
            let entry = ClipboardEntryResponse(
                id: id,
                contentType: contentType,
                content: content,
                sourceDeviceId: sourceDeviceId,
                createdAt: createdAt,
                pinned: payload["pinned"] as? Bool ?? false,
                expiresAt: payload["expires_at"] as? String,
                hasThumbnail: payload["has_thumbnail"] as? Bool ?? contentType.hasPrefix("image/")
            )

            mergeClipboardEntry(entry)

            let localId = KeychainService.shared.deviceId ?? ""
            Task {
                if !sourceDeviceId.isEmpty, sourceDeviceId == localId {
                    clipboardMonitor.rememberSyncedEntry(entry)
                    return
                }
                clipboardMonitor.autoSyncImagesEnabled = autoSyncImages
                guard autoApplyRemoteClipboard,
                      clipboardMonitor.shouldAutoApplyRemote(entry, localDeviceId: localId) else { return }
                guard let resolved = await resolveEntryForApply(entry) else { return }
                clipboardMonitor.applyRemoteEntry(resolved)
            }

            if showNotifications {
                let preview = contentType.hasPrefix("image/") ? "Image received" : content
                NotificationService.notifyClipboardUpdated(preview: preview)
            }
            syncStatus = .connected
            networkManager.markSync()

        case "clipboard.pin":
            guard let payload = envelope.payload?.value as? [String: Any],
                  let id = payload["entry_id"] as? String,
                  let pinned = payload["pinned"] as? Bool else { return }
            if let idx = clipboardHistory.firstIndex(where: { $0.id == id }) {
                let e = clipboardHistory[idx]
                clipboardHistory[idx] = ClipboardEntryResponse(
                    id: e.id, contentType: e.contentType, content: e.content,
                    sourceDeviceId: e.sourceDeviceId, createdAt: e.createdAt,
                    pinned: pinned, expiresAt: e.expiresAt,
                    hasThumbnail: e.hasThumbnail
                )
            }

        case "file.pin":
            Task { await self.refreshFiles() }

        case "file.ready":
            guard let payload = envelope.payload?.value as? [String: Any],
                  let fileId = payload["file_id"] as? String else { return }
            networkManager.markSync()
            Task { await self.refreshFiles() }
            if let idx = activeTransfers.firstIndex(where: { $0.id == fileId }) {
                activeTransfers[idx].status = .ready
            }

        case "file.progress":
            guard let payload = envelope.payload?.value as? [String: Any],
                  let fileId = payload["file_id"] as? String,
                  let pct = payload["progress_percent"] as? Double else { return }
            networkManager.markSync()
            if let idx = activeTransfers.firstIndex(where: { $0.id == fileId }) {
                activeTransfers[idx].progress = pct / 100
            }

        case "file.failed":
            guard let payload = envelope.payload?.value as? [String: Any],
                  let fileId = payload["file_id"] as? String else { return }
            if let idx = activeTransfers.firstIndex(where: { $0.id == fileId }) {
                activeTransfers[idx].status = .failed
            }

        case "presence":
            // Device online/offline — refresh device list.
            Task { await self.refreshDevices() }

        case "signal.peer":
            guard let payload = envelope.payload?.value as? [String: Any],
                  let deviceId = payload["device_id"] as? String else { return }
            let addrs = payload["addrs"] as? [String] ?? []
            let port = payload["port"] as? Int ?? 0
            if networkManager.handleSignalPeer(deviceId: deviceId, addrs: addrs, port: port),
               showNotifications {
                NotificationService.notifyClipboardUpdated(preview: "Nearby device available")
            }

        default:
            break
        }
    }

    // ── Error formatting ──────────────────────────────────────────────────────

    private func errorDescription(_ error: Error) -> String {
        if let apiErr = error as? APIError { return apiErr.error }
        return error.localizedDescription
    }
}
