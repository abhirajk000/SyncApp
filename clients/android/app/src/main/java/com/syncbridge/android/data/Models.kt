package com.syncbridge.android.data

data class ClipboardEntry(
    val id: String,
    val contentType: String,
    val content: String,
    val sourceDeviceId: String,
    val pinned: Boolean,
    val createdAt: String,
    val hasThumbnail: Boolean = false,
)

data class FileEntry(
    val id: String,
    val name: String,
    val mimeType: String,
    val totalSize: Long,
    val status: String,
    val isPinned: Boolean,
    val createdAt: String,
    val transferMode: String = "relay",
)

data class DiagnosticsResponse(
    val serverVersion: String,
    val clientIp: String,
    val localPeers: Int,
    val mdnsEnabled: Boolean,
    val turnEnabled: Boolean,
)

data class LocalPeer(
    val deviceId: String,
    val addrs: List<String>,
    val port: Int,
    val updatedAt: String,
)

data class DeviceEntry(
    val id: String,
    val name: String,
    val platform: String,
    val lastSeenAt: String?,
    val isCurrent: Boolean,
    val createdAt: String,
    val online: Boolean = false,
    val trustedUntil: String? = null,
)

data class AuthResult(
    val accessToken: String,
    val refreshToken: String,
    val userId: String,
    val deviceId: String,
    val trustedUntil: String,
)

data class AuthStatus(
    val deviceId: String,
    val trustedUntil: String?,
    val needsPin: Boolean,
)

data class FileInitResponse(
    val fileId: String,
    val chunkSize: Int,
    val chunkCount: Int,
)

class ApiException(message: String) : Exception(message)
