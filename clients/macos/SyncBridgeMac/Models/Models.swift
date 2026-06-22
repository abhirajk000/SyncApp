// Models.swift
// Mirrors the SyncBridge API DTOs exactly.
// All types are Codable so they round-trip through JSONDecoder/JSONEncoder.

import Foundation

// ── Auth (PIN unlock) ────────────────────────────────────────────────────────

struct UnlockRequest: Encodable {
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

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let deviceId: String
    let trustedUntil: String
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
        case deviceId = "device_id"
        case trustedUntil = "trusted_until"
    }
}

struct AuthStatusResponse: Decodable {
    let deviceId: String
    let trustedUntil: String?
    let needsPin: Bool
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case trustedUntil = "trusted_until"
        case needsPin = "needs_pin"
    }
}

// ── Device ───────────────────────────────────────────────────────────────────

struct DeviceRegistrationRequest: Encodable {
    let name: String
    let platform: String   // "macos"
    let pushToken: String?
    enum CodingKeys: String, CodingKey {
        case name, platform, pushToken = "push_token"
    }
}

struct DeviceResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let platform: String
    let trusted: Bool
    let lastSeenAt: String?
    enum CodingKeys: String, CodingKey {
        case id, name, platform, trusted, lastSeenAt = "last_seen_at"
    }
}

struct DeviceListResponse: Decodable {
    let devices: [DeviceResponse]
    let total: Int
}

// ── Pairing ───────────────────────────────────────────────────────────────────

struct PairingInitResponse: Decodable {
    let pairingId: String
    let otp: String
    let userId: String
    let expiresAt: String
    let qrPayload: String
    enum CodingKeys: String, CodingKey {
        case pairingId = "pairing_id"
        case otp
        case userId = "user_id"
        case expiresAt = "expires_at"
        case qrPayload = "qr_payload"
    }
}

struct PairingConfirmRequest: Encodable {
    let otp: String
    let name: String
    let platform: String
    let publicKey: String
    enum CodingKeys: String, CodingKey {
        case otp, name, platform
        case publicKey = "public_key"
    }
}

// ── Clipboard ─────────────────────────────────────────────────────────────────

struct ClipboardSyncRequest: Encodable {
    let contentType: String
    let content: String
    let sourceDeviceId: String
    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case content
        case sourceDeviceId = "source_device_id"
    }
}

struct ClipboardEntryResponse: Decodable, Identifiable {
    let id: String
    let contentType: String
    let content: String
    let sourceDeviceId: String
    let createdAt: String
    let pinned: Bool
    let expiresAt: String?
    enum CodingKeys: String, CodingKey {
        case id, content, pinned
        case contentType = "content_type"
        case sourceDeviceId = "source_device_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

struct PinRequest: Encodable {
    let pinned: Bool
}

struct ClipboardHistoryResponse: Decodable {
    let entries: [ClipboardEntryResponse]
    let total: Int
    let limit: Int
    let offset: Int
}

// ── File ─────────────────────────────────────────────────────────────────────

struct FileInitRequest: Encodable {
    let name: String
    let mimeType: String
    let totalSize: Int64
    let chunkSize: Int
    let fileHash: String
    let transferMode: String
    let forceRelay: Bool
    enum CodingKeys: String, CodingKey {
        case name
        case mimeType = "mime_type"
        case totalSize = "total_size"
        case chunkSize = "chunk_size"
        case fileHash = "file_hash"
        case transferMode = "transfer_mode"
        case forceRelay = "force_relay"
    }
}

struct FileInitResponse: Decodable {
    let fileId: String
    let chunkSize: Int
    let chunkCount: Int
    let expiresAt: String?
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case chunkSize = "chunk_size"
        case chunkCount = "chunk_count"
        case expiresAt = "expires_at"
    }
}

struct FileStatusResponse: Decodable {
    let fileId: String
    let status: String
    let chunkCount: Int
    let chunksReceived: Int
    let missingChunks: [Int]
    let progressPercent: Int
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case status
        case chunkCount = "chunk_count"
        case chunksReceived = "chunks_received"
        case missingChunks = "missing_chunks"
        case progressPercent = "progress_percent"
    }
}

