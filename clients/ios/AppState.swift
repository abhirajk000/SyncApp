// AppState.swift
// Auth state and PIN unlock — mirrors macOS AppState / AuthService.

import Foundation

@MainActor
final class AppState: ObservableObject {
    static let defaultServerURL = "http://localhost:8080"

    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var latestClipboardPopup: ClipboardEntry?

    var serverURL: String {
        get { UserDefaults.standard.string(forKey: Keys.serverURL) ?? Self.defaultServerURL }
        set { UserDefaults.standard.set(newValue, forKey: Keys.serverURL) }
    }

    var accessToken: String? {
        UserDefaults.standard.string(forKey: Keys.accessToken)
    }

    private var accessTokenStorage: String? {
        get { UserDefaults.standard.string(forKey: Keys.accessToken) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.accessToken) }
    }

    init() {
        isAuthenticated = accessToken != nil
    }

    func logout() {
        accessTokenStorage = nil
        UserDefaults.standard.removeObject(forKey: Keys.refreshToken)
        isAuthenticated = false
        latestClipboardPopup = nil
    }

    func unlock(pin: String) async {
        do {
            let result = try await AuthAPI.unlock(
                pin: pin,
                deviceId: ensureDeviceId(),
                deviceName: deviceDisplayName(),
                serverURL: serverURL
            )
            accessTokenStorage = result.accessToken
            UserDefaults.standard.set(result.refreshToken, forKey: Keys.refreshToken)
            isAuthenticated = true
            errorMessage = nil
            await loadLatestClipboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLatestClipboard() async {
        guard let token = accessToken else { return }
        do {
            let entry = try await ClipboardAPI.fetchCurrent(serverURL: serverURL, accessToken: token)
            latestClipboardPopup = entry
            #if os(iOS)
            UIPasteboard.general.string = entry.content
            #endif
        } catch {
            // No clipboard yet.
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

#if os(iOS)
import UIKit
#endif

// ── Auth API ─────────────────────────────────────────────────────────────────

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
}

private struct APIErrorBody: Decodable {
    let error: String
}

// ── Clipboard API ─────────────────────────────────────────────────────────────

private enum ClipboardAPI {
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
        return ClipboardEntry(
            id: json["id"] as? String ?? UUID().uuidString,
            content: json["content"] as? String ?? "",
            contentType: json["content_type"] as? String ?? "text/plain",
            createdAt: json["created_at"] as? String ?? ISO8601DateFormatter().string(from: Date()),
            pinned: json["pinned"] as? Bool ?? false
        )
    }
}
