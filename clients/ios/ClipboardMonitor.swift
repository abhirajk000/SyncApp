// ClipboardMonitor.swift
// Outbound clipboard sync on iOS — event-driven only (no polling; polling triggers paste alerts).

import CryptoKit
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ClipboardMonitor {
    private static let lastChangeCountKey = "com.syncbridge.clipboard.lastChangeCount"
    private static let lastSyncedHashKey = "com.syncbridge.clipboard.lastSyncedHash"

    private var observer: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?
    /// changeCount after last successful read/upload; -1 = never synced this install.
    private var lastChangeCount = -1
    private var lastSyncedHash = ""
    private var suppressUntil = Date.distantPast
    private var lastLocalUserCopyAt = Date.distantPast
    private var isSyncing = false
    private var didLoadPersistedState = false

    var serverURL: String = ""
    var accessToken: String?
    var onLocalSync: ((ClipboardEntry) -> Void)?

    /// Pasteboard changed since last successful read — reading changeCount does not need paste permission.
    var hasPendingPasteboardChange: Bool {
        guard Date() > suppressUntil else { return false }
        loadPersistedStateIfNeeded()
        return UIPasteboard.general.changeCount != lastChangeCount
    }

    func start() {
        loadPersistedStateIfNeeded()
        stop()
        // Do NOT set lastChangeCount here — copies while backgrounded must still sync on return.
        observer = NotificationCenter.default.addObserver(
            forName: UIPasteboard.changedNotification,
            object: UIPasteboard.general,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onPasteboardChanged()
            }
        }
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    func resetPersistedState() {
        lastChangeCount = -1
        lastSyncedHash = ""
        didLoadPersistedState = true
        UserDefaults.standard.removeObject(forKey: Self.lastChangeCountKey)
        UserDefaults.standard.removeObject(forKey: Self.lastSyncedHashKey)
    }

    /// Sync when pasteboard changed since last successful upload (e.g. copied in Messages while away).
    @discardableResult
    func syncIfPasteboardChanged() async -> Bool {
        guard accessToken != nil else { return false }
        guard Date() > suppressUntil else { return false }
        loadPersistedStateIfNeeded()
        // Brief delay — pasteboard can lag behind app activation on iOS.
        try? await Task.sleep(nanoseconds: 150_000_000)
        let pb = UIPasteboard.general
        guard pb.changeCount != lastChangeCount else { return true }
        return await attemptUpload(from: pb, force: false)
    }

    /// User-initiated — triggers iOS paste permission so Settings → Paste from Other Apps appears.
    @discardableResult
    func syncFromClipboardNow() async -> Bool {
        guard accessToken != nil else { return false }
        guard Date() > suppressUntil else { return false }
        loadPersistedStateIfNeeded()
        return await attemptUpload(from: UIPasteboard.general, force: true)
    }

    /// Upload from UIPasteControl item providers — no system paste permission prompt.
    func uploadFromItemProviders(_ providers: [NSItemProvider]) async {
        guard accessToken != nil, Date() > suppressUntil else { return }
        guard let (content, type) = await loadFromItemProviders(providers) else { return }
        do {
            try await uploadParsed(content: content, contentType: type)
            markSynced(pasteboard: UIPasteboard.general, hash: hashFor(content: content, type: type))
        } catch {
            // Keep pending so user can retry.
        }
    }

    func applyRemoteEntry(_ entry: ClipboardEntry) {
        suppressUntil = Date().addingTimeInterval(2.5)

        let pb = UIPasteboard.general

        if entry.contentType.hasPrefix("image/"),
           let data = ClipboardImageCodec.decodeImageData(from: entry),
           let image = UIImage(data: data) {
            pb.image = image
            if let encoded = ClipboardImageCodec.encodePasteboardImage(image) {
                markSynced(pasteboard: pb, hash: sha256Data(Data(base64Encoded: encoded.0) ?? Data()))
            } else {
                markSynced(pasteboard: pb, hash: sha256Data(data))
            }
        } else if entry.contentType.hasPrefix("image/") {
            // Image payload still loading — don't mark synced with empty hash.
            return
        } else {
            pb.string = entry.content
            markSynced(pasteboard: pb, hash: sha256(entry.content))
        }
    }

    func rememberSyncedEntry(_ entry: ClipboardEntry) {
        markSynced(pasteboard: UIPasteboard.general, hash: hashFor(content: entry.content, type: entry.contentType))
    }

    func shouldAutoApplyRemote(
        _ entry: ClipboardEntry,
        localDeviceId: String,
        forceCatchUp: Bool = false
    ) -> Bool {
        guard ClipboardSettings.autoApplyRemoteClipboard else { return false }
        if entry.sourceDeviceId == localDeviceId { return false }
        if !forceCatchUp && entry.sourceDeviceId.isEmpty { return false }
        if entry.contentType.hasPrefix("image/"), !ClipboardSettings.autoSyncImages { return false }
        let hash = hashFor(content: entry.content, type: entry.contentType)
        if !forceCatchUp, !hash.isEmpty, hash == lastSyncedHash { return false }
        if !forceCatchUp, Date().timeIntervalSince(lastLocalUserCopyAt) < 4 { return false }
        return true
    }

    private func onPasteboardChanged() {
        guard accessToken != nil else { return }
        if Date() < suppressUntil { return }
        lastLocalUserCopyAt = Date()

        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let pb = UIPasteboard.general
            guard pb.changeCount != lastChangeCount else { return }
            _ = await attemptUpload(from: pb, force: false)
        }
    }

    @discardableResult
    private func attemptUpload(from pb: UIPasteboard, force: Bool) async -> Bool {
        guard ClipboardSettings.autoSyncClipboard else { return true }
        guard let (content, type) = readPasteboard(pb) else { return false }
        if type.hasPrefix("image/"), !ClipboardSettings.autoSyncImages { return false }
        let hash = hashFor(content: content, type: type)
        if hash == lastSyncedHash {
            markSynced(pasteboard: pb, hash: hash)
            return true
        }
        guard !isSyncing else { return false }

        isSyncing = true
        defer { isSyncing = false }
        do {
            try await uploadParsed(content: content, contentType: type)
            markSynced(pasteboard: pb, hash: hash)
            return true
        } catch {
            if force { lastSyncedHash = "" }
            return false
        }
    }

    private func uploadParsed(content: String, contentType: String) async throws {
        let entry = try await syncToServer(content: content, contentType: contentType)
        onLocalSync?(entry)
    }

    private func markSynced(pasteboard pb: UIPasteboard, hash: String) {
        lastChangeCount = pb.changeCount
        lastSyncedHash = hash
        UserDefaults.standard.set(lastChangeCount, forKey: Self.lastChangeCountKey)
        UserDefaults.standard.set(lastSyncedHash, forKey: Self.lastSyncedHashKey)
    }

    private func loadPersistedStateIfNeeded() {
        guard !didLoadPersistedState else { return }
        didLoadPersistedState = true
        if UserDefaults.standard.object(forKey: Self.lastChangeCountKey) != nil {
            lastChangeCount = UserDefaults.standard.integer(forKey: Self.lastChangeCountKey)
        }
        lastSyncedHash = UserDefaults.standard.string(forKey: Self.lastSyncedHashKey) ?? ""
    }

    private func hashFor(content: String, type: String) -> String {
        type.hasPrefix("image/")
            ? sha256Data(Data(base64Encoded: content) ?? Data())
            : sha256(content)
    }

    private func loadFromItemProviders(_ providers: [NSItemProvider]) async -> (String, String)? {
        for provider in providers {
            if provider.canLoadObject(ofClass: UIImage.self) {
                if let image = await loadUIImage(from: provider),
                   let encoded = ClipboardImageCodec.encodePasteboardImage(image) {
                    return encoded
                }
            }
            if provider.canLoadObject(ofClass: String.self) {
                if let text = await loadString(from: provider) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    if trimmed.hasPrefix("http"), URL(string: trimmed) != nil {
                        return (trimmed, "text/uri-list")
                    }
                    return (trimmed, "text/plain")
                }
            }
        }
        return nil
    }

    private func loadUIImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    private func loadString(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: String.self) { object, _ in
                continuation.resume(returning: object as? String)
            }
        }
    }

    private func readPasteboard(_ pb: UIPasteboard) -> (String, String)? {
        if let image = pb.image, let encoded = ClipboardImageCodec.encodePasteboardImage(image) {
            return encoded
        }

        let imageTypes: [String] = [
            UTType.png.identifier,
            UTType.jpeg.identifier,
            UTType.heic.identifier,
            UTType.gif.identifier,
            UTType.webP.identifier,
            "public.tiff",
            "com.compuserve.gif",
        ]
        for type in imageTypes {
            if let data = pb.data(forPasteboardType: type),
               let encoded = ClipboardImageCodec.encodeImageData(data) {
                return encoded
            }
        }

        if let text = readTextFromPasteboard(pb) {
            return text
        }
        return nil
    }

    /// Messages/SMS and other apps use different plain-text UTI variants.
    private func readTextFromPasteboard(_ pb: UIPasteboard) -> (String, String)? {
        let textTypes = [
            UTType.plainText.identifier,
            UTType.utf8PlainText.identifier,
            UTType.text.identifier,
            "public.plain-text",
            "public.utf8-plain-text",
            "public.text",
            "NSStringPboardType",
            "com.apple.uikit.attributedstring",
        ]

        for item in pb.items {
            for (type, value) in item {
                if let text = value as? String {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return normalizedText(trimmed) }
                }
                if let data = value as? Data {
                    if let raw = String(data: data, encoding: .utf8) {
                        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { return normalizedText(trimmed) }
                    }
                    if textTypes.contains(where: { type.contains($0) || $0.contains(type) }),
                       let raw = String(data: data, encoding: .utf8) {
                        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { return normalizedText(trimmed) }
                    }
                }
            }
        }

        for type in textTypes {
            if let data = pb.data(forPasteboardType: type),
               let raw = String(data: data, encoding: .utf8) {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return normalizedText(trimmed)
                }
            }
        }

        if let strings = pb.strings {
            for raw in strings {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return normalizedText(trimmed)
                }
            }
        }

        if let text = pb.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return normalizedText(text)
        }
        return nil
    }

    private func normalizedText(_ text: String) -> (String, String) {
        if text.hasPrefix("http"), URL(string: text) != nil {
            return (text, "text/uri-list")
        }
        return (text, "text/plain")
    }

    private func syncToServer(content: String, contentType: String) async throws -> ClipboardEntry {
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        return try await ClipboardAPI.syncClipboard(
            serverURL: serverURL,
            accessToken: token,
            content: content,
            contentType: contentType
        )
    }

    private func sha256(_ text: String) -> String {
        sha256Data(Data(text.utf8))
    }

    private func sha256Data(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
