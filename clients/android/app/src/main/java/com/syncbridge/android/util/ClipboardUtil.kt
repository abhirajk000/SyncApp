package com.syncbridge.android.util

import android.util.Base64
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry

fun isImageContentType(contentType: String): Boolean =
    contentType.startsWith("image/")

fun clipboardImageBytes(entry: ClipboardEntry): ByteArray? {
    val content = entry.content
    if (content.isBlank()) return null
    return try {
        val raw = if (content.startsWith("data:")) {
            content.substringAfter("base64,", content)
        } else {
            content
        }
        Base64.decode(raw, Base64.DEFAULT)
    } catch (_: Exception) {
        null
    }
}

/** Full-resolution bytes for copy — never prefer thumbnail when full content exists on server. */
suspend fun resolveClipboardImageBytes(api: ApiClient, entry: ClipboardEntry): ByteArray? {
    if (entry.content.isNotBlank()) {
        clipboardImageBytes(entry)?.let { return it }
    }
    runCatching { api.fetchClipboardEntry(entry.id) }.getOrNull()?.let { full ->
        clipboardImageBytes(full)?.let { return it }
    }
    if (entry.hasThumbnail) {
        return api.downloadClipboardThumbnailBytes(entry.id)
    }
    return null
}
