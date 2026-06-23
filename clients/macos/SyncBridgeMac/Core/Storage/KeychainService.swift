// KeychainService.swift
// Local credential storage for the macOS client.
//
// Uses app-scoped UserDefaults instead of the system Keychain so unsigned /
// ad-hoc builds do not trigger repeated "login keychain password" prompts after
// each reinstall. (Android uses SharedPreferences for the same data.)

import Foundation

/// Keys used to identify stored credentials.
enum KeychainKey: String {
    case accessToken   = "com.syncbridge.accessToken"
    case refreshToken  = "com.syncbridge.refreshToken"
    case serverURL     = "com.syncbridge.serverURL"
    case userId        = "com.syncbridge.userId"
    case deviceId      = "com.syncbridge.deviceId"
    case deviceName    = "com.syncbridge.deviceName"
    case trustedUntil  = "com.syncbridge.trustedUntil"
}

/// Thread-safe credential accessor.
final class KeychainService {
    static let shared = KeychainService()

    private let defaults = UserDefaults(suiteName: "com.syncbridge.mac.credentials")
        ?? UserDefaults.standard
    private let keyPrefix = "credential."

    private init() {}

    // ── Write ─────────────────────────────────────────────────────────────────

    @discardableResult
    func set(_ value: String, for key: KeychainKey) -> Bool {
        defaults.set(value, forKey: storageKey(key))
        return true
    }

    // ── Read ──────────────────────────────────────────────────────────────────

    func get(_ key: KeychainKey) -> String? {
        defaults.string(forKey: storageKey(key))
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    @discardableResult
    func delete(_ key: KeychainKey) -> Bool {
        defaults.removeObject(forKey: storageKey(key))
        return true
    }

    // ── Bulk operations ───────────────────────────────────────────────────────

    /// Removes all SyncBridge credentials (on logout).
    func clearAll() {
        let keys: [KeychainKey] = [
            .accessToken, .refreshToken, .userId,
            .deviceId, .deviceName, .trustedUntil
        ]
        keys.forEach { delete($0) }
    }

    // ── Convenience computed properties ───────────────────────────────────────

    var accessToken: String? {
        get { get(.accessToken) }
        set {
            if let v = newValue { set(v, for: .accessToken) }
            else { delete(.accessToken) }
        }
    }

    var refreshToken: String? {
        get { get(.refreshToken) }
        set {
            if let v = newValue { set(v, for: .refreshToken) }
            else { delete(.refreshToken) }
        }
    }

    var serverURL: String {
        get { Self.defaultServerURL }
        set { /* fixed production endpoint */ }
    }

    static let defaultServerURL = "https://sync.abhiraj.xyz"

    var userId: String? {
        get { get(.userId) }
        set {
            if let v = newValue { set(v, for: .userId) }
            else { delete(.userId) }
        }
    }

    var deviceId: String? {
        get { get(.deviceId) }
        set {
            if let v = newValue { set(v, for: .deviceId) }
            else { delete(.deviceId) }
        }
    }

    var trustedUntil: String? {
        get { get(.trustedUntil) }
        set {
            if let v = newValue { set(v, for: .trustedUntil) }
            else { delete(.trustedUntil) }
        }
    }

    /// Returns a stable device UUID, creating and persisting one on first call.
    func ensureDeviceId() -> String {
        if let existing = deviceId { return existing }
        let id = UUID().uuidString
        deviceId = id
        return id
    }

    var isAuthenticated: Bool {
        accessToken != nil && deviceId != nil
    }

    private func storageKey(_ key: KeychainKey) -> String {
        keyPrefix + key.rawValue
    }
}
