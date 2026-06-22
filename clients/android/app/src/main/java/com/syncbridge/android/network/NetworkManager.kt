package com.syncbridge.android.network

import android.content.Context
import android.content.SharedPreferences
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.DeviceEntry
import com.syncbridge.android.data.DiagnosticsResponse
import com.syncbridge.android.data.LocalPeer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

data class SignalPeerEvent(
    val deviceId: String,
    val addrs: List<String>,
    val port: Int,
    val at: String,
)

data class EnrichedPeer(
    val deviceId: String,
    val addrs: List<String>,
    val port: Int,
    val updatedAt: String,
    val name: String,
    val platform: String,
    val connectionType: TransferRoute,
)

data class TransferLogEntry(
    val id: String,
    val at: String,
    val name: String,
    val method: TransferRoute,
    val fallbackReason: String? = null,
    val bytesPerSec: Long? = null,
    val peerDeviceId: String? = null,
)

data class NetworkSnapshot(
    val diagnostics: DiagnosticsResponse? = null,
    val wsConnected: Boolean = false,
    val peers: List<LocalPeer> = emptyList(),
    val devices: List<DeviceEntry> = emptyList(),
    val enrichedPeers: List<EnrichedPeer> = emptyList(),
    val lastSignalTime: String? = null,
    val nearbyAlert: SignalPeerEvent? = null,
    val currentTransferMode: String = "Automatic",
    val lastSyncAt: String? = null,
    val latencyMs: Long? = null,
    val transferLogs: List<TransferLogEntry> = emptyList(),
    val loading: Boolean = false,
    val error: String? = null,
)

class NetworkManager(
    private val context: Context,
    private val api: ApiClient,
    private val prefs: SharedPreferences,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _state = MutableStateFlow(NetworkSnapshot())
    val state: StateFlow<NetworkSnapshot> = _state.asStateFlow()

    private var running = false
    private var clientIp = ""
    private val knownPeerIds = mutableSetOf<String>()

    fun start() {
        if (running) return
        running = true
        scope.launch { refreshLoop() }
        scope.launch { advertiseLoop() }
    }

    fun stop() {
        running = false
        knownPeerIds.clear()
        _state.value = NetworkSnapshot()
    }

    fun setWsConnected(connected: Boolean) {
        _state.update {
            it.copy(
                wsConnected = connected,
                currentTransferMode = NetworkPreferences.systemTransferLabel(connected),
            )
        }
    }

    fun markSync() {
        _state.update { it.copy(lastSyncAt = java.time.Instant.now().toString()) }
    }

    fun dismissNearbyAlert() {
        _state.update { it.copy(nearbyAlert = null) }
    }

    suspend fun refreshOncePublic() {
        refreshOnce()
    }

    /** @return true the first time we see this peer (for optional toast). */
    fun handleSignalPeer(deviceId: String, addrs: List<String>, port: Int): Boolean {
        val isNew = !knownPeerIds.contains(deviceId)
        if (isNew) knownPeerIds.add(deviceId)
        val event = SignalPeerEvent(
            deviceId = deviceId,
            addrs = addrs,
            port = port,
            at = java.time.Instant.now().toString(),
        )
        _state.update {
            it.copy(
                lastSignalTime = event.at,
                nearbyAlert = if (isNew) event else it.nearbyAlert,
            )
        }
        return isNew
    }

    fun resolveUploadRoute(
        fileSizeBytes: Long,
        fileCount: Int = 1,
        isFolder: Boolean = false,
    ): UploadRoute {
        val r = FileRouting.resolve(fileSizeBytes, fileCount, isFolder)
        return UploadRoute(r.transferMode, r.route, r.fallbackReason)
    }

    fun logTransfer(
        name: String,
        method: TransferRoute,
        fallbackReason: String? = null,
        bytesPerSec: Long? = null,
        peerDeviceId: String? = null,
    ) {
        val entry = TransferLogEntry(
            id = java.util.UUID.randomUUID().toString(),
            at = java.time.Instant.now().toString(),
            name = name,
            method = method,
            fallbackReason = fallbackReason,
            bytesPerSec = bytesPerSec,
            peerDeviceId = peerDeviceId,
        )
        _state.update { it.copy(transferLogs = (listOf(entry) + it.transferLogs).take(50)) }
    }

    private suspend fun refreshLoop() {
        while (scope.isActive && running) {
            refreshOnce()
            delay(15_000)
        }
    }

    private suspend fun advertiseLoop() {
        while (scope.isActive && running) {
            delay(60_000)
            if (!running) return
            advertiseOnce()
        }
    }

    private suspend fun refreshOnce() {
        _state.update { it.copy(loading = true, error = null) }
        val t0 = System.currentTimeMillis()
        try {
            val diagnostics = api.fetchDiagnostics()
            clientIp = diagnostics.clientIp
            advertiseOnce()
            val localAddrs = LanAddressHelper.localIpv4Addresses()
            val addrsQuery = (localAddrs + listOfNotNull(diagnostics.clientIp.takeIf { it.isNotBlank() }))
                .distinct().joinToString(",")
            val peerData = api.fetchLocalPeers(addrsQuery)
            val deviceData = runCatching { api.fetchDevices() }.getOrDefault(emptyList())
            val peers = peerData
            val enriched = enrichPeers(peers, deviceData)
            val latencyMs = System.currentTimeMillis() - t0
            _state.update {
                it.copy(
                    diagnostics = diagnostics,
                    peers = peers,
                    devices = deviceData,
                    enrichedPeers = enriched,
                    latencyMs = latencyMs,
                    loading = false,
                    currentTransferMode = NetworkPreferences.systemTransferLabel(it.wsConnected),
                )
            }
        } catch (e: Exception) {
            _state.update {
                it.copy(loading = false, error = e.message ?: "Network refresh failed")
            }
        }
    }

    private suspend fun advertiseOnce() {
        val addrs = LanAddressHelper.localIpv4Addresses()
        if (addrs.isNotEmpty()) {
            runCatching { api.advertiseLocalAddrs(addrs) }
        }
    }

    private fun enrichPeers(peers: List<LocalPeer>, devices: List<DeviceEntry>): List<EnrichedPeer> {
        val byId = devices.associateBy { it.id }
        return peers.map { p ->
            val dev = byId[p.deviceId]
            EnrichedPeer(
                deviceId = p.deviceId,
                addrs = p.addrs,
                port = p.port,
                updatedAt = p.updatedAt,
                name = dev?.name ?: "${p.deviceId.take(8)}…",
                platform = dev?.platform ?: "unknown",
                connectionType = TransferRoute.DirectLan,
            )
        }
    }

    data class UploadRoute(
        val transferMode: String,
        val route: TransferRoute,
        val fallbackReason: String? = null,
        val peerDeviceId: String? = null,
    )

    companion object {
        fun platformLabel(platform: String): String = when (platform) {
            "macos" -> "Mac"
            "android" -> "Android"
            "ios" -> "iPhone"
            "web" -> "Web"
            else -> platform
        }
    }
}
