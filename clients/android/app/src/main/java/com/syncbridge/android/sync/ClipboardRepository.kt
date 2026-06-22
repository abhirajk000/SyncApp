package com.syncbridge.android.sync

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import com.syncbridge.android.data.ApiClient

class ClipboardRepository(
    private val context: Context,
    private val api: ApiClient,
) {
    fun readPrimaryClip(): Pair<String, String>? {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = cm.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        val text = clip.getItemAt(0).coerceToText(context)?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return null
        return text to "text/plain"
    }

    fun applyRemoteClip(text: String) {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("SyncBridge", text))
    }

    suspend fun syncClipboard(contentType: String, content: String) {
        val entry = api.syncClipboard(content, contentType)
        SyncEventBus.emitClipboard(entry)
    }
}
