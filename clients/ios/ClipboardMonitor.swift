// ClipboardMonitor.swift
// Outbound clipboard sync on iOS — polls pasteboard changeCount while app is active.

import CryptoKit
import UIKit

@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount = UIPasteboard.general.changeCount
    private var lastSyncedHash = ""
    private var suppressUntil = Date.distantPast
    private var isSyncing = false

    var serverURL: String = ""
    var accessToken: String?

    func start() {
        stop()
        lastChangeCount = UIPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func applyRemoteEntry(_ entry: ClipboardEntry) {
        suppressUntil = Date().addingTimeInterval(0.5)
        let pb = UIPasteboard.general
        if entry.contentType.hasPrefix("image/"),
           let data = Data(base64Encoded: entry.content),
           let image = UIImage(data: data) {
            pb.image = image
            lastSyncedHash = sha256Data(data)
        } else {
            pb.string = entry.content
            lastSyncedHash = sha256(entry.content)
        }
        lastChangeCount = pb.changeCount
    }

    private func poll() {
        guard accessToken != nil else { return }
        if Date() < suppressUntil { return }

        let pb = UIPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let (content, type) = readPasteboard(pb) else { return }
        let hash = type.hasPrefix("image/") ? sha256Data(Data(base64Encoded: content) ?? Data()) : sha256(content)
        guard hash != lastSyncedHash, !isSyncing else { return }

        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                try await syncToServer(content: content, contentType: type)
                lastSyncedHash = hash
            } catch {
                // Ignore transient errors; next copy will retry.
            }
        }
    }

    private func readPasteboard(_ pb: UIPasteboard) -> (String, String)? {
        if let image = pb.image, let data = image.pngData() {
            let b64 = data.base64EncodedString()
            return (b64, "image/png")
        }
        if let text = pb.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            if let url = URL(string: text), url.scheme != nil {
                return (text, "text/uri-list")
            }
            return (text, "text/plain")
        }
        return nil
    }

    private func syncToServer(content: String, contentType: String) async throws {
        guard let token = accessToken else { return }
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/clipboard") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "content_type": contentType,
            "content": content,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func sha256(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256Data(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
