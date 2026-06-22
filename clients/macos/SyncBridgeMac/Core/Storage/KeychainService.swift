// KeychainService.swift
// Secure credential storage backed by the macOS Keychain.
//
// All items are stored in the app's own keychain group with
// kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly so they are available
// after login but never migrate to iCloud backup or other devices.

import Foundation
import Security

/// Keys used to identify items stored in the Keychain.
enum KeychainKey: String {
    case accessToken   = "com.syncbridge.accessToken"
    case refreshToken  = "com.syncbridge.refreshToken"
    case serverURL     = "com.syncbridge.serverURL"
    case userId        = "com.syncbridge.userId"
    case deviceId      = "com.syncbridge.deviceId"
    case deviceName    = "com.syncbridge.deviceName"
    case trustedUntil  = "com.syncbridge.trustedUntil"
}

/// Thread-safe keychain accessor.
final class KeychainService {
    static let shared = KeychainService()
    private init() {}

    // ── Write ─────────────────────────────────────────────────────────────────

    @discardableResult
    func set(_ value: String, for key: KeychainKey) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String:             kSecClassGenericPassword,
            kSecAttrAccount as String:       key.rawValue,
            kSecAttrAccessible as String:    kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:         data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // ── Read ──────────────────────────────────────────────────────────────────

    func get(_ key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    @discardableResult
    func delete(_ key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // ── Bulk operations ───────────────────────────────────────────────────────

    /// Removes all SyncBridge credentials from Keychain (on logout).
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
        get { get(.serverURL) ?? "http://localhost:8080" }
        set { set(newValue, for: .serverURL) }
    }

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
}
