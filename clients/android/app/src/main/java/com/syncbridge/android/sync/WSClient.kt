package com.syncbridge.android.sync

import android.util.Log
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.network.NetworkManager
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject

class WSClient(
    private val api: ApiClient,
    private val networkManager: NetworkManager? = null,
    private val onClipboardNew: (ClipboardEntry) -> Unit,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var socket: WebSocket? = null
    @Volatile private var running = false

    private val client = OkHttpClient.Builder()
        .pingInterval(54, TimeUnit.SECONDS)
        .build()

    fun connect() {
        if (running) return
        running = true
        openSocket()
    }

    private fun openSocket() {
        val token = api.accessToken ?: return
        socket?.close(1000, "reconnect")
        val base = api.serverUrl.trimEnd('/')
        val wsBase = base.replace("https://", "wss://").replace("http://", "ws://")
        val request = Request.Builder().url("$wsBase/ws?token=$token").build()
        socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                SyncEventBus.setConnected(true)
                networkManager?.setWsConnected(true)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    val json = JSONObject(text)
                    when (json.optString("type")) {
                        "clipboard.new" -> {
                            val payload = json.getJSONObject("payload")
                            onClipboardNew(
                                ClipboardEntry(
                                    id = payload.getString("entry_id"),
                                    contentType = payload.optString("content_type", "text/plain"),
                                    content = payload.getString("content"),
                                    sourceDeviceId = payload.optString("source_device_id", ""),
                                    pinned = payload.optBoolean("pinned", false),
                                    createdAt = payload.optString("created_at", ""),
                                ),
                            )
                            networkManager?.markSync()
                        }
                        "signal.peer" -> {
                            val payload = json.optJSONObject("payload") ?: return
                            val deviceId = payload.optString("device_id", "")
                            if (deviceId.isBlank()) return
                            val addrsArr = payload.optJSONArray("addrs") ?: org.json.JSONArray()
                            val addrs = (0 until addrsArr.length()).map { addrsArr.getString(it) }
                            val port = payload.optInt("port", 0)
                            if (networkManager?.handleSignalPeer(deviceId, addrs, port) == true) {
                                SyncEventBus.emitNearbyAlert(deviceId)
                            }
                        }
                        "file.ready", "file.progress" -> {
                            networkManager?.markSync()
                            if (json.optString("type") == "file.ready") {
                                SyncEventBus.emitFilesUpdated()
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "ws parse: ${e.message}")
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                SyncEventBus.setConnected(false)
                networkManager?.setWsConnected(false)
                scheduleReconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                SyncEventBus.setConnected(false)
                networkManager?.setWsConnected(false)
                scheduleReconnect()
            }
        })
    }

    private fun scheduleReconnect() {
        if (!running) return
        scope.launch {
            var backoff = 1000L
            while (running && !SyncEventBus.connected.value) {
                delay(backoff)
                if (!running) return@launch
                openSocket()
                delay(3000)
                if (SyncEventBus.connected.value) return@launch
                backoff = minOf(backoff * 2, 60_000L)
            }
        }
    }

    fun disconnect() {
        running = false
        socket?.close(1000, "stop")
        socket = null
        SyncEventBus.setConnected(false)
    }

    companion object {
        private const val TAG = "SyncBridgeWS"
    }
}
