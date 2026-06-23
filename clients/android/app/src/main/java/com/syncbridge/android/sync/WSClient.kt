package com.syncbridge.android.sync

import android.util.Log
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.network.NetworkManager
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
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
    private var reconnectJob: Job? = null
    @Volatile private var running = false
    @Volatile private var replacingSocket = false

    private var reconnectStep = 0
    private val reconnectSteps = longArrayOf(1000, 2000, 5000, 10000)

    private val client = OkHttpClient.Builder()
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    fun connect() {
        if (running) return
        running = true
        openSocket()
    }

    private fun openSocket() {
        val token = api.accessToken ?: return
        replacingSocket = true
        socket?.close(1000, "reconnect")
        socket = null
        replacingSocket = false

        val base = api.serverUrl.trimEnd('/')
        val wsBase = base.replace("https://", "wss://").replace("http://", "ws://")
        val request = Request.Builder().url("$wsBase/ws?token=$token").build()
        socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                reconnectJob?.cancel()
                reconnectJob = null
                reconnectStep = 0
                setLive(true)
                Log.d(TAG, "websocket open")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    val json = JSONObject(text)
                    when (json.optString("type")) {
                        "clipboard.new" -> {
                            val payload = json.getJSONObject("payload")
                            val entry = ClipboardEntry(
                                id = payload.getString("entry_id"),
                                contentType = payload.optString("content_type", "text/plain"),
                                content = payload.optString("content", ""),
                                sourceDeviceId = payload.optString("source_device_id", ""),
                                pinned = payload.optBoolean("pinned", false),
                                createdAt = payload.optString("created_at", ""),
                                hasThumbnail = payload.optBoolean("has_thumbnail", false)
                                    || payload.optString("content_type", "").startsWith("image/"),
                            )
                            onClipboardNew(entry)
                            networkManager?.markSync()
                        }
                        "clipboard.pin" -> {
                            val payload = json.optJSONObject("payload") ?: return
                            SyncEventBus.emitClipboardPin(
                                payload.optString("entry_id", ""),
                                payload.optBoolean("pinned", false),
                            )
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
                if (replacingSocket) return
                Log.d(TAG, "websocket closed code=$code reason=$reason")
                handleDisconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                if (replacingSocket) return
                Log.w(TAG, "websocket failure: ${t.message}")
                handleDisconnect()
            }
        })
    }

    private fun handleDisconnect() {
        setLive(false)
        scheduleReconnect()
    }

    private fun setLive(live: Boolean) {
        SyncEventBus.setConnected(live)
        networkManager?.setWsConnected(live)
    }

    private fun scheduleReconnect() {
        if (!running || reconnectJob?.isActive == true) return
        reconnectJob = scope.launch {
            while (running && !SyncEventBus.connected.value) {
                val delay = reconnectSteps[reconnectStep.coerceAtMost(reconnectSteps.lastIndex)]
                reconnectStep = (reconnectStep + 1).coerceAtMost(reconnectSteps.lastIndex)
                delay(delay)
                if (!running) return@launch
                openSocket()
                delay(2500)
                if (SyncEventBus.connected.value) return@launch
            }
        }
    }

    fun disconnect() {
        running = false
        reconnectStep = 0
        reconnectJob?.cancel()
        reconnectJob = null
        replacingSocket = true
        socket?.close(1000, "stop")
        socket = null
        replacingSocket = false
        setLive(false)
    }

    companion object {
        private const val TAG = "SyncBridgeWS"
    }
}
