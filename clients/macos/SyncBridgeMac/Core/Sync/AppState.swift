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

    @AppStorage("syncEnabled") private var syncEnabled = true
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
        Task { await restoreOrPromptPIN() }
    }

    /// If the device is still trusted, start services; otherwise show the PIN screen.
    func restoreOrPromptPIN() async {
        guard KeychainService.shared.isAuthenticated else { return }
        do {
            let status = try await authService.checkStatus()
            if status.needsPin {
                authState = .loggedOut
                return
            }
            if case .loggedIn = authState {
                startServices()
                await refreshAll()
                await presentLatestClipboardPopup()
            }
        } catch {
            authState = .loggedOut
        }
    }

    func onDisappear() {
        // Don't stop services — app stays in background.
    }

    func startServices() {
        syncStatus = .connecting
        networkManager.start()
        wsClient.connect()
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
        authState = .loggingIn
        do {
            let resp = try await authService.unlock(pin: pin)
            authState = .loggedIn(userId: resp.userId, deviceId: resp.deviceId)
            startServices()
            await refreshAll()
            await presentLatestClipboardPopup()
        } catch {
            authState = .loggedOut
            errorMessage = errorDescription(error)
        }
    }

    func logout() async {
        stopServices()
        await authService.logout()
        authState = .loggedOut
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
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshClipboardHistory() }
            group.addTask { await self.refreshDevices() }
            group.addTask { await self.refreshFiles() }
        }
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

    /// Fetch and show the latest clipboard entry after auth (centered popup).
    func presentLatestClipboardPopup() async {
        do {
            let entry = try await authService.getCurrentClipboard()
            latestClipboardPopup = entry
        } catch {
            // No clipboard yet — skip popup.
        }
    }

    func dismissLatestClipboardPopup() {
        latestClipboardPopup = nil
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

    // ── Clipboard actions ─────────────────────────────────────────────────────

    func copyToClipboard(_ entry: ClipboardEntryResponse) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.content, forType: .string)
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
                    pinned: pinned, expiresAt: updated.expiresAt
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

    @discardableResult
    private func handleAuthError(_ error: Error) -> Bool {
        if let apiErr = error as? APIError, apiErr.error == "session expired" {
            stopServices()
            authState = .loggedOut
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
                  let content = payload["content"] as? String,
                  let sourceDeviceId = payload["source_device_id"] as? String,
                  let createdAt = payload["created_at"] as? String else { return }

            let entry = ClipboardEntryResponse(
                id: id,
                contentType: contentType,
                content: content,
                sourceDeviceId: sourceDeviceId,
                createdAt: createdAt,
                pinned: payload["pinned"] as? Bool ?? false,
                expiresAt: payload["expires_at"] as? String
            )
            clipboardMonitor.applyRemoteEntry(entry)
            clipboardHistory.insert(entry, at: 0)
            let limit = max(10, min(historyLimit, 500))
            if clipboardHistory.count > limit { clipboardHistory.removeLast() }

            if showNotifications {
                NotificationService.notifyClipboardUpdated(preview: content)
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
                    pinned: pinned, expiresAt: e.expiresAt
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
