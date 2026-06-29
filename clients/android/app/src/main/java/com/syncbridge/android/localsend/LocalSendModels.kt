package com.syncbridge.android.localsend

data class LocalPeer(
    val id: String,
    val name: String,
    val platform: String,
    val host: String,
    val port: Int,
)

enum class LocalTransferPhase {
    Idle,
    Connecting,
    WaitingAccept,
    Transferring,
    Paused,
    Completed,
    Failed,
}

data class LocalTransferProgress(
    val transferId: String,
    val peerName: String,
    val direction: LocalTransferDirection,
    val phase: LocalTransferPhase,
    val files: List<LocalFileProgress>,
    val speedBytesPerSec: Long = 0,
    val error: String? = null,
)

enum class LocalTransferDirection { Sending, Receiving }

data class LocalFileProgress(
    val index: Int,
    val name: String,
    val size: Long,
    val transferred: Long,
) {
    val percent: Float
        get() = if (size <= 0) 0f else (transferred.toFloat() / size.toFloat()).coerceIn(0f, 1f)

    val remaining: Long get() = (size - transferred).coerceAtLeast(0)
}

data class IncomingOffer(
    val offer: LocalSendProtocol.Offer,
    val peer: LocalPeer,
)
