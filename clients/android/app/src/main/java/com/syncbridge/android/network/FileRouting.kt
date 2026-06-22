package com.syncbridge.android.network

/** Automatic file routing — clipboard always uses relay separately. */
object FileRouting {
    const val RELAY_MAX_BYTES = 100L * 1024 * 1024

    data class Route(
        val transferMode: String,
        val route: TransferRoute,
        val fallbackReason: String? = null,
    )

    fun resolve(
        fileSizeBytes: Long,
        fileCount: Int = 1,
        isFolder: Boolean = false,
    ): Route {
        val attemptWebRtc = fileSizeBytes > RELAY_MAX_BYTES || fileCount > 1 || isFolder
        if (!attemptWebRtc) {
            return Route("relay", TransferRoute.Cloud)
        }
        return Route(
            transferMode = "webrtc",
            route = TransferRoute.WebRtc,
            fallbackReason = "WebRTC attempted — automatic relay fallback if P2P unavailable",
        )
    }
}
