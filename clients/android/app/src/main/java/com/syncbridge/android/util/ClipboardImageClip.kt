package com.syncbridge.android.util

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

fun setClipboardImageFile(context: Context, file: File, mimeType: String): Boolean {
    return try {
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        setClipboardImageUri(context, uri, mimeType)
    } catch (e: Exception) {
        Log.e(TAG, "setClipboardImageFile failed: ${file.name}", e)
        false
    }
}

fun setClipboardImageUri(context: Context, uri: Uri, mimeType: String): Boolean {
    return try {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val mime = mimeType.ifBlank { "image/jpeg" }
        // URI clip — pastes as a real image in Messages, WhatsApp, Gallery, etc.
        // Intent clips coerce to text (raw URI/base64) in most apps.
        val clip = ClipData(
            ClipDescription("SyncBridge", arrayOf(mime, ClipDescription.MIMETYPE_TEXT_URILIST, "image/*")),
            ClipData.Item(uri),
        )
        cm.setPrimaryClip(clip)
        true
    } catch (e: Exception) {
        Log.e(TAG, "setClipboardImageUri failed", e)
        false
    }
}

private const val TAG = "ClipboardImageClip"
