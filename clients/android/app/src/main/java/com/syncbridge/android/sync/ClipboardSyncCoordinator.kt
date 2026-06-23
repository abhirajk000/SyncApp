package com.syncbridge.android.sync

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.security.MessageDigest

/**
 * Shared local clipboard + screenshot upload logic for the foreground service.
 *
 * In-app copies call [prepareLocalClipboardWrite] before writing and
 * [finishLocalClipboardWrite] after, so we never re-upload echoed content.
 */
class ClipboardSyncCoordinator(
    context: Context,
    private val api: ApiClient,
    val settings: ClipboardSettings,
) {
    private val appContext = context.applicationContext
    private val repo = ClipboardRepository(appContext, api)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var lastHash: String = ""

    @Volatile
    private var suppressEcho: Boolean = false

    @Volatile
    private var suppressUploadUntilMs: Long = 0L

    @Volatile
    private var isSyncing = false

    @Volatile
    private var lastLocalUserCopyAtMs: Long = 0L

    private var pendingReadRunnable: Runnable? = null
    private val suppressClearRunnable = Runnable {
        suppressEcho = false
    }

    fun onLocalClipboardChanged() {
        if (suppressEcho) return
        lastLocalUserCopyAtMs = System.currentTimeMillis()
        scheduleDebouncedClipboardRead()
    }

    /** Read clipboard after returning from another app (e.g. copied text in Messages/SMS). */
    fun syncExternalClipboardOnResume() {
        if (suppressEcho) return
        scheduleDebouncedClipboardRead(delayMs = 150)
    }

    /** Manual refresh — sync local clipboard if changed. */
    fun syncFromClipboardNow() {
        if (suppressEcho) return
        scheduleDebouncedClipboardRead()
    }

    fun onScreenshotUri(uri: Uri) {
        if (!settings.autoSyncImages || shouldSkipUpload()) return
        scope.launch {
            try {
                val image = repo.readImageFromUri(uri) ?: return@launch
                uploadIfNew(image.first, image.second)
            } catch (e: Exception) {
                Log.w(TAG, "screenshot sync failed", e)
            }
        }
    }

    fun applyRemoteClip(entry: ClipboardEntry) {
        beginSuppress(localCopy = false)
        rememberSyncedContent(entry.content, entry.contentType)
        repo.applyRemoteClip(entry)
        SyncEventBus.emitClipboard(
            entry.copy(
                hasThumbnail = entry.hasThumbnail || entry.contentType.startsWith("image/"),
            ),
        )
    }

    /** Whether incoming remote clipboard should be written to the system clipboard. */
    fun shouldAutoApplyRemote(entry: ClipboardEntry, forceCatchUp: Boolean = false): Boolean {
        if (!settings.autoApplyRemoteClipboard) return false
        val localId = api.ensureDeviceId()
        if (entry.sourceDeviceId == localId) return false
        if (!forceCatchUp && entry.sourceDeviceId.isBlank()) return false
        val hash = hashFor(entry.content, entry.contentType)
        if (!forceCatchUp && hash.isNotBlank() && hash == lastHash) return false
        if (!forceCatchUp && System.currentTimeMillis() - lastLocalUserCopyAtMs < LOCAL_COPY_GUARD_MS) return false
        if (entry.contentType.startsWith("image/") && !settings.autoSyncImages) return false
        return true
    }

    fun hashFor(content: String, contentType: String): String {
        if (content.isBlank()) return ""
        return hashContent(content)
    }

    /** Own-device WS echo — update hash without writing clipboard again. */
    fun rememberSyncedEntry(entry: ClipboardEntry) {
        rememberSyncedContent(entry.content, entry.contentType)
    }

    /** Lock dedupe hash from known text before/after an in-app copy. */
    fun lockTextHash(text: String) {
        if (text.isBlank()) return
        lastHash = hashContent(text)
    }

    /** Lock dedupe hash from raw image bytes (same encoding as upload). */
    fun lockImageBytesHash(bytes: ByteArray, mimeType: String?) {
        repo.fingerprintImageBytes(bytes, mimeType)?.let { lastHash = it }
    }

    /** Call before writing clipboard from in-app Copy action. */
    fun prepareLocalClipboardWrite() {
        beginSuppress(localCopy = true)
    }

    /** Call after writing clipboard from in-app Copy action. */
    fun finishLocalClipboardWrite() {
        recordClipboardHashAfterWrite()
    }

    /** Copy text/image entry from in-app UI. */
    fun applyLocalCopy(entry: ClipboardEntry) {
        prepareLocalClipboardWrite()
        if (entry.contentType.startsWith("image/")) {
            if (entry.content.isNotBlank()) {
                val bytes = Base64.decode(entry.content, Base64.DEFAULT)
                lockImageBytesHash(bytes, entry.contentType)
            }
        } else {
            lockTextHash(entry.content)
        }
        repo.applyRemoteClip(entry)
        finishLocalClipboardWrite()
    }

    private fun beginSuppress(localCopy: Boolean) {
        suppressEcho = true
        pendingReadRunnable?.let { mainHandler.removeCallbacks(it) }
        pendingReadRunnable = null
        mainHandler.removeCallbacks(suppressClearRunnable)
        val duration = if (localCopy) LOCAL_COPY_SUPPRESS_MS else REMOTE_COPY_SUPPRESS_MS
        val until = System.currentTimeMillis() + duration
        suppressUploadUntilMs = maxOf(suppressUploadUntilMs, until)
        mainHandler.postDelayed(suppressClearRunnable, duration)
    }

    private fun rememberSyncedContent(content: String, contentType: String) {
        if (contentType.startsWith("image/")) {
            if (content.isNotBlank()) lastHash = hashContent(content)
        } else if (content.isNotBlank()) {
            lastHash = hashContent(content)
        }
    }

    private fun recordClipboardHashAfterWrite() {
        val delays = longArrayOf(50, 200, 500, 1000)
        for (delay in delays) {
            mainHandler.postDelayed({
                if (System.currentTimeMillis() >= suppressUploadUntilMs) return@postDelayed
                repo.readPrimaryClip()?.let { (content, _) ->
                    lastHash = hashContent(content)
                    Log.d(TAG, "locked clipboard hash after local copy")
                }
            }, delay)
        }
    }

    private fun scheduleDebouncedClipboardRead(delayMs: Long = 400) {
        pendingReadRunnable?.let { mainHandler.removeCallbacks(it) }
        val runnable = Runnable {
            pendingReadRunnable = null
            if (suppressEcho) return@Runnable
            val clip = repo.readPrimaryClip() ?: return@Runnable
            uploadIfNew(clip.first, clip.second)
        }
        pendingReadRunnable = runnable
        mainHandler.postDelayed(runnable, delayMs)
    }

    private fun shouldSkipUpload(forHash: String? = null): Boolean {
        if (suppressEcho) return true
        // New clipboard content (e.g. SMS copy) should sync even during post-upload echo window.
        if (forHash != null && forHash != lastHash) return false
        if (System.currentTimeMillis() < suppressUploadUntilMs) return true
        return false
    }

    private fun uploadIfNew(content: String, contentType: String) {
        if (!settings.autoSyncClipboard) return
        if (contentType.startsWith("image/") && !settings.autoSyncImages) return
        val hash = hashContent(content)
        if (hash == lastHash) return
        if (shouldSkipUpload(forHash = hash)) return
        if (isSyncing) return
        isSyncing = true
        scope.launch {
            try {
                if (!api.isAuthenticated) return@launch
                if (shouldSkipUpload(forHash = hash)) return@launch
                if (hash == lastHash) return@launch
                Log.i(TAG, "uploading clipboard ($contentType, ${content.length} chars)")
                repo.syncClipboard(contentType, content)
                lastHash = hash
                suppressUploadUntilMs = System.currentTimeMillis() + POST_UPLOAD_SUPPRESS_MS
            } catch (e: Exception) {
                Log.w(TAG, "clipboard upload failed", e)
                SyncEventBus.emitSyncError(
                    (e as? com.syncbridge.android.data.ApiException)?.message
                        ?: e.message
                        ?: "Clipboard sync failed",
                )
            } finally {
                isSyncing = false
            }
        }
    }

    companion object {
        private const val TAG = "ClipboardSync"
        private const val LOCAL_COPY_SUPPRESS_MS = 20_000L
        private const val REMOTE_COPY_SUPPRESS_MS = 3_000L
        private const val POST_UPLOAD_SUPPRESS_MS = 5_000L
        private const val LOCAL_COPY_GUARD_MS = 4_000L

        fun hashContent(content: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
            val bytes = digest.digest(content.toByteArray(Charsets.UTF_8))
            return bytes.joinToString("") { "%02x".format(it) }
        }
    }
}
