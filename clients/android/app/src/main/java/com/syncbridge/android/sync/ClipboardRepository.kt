package com.syncbridge.android.sync

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import androidx.core.content.FileProvider
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import java.io.File
import java.io.FileOutputStream

class ClipboardRepository(
    private val context: Context,
    private val api: ApiClient,
) {
    fun readPrimaryClip(): Pair<String, String>? {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = cm.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        val item = clip.getItemAt(0)

        val text = item.coerceToText(context)?.toString()?.trim().orEmpty()
        if (text.isNotEmpty()) return text to "text/plain"

        val uri = item.uri
        if (uri != null) {
            readImageFromUri(uri)?.let { return it }
        }

        return null
    }

    fun applyRemoteClip(entry: ClipboardEntry) {
        if (entry.contentType.startsWith("image/")) {
            applyRemoteImage(entry.content, entry.contentType)
            return
        }
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("SyncBridge", entry.content))
    }

    suspend fun syncClipboard(contentType: String, content: String) {
        val synced = api.syncClipboard(content, contentType)
        SyncEventBus.emitClipboard(synced)
    }

    private fun readImageFromUri(uri: Uri): Pair<String, String>? {
        return try {
            val mime = context.contentResolver.getType(uri) ?: "image/png"
            if (!mime.startsWith("image/")) return null
            val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
            if (bytes.size > MAX_IMAGE_BYTES) return null
            Base64.encodeToString(bytes, Base64.NO_WRAP) to mime
        } catch (_: Exception) {
            null
        }
    }

    private fun applyRemoteImage(base64: String, contentType: String) {
        val bytes = Base64.decode(base64, Base64.DEFAULT)
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return
        val ext = when {
            contentType.contains("jpeg") || contentType.contains("jpg") -> "jpg"
            contentType.contains("webp") -> "webp"
            else -> "png"
        }
        val file = File(context.cacheDir, "sync_clip.$ext")
        FileOutputStream(file).use { out ->
            val format = when (ext) {
                "jpg" -> android.graphics.Bitmap.CompressFormat.JPEG
                "webp" -> android.graphics.Bitmap.CompressFormat.WEBP
                else -> android.graphics.Bitmap.CompressFormat.PNG
            }
            bitmap.compress(format, 95, out)
        }
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newUri(context.contentResolver, "SyncBridge", uri))
    }

    companion object {
        private const val MAX_IMAGE_BYTES = 10 * 1024 * 1024
    }
}
