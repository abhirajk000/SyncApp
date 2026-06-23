package com.syncbridge.android.sync

import android.content.ContentUris
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Watches MediaStore for new screenshots. Android 10+ blocks clipboard reads while the app
 * is in the background, so screenshots are picked up here instead.
 */
class ScreenshotWatcher(
    private val context: Context,
    private val onScreenshot: (Uri) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private var observer: ContentObserver? = null
    private var lastSeenAddedAt: Long = 0L
    private var lastSeenId: Long = 0L
    private val checking = AtomicBoolean(false)

    fun start() {
        primeLatest()
        if (observer != null) return
        observer = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                scheduleChecks()
            }
        }
        val uris = listOf(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
        )
        for (uri in uris) {
            context.contentResolver.registerContentObserver(uri, true, observer!!)
        }
        Log.i(TAG, "started (last screenshot id=$lastSeenId addedAt=$lastSeenAddedAt)")
    }

    fun stop() {
        observer?.let { context.contentResolver.unregisterContentObserver(it) }
        observer = null
        handler.removeCallbacksAndMessages(null)
    }

    private fun primeLatest() {
        val row = queryLatest() ?: return
        lastSeenId = row.id
        lastSeenAddedAt = row.addedAt
    }

    private fun scheduleChecks() {
        val delays = longArrayOf(0, 350, 900, 2000)
        for (delay in delays) {
            handler.postDelayed({ checkLatest() }, delay)
        }
    }

    private fun checkLatest() {
        if (!checking.compareAndSet(false, true)) return
        try {
            val row = queryLatest() ?: return
            val isNew = row.id > lastSeenId || row.addedAt > lastSeenAddedAt
            if (!isNew) return

            val nowSec = System.currentTimeMillis() / 1000
            if (nowSec - row.addedAt > 120) return

            lastSeenId = row.id
            lastSeenAddedAt = row.addedAt
            Log.i(TAG, "new screenshot: ${row.displayName} id=${row.id}")
            onScreenshot(row.uri)
        } finally {
            checking.set(false)
        }
    }

    private fun queryLatest(): ScreenshotRow? {
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.DATE_ADDED,
            MediaStore.Files.FileColumns.RELATIVE_PATH,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )
        val selection = buildString {
            append("${MediaStore.Files.FileColumns.MEDIA_TYPE}=?")
            append(" AND (")
            append("${MediaStore.Files.FileColumns.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Files.FileColumns.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?")
            append(" OR ${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?")
            append(")")
        }
        val args = arrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            "%Screenshots%",
            "%Screenshot%",
            "Screenshot%",
            "Screen capture%",
        )

        return try {
            context.contentResolver.query(
                collection,
                projection,
                selection,
                args,
                "${MediaStore.Files.FileColumns.DATE_ADDED} DESC",
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID))
                val name = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)).orEmpty()
                val added = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_ADDED))
                val uri = ContentUris.withAppendedId(collection, id)
                ScreenshotRow(id, name, added, uri)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "screenshot query denied — grant Photos permission", e)
            null
        }
    }

    private data class ScreenshotRow(
        val id: Long,
        val displayName: String,
        val addedAt: Long,
        val uri: Uri,
    )

    companion object {
        private const val TAG = "ScreenshotWatcher"
    }
}
