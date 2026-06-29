package com.syncbridge.android.data

import android.content.SharedPreferences
import com.syncbridge.android.BuildConfig
import android.util.Base64
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

class ApiClient(private val prefs: SharedPreferences) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .build()

    private val jsonMedia = "application/json; charset=utf-8".toMediaType()

    val serverUrl: String
        get() = BuildConfig.DEFAULT_API_URL

    val accessToken: String?
        get() = prefs.getString(KEY_ACCESS_TOKEN, null)

    val isAuthenticated: Boolean
        get() = accessToken != null

    fun ensureDeviceId(): String {
        val existing = prefs.getString(KEY_DEVICE_ID, null)
        if (existing != null) return existing
        val id = UUID.randomUUID().toString()
        prefs.edit().putString(KEY_DEVICE_ID, id).apply()
        return id
    }

    fun logout() {
        prefs.edit()
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .apply()
    }

    suspend fun unlock(pin: String, deviceName: String = "Android Device"): AuthResult =
        withContext(Dispatchers.IO) {
            val body = JSONObject().apply {
                put("pin", pin)
                put("device_id", ensureDeviceId())
                put("device_name", deviceName)
                put("platform", "android")
            }
            val json = post("/api/v1/auth/unlock", body, auth = false)
            val result = AuthResult(
                accessToken = json.getString("access_token"),
                refreshToken = json.getString("refresh_token"),
                userId = json.getString("user_id"),
                deviceId = json.getString("device_id"),
                trustedUntil = json.getString("trusted_until"),
            )
            prefs.edit()
                .putString(KEY_ACCESS_TOKEN, result.accessToken)
                .putString(KEY_REFRESH_TOKEN, result.refreshToken)
                .apply()
            result
        }

    suspend fun fetchAuthStatus(): AuthStatus = withContext(Dispatchers.IO) {
        val json = get("/api/v1/auth/status")
        AuthStatus(
            deviceId = json.getString("device_id"),
            trustedUntil = json.optString("trusted_until", null),
            needsPin = json.getBoolean("needs_pin"),
        )
    }

    suspend fun syncClipboard(content: String, contentType: String = "text/plain"): ClipboardEntry =
        withContext(Dispatchers.IO) {
            val body = JSONObject().apply {
                put("content_type", contentType)
                put("content", content)
            }
            parseClipboardEntry(post("/api/v1/clipboard", body))
        }

    suspend fun fetchClipboardEntry(id: String): ClipboardEntry =
        withContext(Dispatchers.IO) {
            parseClipboardEntry(get("/api/v1/clipboard/$id"))
        }

    suspend fun fetchClipboardHistory(limit: Int = 100): List<ClipboardEntry> =
        withContext(Dispatchers.IO) {
            val json = get("/api/v1/clipboard?limit=$limit")
            val entries = json.getJSONArray("entries")
            (0 until entries.length()).map { parseClipboardEntry(entries.getJSONObject(it)) }
        }

    suspend fun fetchCurrentClipboard(): ClipboardEntry =
        withContext(Dispatchers.IO) {
            parseClipboardEntry(get("/api/v1/clipboard/current"))
        }

    suspend fun pinClipboard(id: String, pinned: Boolean) = withContext(Dispatchers.IO) {
        postEmpty("/api/v1/clipboard/$id/pin", JSONObject().put("pinned", pinned))
    }

    suspend fun deleteClipboard(id: String) = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${baseUrl()}/api/v1/clipboard/$id")
            .delete()
            .header("Authorization", "Bearer ${accessToken!!}")
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                val text = response.body?.string().orEmpty()
                throw ApiException(text.ifBlank { "HTTP ${response.code}" })
            }
        }
    }

    suspend fun listFiles(limit: Int = 100): List<FileEntry> = withContext(Dispatchers.IO) {
        val json = get("/api/v1/files?limit=$limit")
        val files = json.getJSONArray("files")
        (0 until files.length()).map { parseFileEntry(files.getJSONObject(it)) }
    }

    suspend fun pinFile(id: String, pinned: Boolean) = withContext(Dispatchers.IO) {
        postEmpty("/api/v1/files/$id/pin", JSONObject().put("pinned", pinned))
    }

    suspend fun deleteFile(id: String) = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${baseUrl()}/api/v1/files/$id")
            .delete()
            .header("Authorization", "Bearer ${accessToken!!}")
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                val text = response.body?.string().orEmpty()
                throw ApiException(text.ifBlank { "HTTP ${response.code}" })
            }
        }
    }

    suspend fun initFileUpload(
        name: String,
        mimeType: String,
        totalSize: Long,
        fileHash: String,
        chunkSize: Int = CHUNK_SIZE,
        transferMode: String = "relay",
    ): FileInitResponse = withContext(Dispatchers.IO) {
        val body = JSONObject().apply {
            put("name", name)
            put("mime_type", mimeType)
            put("total_size", totalSize)
            put("chunk_size", chunkSize)
            put("file_hash", fileHash)
            put("transfer_mode", transferMode)
            put("force_relay", false)
        }
        val json = post("/api/v1/files/init", body)
        FileInitResponse(
            fileId = json.getString("file_id"),
            chunkSize = json.getInt("chunk_size"),
            chunkCount = json.getInt("chunk_count"),
        )
    }

    suspend fun uploadChunk(fileId: String, index: Int, data: ByteArray, chunkHash: String) =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("${baseUrl()}/api/v1/files/$fileId/chunks/$index")
                .put(data.toRequestBody("application/octet-stream".toMediaType()))
                .header("Authorization", "Bearer ${accessToken!!}")
                .header("X-Chunk-Hash", chunkHash)
                .build()
            execute(request)
        }

    suspend fun completeFileUpload(fileId: String): FileEntry = withContext(Dispatchers.IO) {
        parseFileEntry(post("/api/v1/files/$fileId/complete", JSONObject()))
    }

    suspend fun downloadFileBytes(fileId: String): ByteArray =
        downloadBytes("/api/v1/files/$fileId/download")

    suspend fun downloadThumbnailBytes(fileId: String): ByteArray? = withContext(Dispatchers.IO) {
        try {
            downloadBytes("/api/v1/files/$fileId/thumbnail")
        } catch (_: Exception) {
            null
        }
    }

    suspend fun downloadClipboardThumbnailBytes(clipboardId: String): ByteArray? =
        withContext(Dispatchers.IO) {
            try {
                downloadBytes("/api/v1/clipboard/$clipboardId/thumbnail")
            } catch (_: Exception) {
                null
            }
        }

    private suspend fun downloadBytes(path: String): ByteArray = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${baseUrl()}$path")
            .header("Authorization", "Bearer ${accessToken!!}")
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw ApiException("HTTP ${response.code}")
            }
            response.body?.bytes() ?: throw ApiException("Empty response")
        }
    }

    private fun baseUrl(): String = serverUrl.trimEnd('/')

    private fun get(path: String): JSONObject {
        val request = Request.Builder()
            .url("${baseUrl()}$path")
            .header("Authorization", "Bearer ${accessToken!!}")
            .get()
            .build()
        return JSONObject(execute(request))
    }

    private fun post(path: String, body: JSONObject, auth: Boolean = true): JSONObject {
        val builder = Request.Builder()
            .url("${baseUrl()}$path")
            .post(body.toString().toRequestBody(jsonMedia))
        if (auth) {
            builder.header("Authorization", "Bearer ${accessToken!!}")
        }
        return JSONObject(execute(builder.build()))
    }

    private fun patch(path: String, body: JSONObject): JSONObject {
        val builder = Request.Builder()
            .url("${baseUrl()}$path")
            .patch(body.toString().toRequestBody(jsonMedia))
            .header("Authorization", "Bearer ${accessToken!!}")
        return JSONObject(execute(builder.build()))
    }

    private fun execute(request: Request): String {
        client.newCall(request).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                val message = try {
                    if (text.isNotBlank()) JSONObject(text).optString("error", response.message) else response.message
                } catch (_: Exception) {
                    response.message
                }
                if (response.code == 401) logout()
                throw ApiException(message.ifBlank { "HTTP ${response.code}" })
            }
            return text.ifBlank { "{}" }
        }
    }

    private fun postEmpty(path: String, body: JSONObject) {
        val builder = Request.Builder()
            .url("${baseUrl()}$path")
            .post(body.toString().toRequestBody(jsonMedia))
            .header("Authorization", "Bearer ${accessToken!!}")
        client.newCall(builder.build()).execute().use { response ->
            if (!response.isSuccessful) {
                val text = response.body?.string().orEmpty()
                throw ApiException(text.ifBlank { "HTTP ${response.code}" })
            }
        }
    }

    private fun parseClipboardEntry(json: JSONObject) = ClipboardEntry(
        id = json.getString("id"),
        contentType = json.optString("content_type", "text/plain"),
        content = json.optString("content", ""),
        sourceDeviceId = json.optString("source_device_id", ""),
        pinned = json.optBoolean("pinned", false),
        createdAt = json.optString("created_at", ""),
        hasThumbnail = json.optBoolean("has_thumbnail", false)
            || json.optString("content_type", "").startsWith("image/"),
    )

    private fun parseFileEntry(json: JSONObject) = FileEntry(
        id = json.getString("id"),
        name = json.getString("name"),
        mimeType = json.optString("mime_type", "application/octet-stream"),
        totalSize = json.optLong("total_size", 0),
        status = json.optString("status", "unknown"),
        isPinned = json.optBoolean("is_pinned", false),
        createdAt = json.optString("created_at", ""),
        transferMode = json.optString("transfer_mode", "relay"),
    )

    suspend fun fetchDiagnostics(): DiagnosticsResponse = withContext(Dispatchers.IO) {
        val json = get("/api/v1/diagnostics")
        DiagnosticsResponse(
            serverVersion = json.optString("server_version", ""),
            clientIp = json.optString("client_ip", ""),
            localPeers = json.optInt("local_peers", 0),
            mdnsEnabled = json.optBoolean("mdns_enabled", false),
            turnEnabled = json.optBoolean("turn_enabled", false),
        )
    }

    suspend fun fetchLocalPeers(addrs: String = ""): List<LocalPeer> = withContext(Dispatchers.IO) {
        val path = if (addrs.isBlank()) "/api/v1/local/peers" else "/api/v1/local/peers?addrs=${java.net.URLEncoder.encode(addrs, "UTF-8")}"
        val json = get(path)
        val peers = json.optJSONArray("peers") ?: JSONArray()
        (0 until peers.length()).map { i ->
            val p = peers.getJSONObject(i)
            val addrsArr = p.optJSONArray("addrs") ?: JSONArray()
            LocalPeer(
                deviceId = p.optString("device_id", ""),
                addrs = (0 until addrsArr.length()).map { j -> addrsArr.getString(j) },
                port = p.optInt("port", 0),
                updatedAt = p.optString("updated_at", ""),
            )
        }
    }

    suspend fun advertiseLocalAddrs(addrs: List<String>, port: Int = 0) = withContext(Dispatchers.IO) {
        val body = JSONObject().apply {
            put("addrs", JSONArray(addrs))
            put("port", port)
        }
        postEmpty("/api/v1/local/advertise", body)
    }

    suspend fun fetchDevices(): List<DeviceEntry> = withContext(Dispatchers.IO) {
        val json = get("/api/v1/devices")
        val devices = json.optJSONArray("devices") ?: JSONArray()
        (0 until devices.length()).map { i ->
            val d = devices.getJSONObject(i)
            DeviceEntry(
                id = d.optString("id", ""),
                name = d.optString("name", ""),
                platform = d.optString("platform", "unknown"),
                lastSeenAt = d.optString("last_seen_at", null),
                isCurrent = d.optBoolean("is_current", false),
                createdAt = d.optString("created_at", ""),
                online = d.optBoolean("online", false),
                trustedUntil = d.optString("trusted_until", null),
            )
        }
    }

    suspend fun renameDevice(id: String, name: String): DeviceEntry = withContext(Dispatchers.IO) {
        val body = JSONObject().put("name", name)
        val d = patch("/api/v1/devices/$id", body)
        parseDeviceEntry(d)
    }

    suspend fun revokeDevice(id: String) = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("${baseUrl()}/api/v1/devices/$id")
            .delete()
            .header("Authorization", "Bearer ${accessToken!!}")
            .build()
        execute(request)
    }

    suspend fun trustDevice(id: String) = withContext(Dispatchers.IO) {
        postEmpty("/api/v1/devices/$id/trust", JSONObject())
    }

    suspend fun confirmPairing(otp: String, deviceName: String): AuthResult =
        withContext(Dispatchers.IO) {
            val keyBytes = ByteArray(32)
            java.security.SecureRandom().nextBytes(keyBytes)
            val publicKey = Base64.encodeToString(keyBytes, Base64.NO_WRAP)
            val body = JSONObject().apply {
                put("otp", otp)
                put("name", deviceName)
                put("platform", "android")
                put("public_key", publicKey)
            }
            val json = post("/api/v1/devices/pair/confirm", body, auth = false)
            val result = AuthResult(
                accessToken = json.getString("access_token"),
                refreshToken = json.getString("refresh_token"),
                userId = json.getString("user_id"),
                deviceId = json.getString("device_id"),
                trustedUntil = json.getString("trusted_until"),
            )
            prefs.edit()
                .putString(KEY_ACCESS_TOKEN, result.accessToken)
                .putString(KEY_REFRESH_TOKEN, result.refreshToken)
                .putString(KEY_DEVICE_ID, result.deviceId)
                .apply()
            result
        }

    private fun parseDeviceEntry(d: JSONObject) = DeviceEntry(
        id = d.optString("id", ""),
        name = d.optString("name", ""),
        platform = d.optString("platform", "unknown"),
        lastSeenAt = d.optString("last_seen_at", null),
        isCurrent = d.optBoolean("is_current", false),
        createdAt = d.optString("created_at", ""),
        online = d.optBoolean("online", false),
        trustedUntil = d.optString("trusted_until", null),
    )

    companion object {
        const val CHUNK_SIZE = 4 * 1024 * 1024
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
    }
}
