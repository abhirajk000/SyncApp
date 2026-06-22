package com.syncbridge.android.auth

import android.content.Context
import android.content.SharedPreferences
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import org.json.JSONObject

/**
 * PIN unlock against SyncBridge API — mirrors macOS AuthService pattern.
 *
 * Default server: http://localhost:8080
 * Platform: "android"
 */
class AuthRepository(private val context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("syncbridge", Context.MODE_PRIVATE)

    companion object {
        const val DEFAULT_SERVER_URL = "http://localhost:8080"
        private const val KEY_SERVER_URL = "server_url"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
    }

    var serverUrl: String
        get() = prefs.getString(KEY_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL
        set(value) = prefs.edit().putString(KEY_SERVER_URL, value).apply()

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

    /**
     * POST /api/v1/auth/unlock
     * @throws AuthException on invalid PIN or network error
     */
    fun unlock(pin: String, deviceName: String = "Android Device"): AuthResult {
        val base = serverUrl.trimEnd('/')
        val url = URL("$base/api/v1/auth/unlock")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            setRequestProperty("Content-Type", "application/json")
            doOutput = true
        }

        val body = JSONObject().apply {
            put("pin", pin)
            put("device_id", ensureDeviceId())
            put("device_name", deviceName)
            put("platform", "android")
        }

        conn.outputStream.use { it.write(body.toString().toByteArray()) }

        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val responseText = stream?.bufferedReader()?.use { it.readText() } ?: ""

        if (code !in 200..299) {
            val message = try {
                JSONObject(responseText).optString("error", "unlock failed")
            } catch (_: Exception) {
                "unlock failed ($code)"
            }
            throw AuthException(message)
        }

        val json = JSONObject(responseText)
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

        return result
    }

    fun logout() {
        prefs.edit()
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .apply()
    }

    data class AuthResult(
        val accessToken: String,
        val refreshToken: String,
        val userId: String,
        val deviceId: String,
        val trustedUntil: String,
    )

    class AuthException(message: String) : Exception(message)
}