struct FileResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let mimeType: String
    let totalSize: Int64
    let status: String
    let hasThumbnail: Bool
    let transferMode: String
    let senderDeviceId: String
    let createdAt: String
    let isPinned: Bool
    let expiresAt: String?
    enum CodingKeys: String, CodingKey {
        case id, name, status
        case mimeType = "mime_type"
        case totalSize = "total_size"
        case hasThumbnail = "has_thumbnail"
        case transferMode = "transfer_mode"
        case senderDeviceId = "sender_device_id"
        case createdAt = "created_at"
        case isPinned = "is_pinned"
        case expiresAt = "expires_at"
    }
}

struct FileListResponse: Decodable {
    let files: [FileResponse]
    let total: Int
}

// ── WebSocket envelopes ───────────────────────────────────────────────────────

struct WSEnvelope: Codable {
    let id: String
    let type: String
    let payload: AnyCodable?
}

/// Thin container for arbitrary JSON payloads.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode([String: AnyCodable].self) {
            value = d.mapValues { $0.value }
        } else if let a = try? container.decode([AnyCodable].self) {
            value = a.map { $0.value }
        } else if let s = try? container.decode(String.self) {
            value = s
        } else if let n = try? container.decode(Double.self) {
            value = n
        } else if let b = try? container.decode(Bool.self) {
            value = b
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let d as [String: Any]:
            try container.encode(d.mapValues { AnyCodable($0) })
        case let a as [Any]:
            try container.encode(a.map { AnyCodable($0) })
        case let s as String:
            try container.encode(s)
        case let n as Double:
            try container.encode(n)
        case let b as Bool:
            try container.encode(b)
        default:
            try container.encodeNil()
        }
    }
}

// ── Local domain models ───────────────────────────────────────────────────────

/// Current authentication state of the app.
enum AuthState: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn(userId: String, deviceId: String)
}

/// Connectivity status shown in the menu bar icon.
enum SyncStatus {
    case disconnected
    case connecting
    case connected
    case syncing
    case error(String)

    var symbolName: String {
        switch self {
        case .disconnected: return "arrow.triangle.2.circlepath"
        case .connecting:   return "arrow.clockwise"
        case .connected:    return "checkmark.circle"
        case .syncing:      return "arrow.up.arrow.down.circle"
        case .error:        return "exclamationmark.circle"
        }
    }
}

/// Represents one in-progress or completed file transfer in the local UI.
struct TransferItem: Identifiable {
    let id: String           // file_id
    let name: String
    let totalSize: Int64
    var progress: Double     // 0–1
    var status: TransferStatus

    enum TransferStatus {
        case uploading, downloading, ready, failed
    }
}

/// API error envelope.
struct APIError: Decodable, Error {
    let error: String
    let requestId: String?
    enum CodingKeys: String, CodingKey {
        case error, requestId = "request_id"
    }
}

struct EmptyResponse: Decodable {}

// ── Network / diagnostics ─────────────────────────────────────────────────────

struct DiagnosticsResponse: Decodable {
    let serverVersion: String
    let clientIp: String
    let localPeers: Int
    let mdnsEnabled: Bool
    let turnEnabled: Bool
    enum CodingKeys: String, CodingKey {
        case serverVersion = "server_version"
        case clientIp = "client_ip"
        case localPeers = "local_peers"
        case mdnsEnabled = "mdns_enabled"
        case turnEnabled = "turn_enabled"
    }
}

struct LocalPeerResponse: Decodable, Identifiable {
    let deviceId: String
    let addrs: [String]
    let port: Int
    let updatedAt: String
    var id: String { deviceId }
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case addrs, port
        case updatedAt = "updated_at"
    }
}

struct LocalPeersResponse: Decodable {
    let peers: [LocalPeerResponse]
}

struct AdvertiseRequest: Encodable {
    let addrs: [String]
    let port: Int
}
