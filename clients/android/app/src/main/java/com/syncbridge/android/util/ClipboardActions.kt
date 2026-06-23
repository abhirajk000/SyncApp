package com.syncbridge.android.util

import android.content.ClipData
import android.content.Context
import android.widget.Toast
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

suspend fun copyEntryToClipboard(context: Context, api: ApiClient, entry: ClipboardEntry): Boolean {
    val coordinator = (context.applicationContext as? com.syncbridge.android.SyncBridgeApp)?.clipboardSync
    return withContext(Dispatchers.IO) {
        if (!isImageContentType(entry.contentType)) {
            withContext(Dispatchers.Main) {
                coordinator?.applyLocalCopy(entry) ?: run {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("SyncBridge", entry.content))
                }
                Toast.makeText(context, "Copied", Toast.LENGTH_SHORT).show()
            }
            return@withContext true
        }

        var bytes = resolveClipboardImageBytes(api, entry)
        if (bytes == null) {
            withContext(Dispatchers.Main) {
                Toast.makeText(context, "Image unavailable", Toast.LENGTH_SHORT).show()
            }
            return@withContext false
        }

        val ext = when {
            entry.contentType.contains("jpeg") || entry.contentType.contains("jpg") -> "jpg"
            entry.contentType.contains("webp") -> "webp"
            entry.contentType.contains("gif") -> "gif"
            else -> "png"
        }
        val cacheFile = File(context.cacheDir, "clip_${entry.id}.$ext")
        cacheFile.writeBytes(bytes)
        val mimeType = entry.contentType.ifBlank { "image/jpeg" }
        val ok = withContext(Dispatchers.Main) {
            coordinator?.prepareLocalClipboardWrite()
            coordinator?.lockImageBytesHash(bytes, mimeType)
            val written = setClipboardImageFile(context, cacheFile, mimeType)
            if (written) coordinator?.finishLocalClipboardWrite()
            if (!written) {
                Toast.makeText(context, "Image unavailable", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(context, "Image copied", Toast.LENGTH_SHORT).show()
            }
            written
        }
        return@withContext ok
    }
}
