package com.syncbridge.android.util

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.FileEntry
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

fun isTextMime(mimeType: String): Boolean =
    mimeType.startsWith("text/") || mimeType == "application/json"

fun canCopyFile(file: FileEntry): Boolean {
    if (file.status != "ready") return false
    val ext = file.name.substringAfterLast('.', "").lowercase()
    return file.mimeType.startsWith("image/") ||
        isTextMime(file.mimeType) ||
        ext in setOf("txt", "md", "csv", "json", "log")
}

suspend fun downloadFileToDevice(context: Context, api: ApiClient, file: FileEntry) {
    withContext(Dispatchers.IO) {
        val bytes = api.downloadFileBytes(file.id)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, file.name)
                put(MediaStore.Downloads.MIME_TYPE, file.mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create download")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } else {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            dir.mkdirs()
            File(dir, file.name).writeBytes(bytes)
        }
    }
    withContext(Dispatchers.Main) {
        Toast.makeText(context, "Saved to Downloads", Toast.LENGTH_SHORT).show()
    }
}

suspend fun copyFileToClipboard(context: Context, api: ApiClient, file: FileEntry): Boolean {
    val coordinator = (context.applicationContext as? com.syncbridge.android.SyncBridgeApp)?.clipboardSync
    return withContext(Dispatchers.IO) {
        val bytes = api.downloadFileBytes(file.id)
        if (file.mimeType.startsWith("image/")) {
            val cacheFile = File(context.cacheDir, "copy_${file.id}")
            cacheFile.writeBytes(bytes)
            withContext(Dispatchers.Main) {
                coordinator?.prepareLocalClipboardWrite()
                coordinator?.lockImageBytesHash(bytes, file.mimeType)
                val written = setClipboardImageFile(context, cacheFile, file.mimeType.ifBlank { "image/jpeg" })
                if (written) {
                    coordinator?.finishLocalClipboardWrite()
                    Toast.makeText(context, "Image copied", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(context, "Image unavailable", Toast.LENGTH_SHORT).show()
                }
            }
            true
        } else if (isTextMime(file.mimeType) || file.name.substringAfterLast('.', "").lowercase() in setOf("txt", "md", "csv", "json", "log")) {
            val text = String(bytes, Charsets.UTF_8)
            withContext(Dispatchers.Main) {
                coordinator?.applyLocalCopy(
                    com.syncbridge.android.data.ClipboardEntry(
                        id = file.id,
                        contentType = file.mimeType.ifBlank { "text/plain" },
                        content = text,
                        sourceDeviceId = "",
                        pinned = false,
                        createdAt = file.createdAt,
                        hasThumbnail = false,
                    ),
                ) ?: run {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                    clipboard.setPrimaryClip(android.content.ClipData.newPlainText(file.name, text))
                }
                Toast.makeText(context, "Copied", Toast.LENGTH_SHORT).show()
            }
            true
        } else {
            false
        }
    }
}
