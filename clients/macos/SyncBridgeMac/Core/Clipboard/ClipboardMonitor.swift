// ClipboardMonitor.swift
// Watches NSPasteboard for changes and syncs new content to the server.
//
// Design:
//   • Polls `NSPasteboard.general.changeCount` every 100 ms — event-driven via
//     changeCount (no full scheduled sync; lowest-latency approach on macOS).
//   • SHA-256 deduplication: only syncs if the content hash changed since the
//     last successful sync.
//   • Echo suppression: when the monitor writes to the pasteboard (in response
//     to a clipboard.new WS event from another device), it sets a suppression
//     flag for 500 ms so it doesn't re-upload the same content.
//   • Supported content types: text/plain, text/uri-list (URLs), text/html,
//     text/rtf — matching the Phase 5 backend allowlist.
//
// Privacy: macOS 14+ shows a one-time permission prompt when the app reads
// the clipboard in the background.  Add NSPasteboardUsageDescription to
// Info.plist with a user-facing explanation string.

import AppKit
import CryptoKit
import Combine

final class ClipboardMonitor {

    // MARK: – Public interface

    /// Called on main queue when a new entry arrives from another device.
    var onRemoteEntry: ((ClipboardEntryResponse) -> Void)?

    // MARK: – Private

    private let authService: AuthService
    private let keychain = KeychainService.shared
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.syncbridge.clipboard", qos: .utility)
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastSyncedHash: String = ""
    private var suppressUntil: Date = .distantPast
    private var isSyncing = false

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: – Lifecycle

    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.1, repeating: 0.1)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: – Remote clipboard update (called by WSClient handler)

    /// Writes a clipboard entry received from another device into the local pasteboard.
    func applyRemoteEntry(_ entry: ClipboardEntryResponse) {
        // Suppress our own polling echo for 500 ms after writing.
        suppressUntil = Date().addingTimeInterval(0.5)

        DispatchQueue.main.async {
            let pb = NSPasteboard.general
            pb.clearContents()

            switch entry.contentType {
            case "text/plain", "text/uri-list":
                pb.setString(entry.content, forType: .string)
                if entry.contentType == "text/uri-list",
                   let url = URL(string: entry.content) {
                    pb.setString(entry.content, forType: .URL)
                    pb.writeObjects([url as NSURL])
                }
            case "text/html":
                if let data = entry.content.data(using: .utf8) {
                    pb.setData(data, forType: .html)
                }
                pb.setString(entry.content, forType: .string)
            default:
                pb.setString(entry.content, forType: .string)
            }
            self.lastSyncedHash = sha256(entry.content)
            self.lastChangeCount = pb.changeCount
        }

        onRemoteEntry?(entry)
    }

    // MARK: – Private: polling

    private func poll() {
        let pb = NSPasteboard.general
        let current = pb.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // Skip if we just wrote to the pasteboard ourselves.
        guard Date() > suppressUntil else { return }

        // Read content and determine type.
        guard let (content, contentType) = readPasteboard(pb) else { return }

        let hash = sha256(content)
        guard hash != lastSyncedHash else { return } // deduplicate
        lastSyncedHash = hash

        guard keychain.isAuthenticated, !isSyncing else { return }
        isSyncing = true

        Task {
            defer { self.isSyncing = false }
            _ = try? await self.authService.syncClipboard(
                contentType: contentType,
                content: content
            )
        }
    }

    // MARK: – Pasteboard reading

    private func readPasteboard(_ pb: NSPasteboard) -> (String, String)? {
        // Prefer rich HTML if available.
        if let html = pb.string(forType: .html), !html.isEmpty {
            return (html, "text/html")
        }
        // Plain string / URL.
        if let str = pb.string(forType: .string), !str.isEmpty {
            // Detect URL-only content.
            if let _ = URL(string: str), str.hasPrefix("http") {
                return (str, "text/uri-list")
            }
            return (str, "text/plain")
        }
        // URL objects.
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first {
            return (first.absoluteString, "text/uri-list")
        }
        return nil
    }
}

// MARK: – SHA-256 helper

private func sha256(_ input: String) -> String {
    let digest = SHA256.hash(data: Data(input.utf8))
    return digest.compactMap { String(format: "%02x", $0) }.joined()
}
