package com.syncbridge.android.network

enum class TransferRoute(val emoji: String, val label: String) {
    Cloud("☁", "Cloud Relay"),
    DirectLan("⚡", "Direct LAN"),
    WebRtc("🌐", "WebRTC"),
    ;

    companion object {
        fun fromTransferMode(mode: String?): TransferRoute = when (mode) {
            "webrtc" -> WebRtc
            "direct_lan" -> DirectLan
            else -> Cloud
        }
    }
}

object NetworkPreferences {
    fun systemTransferLabel(wsConnected: Boolean): String =
        if (!wsConnected) "Offline" else "Automatic"
}
