package com.syncbridge.android.sync

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.util.Base64
import android.util.Log
import com.syncbridge.android.util.setClipboardImageFile
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream

class ClipboardRepository(
    private val context: Context,
    private val api: ApiClient,
) {
    fun readPrimaryClip(): Pair<String, String>? {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        if (!cm.hasPrimaryClip()) return null
        val clip = cm.primaryClip ?: return null
        if (clip.itemCount == 0) return null

        readImageFromClip(clip)?.let { return it }

        for (i in 0 until clip.itemCount) {
            val item = clip.getItemAt(i)
            readTextFromClipItem(item)?.let { return it }
        }
        return null
    }

    private fun readTextFromClipItem(item: ClipData.Item): Pair<String, String>? {
        val direct = item.text?.toString()?.trim().orEmpty()
        if (direct.isNotEmpty()) {
            if (direct.startsWith("content://")) {
                try {
                    readImageFromUri(Uri.parse(direct))?.let { return it }
                } catch (_: Exception) {
                }
            }
            readImageFromPath(direct)?.let { return it }
            return direct to "text/plain"
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            item.htmlText?.let { html ->
                val stripped = html.replace(Regex("<[^>]+>"), " ").replace(Regex("\\s+"), " ").trim()
                if (stripped.isNotEmpty()) return stripped to "text/plain"
            }
        }

        val text = item.coerceToText(context)?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return null
        if (text.startsWith("content://")) {
            try {
                readImageFromUri(Uri.parse(text))?.let { return it }
            } catch (_: Exception) {
            }
        }
        readImageFromPath(text)?.let { return it }
        return text to "text/plain"
    }

    fun describeClipboard(): String {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        if (!cm.hasPrimaryClip()) return "empty"
        val clip = cm.primaryClip ?: return "null-clip"
        val desc = clip.description
        val mimes = (0 until desc.mimeTypeCount).map { desc.getMimeType(it) }
        val items = (0 until clip.itemCount).map { i ->
            val item = clip.getItemAt(i)
            "uri=${item.uri} text=${item.coerceToText(context)?.toString()?.take(40)}"
        }
        return "mimes=$mimes items=$items"
    }

    fun applyRemoteClip(entry: ClipboardEntry) {
        if (entry.contentType.startsWith("image/")) {
            applyRemoteImage(entry.content, entry.contentType)
            return
        }
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("SyncBridge", entry.content))
    }

    suspend fun syncClipboard(contentType: String, content: String): ClipboardEntry {
        val synced = api.syncClipboard(content, contentType)
        val uiEntry = synced.copy(
            hasThumbnail = synced.hasThumbnail || synced.contentType.startsWith("image/"),
        )
        SyncEventBus.emitClipboard(uiEntry)
        return uiEntry
    }

    suspend fun syncImageFromUri(uri: Uri) {
        readImageFromUri(uri)?.let { (content, type) ->
            syncClipboard(type, content)
        }
    }

    fun readImageFromUri(uri: Uri): Pair<String, String>? {
        return try {
            val bytes = openImageBytes(uri) ?: return null
            encodeImageBytes(bytes, context.contentResolver.getType(uri))
        } catch (e: Exception) {
            Log.w(TAG, "read image uri failed: $uri", e)
            null
        }
    }

    private fun readImageFromClip(clip: ClipData): Pair<String, String>? {
        readImageFromClipData(clip)?.let { return it }

        val desc = clip.description
        for (i in 0 until desc.mimeTypeCount) {
            val mime = desc.getMimeType(i)
            if (!mime.startsWith("image/")) continue
            for (j in 0 until clip.itemCount) {
                readImageFromClipItem(clip.getItemAt(j))?.let { return it }
            }
        }

        for (i in 0 until clip.itemCount) {
            readImageFromClipItem(clip.getItemAt(i))?.let { return it }
        }
        return null
    }

    private fun readImageFromClipData(clip: ClipData): Pair<String, String>? {
        val mimeFilters = listOf("image/png", "image/jpeg", "image/jpg", "image/webp", "image/*")
        for (i in 0 until clip.itemCount) {
            val uri = clip.getItemAt(i).uri ?: continue
            for (mime in mimeFilters) {
                try {
                    context.contentResolver.openTypedAssetFileDescriptor(uri, mime, null)?.use { afd ->
                        afd.createInputStream()?.use { stream ->
                            val bytes = stream.readBytes()
                            encodeImageBytes(bytes, mime)?.let { return it }
                        }
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "openTypedAssetFileDescriptor($mime): ${e.message}")
                }
            }
        }
        return null
    }

    private fun readImageFromClipItem(item: ClipData.Item): Pair<String, String>? {
        item.uri?.let { uri -> readImageFromUri(uri)?.let { return it } }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            item.htmlText?.let { html ->
                extractImageUriFromHtml(html)?.let { uri ->
                    readImageFromUri(uri)?.let { return it }
                }
            }
        }

        val intent = item.intent
        if (intent != null) {
            val stream = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            stream?.let { uri -> readImageFromUri(uri)?.let { return it } }
        }

        val text = item.coerceToText(context)?.toString()?.trim().orEmpty()
        if (text.startsWith("content://")) {
            readImageFromUri(Uri.parse(text))?.let { return it }
        }
        readImageFromPath(text)?.let { return it }
        return null
    }

    private fun readImageFromPath(path: String): Pair<String, String>? {
        if (!path.startsWith("/")) return null
        val file = File(path)
        if (!file.isFile || !file.canRead()) return null
        return try {
            FileInputStream(file).use { stream ->
                val bytes = stream.readBytes()
                encodeImageBytes(bytes, null)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun openImageBytes(uri: Uri): ByteArray? {
        openImageStream(uri)?.use { return it.readBytes() }

        try {
            context.contentResolver.openAssetFileDescriptor(uri, "r")?.use { afd ->
                afd.createInputStream()?.use { return it.readBytes() }
            }
        } catch (e: Exception) {
            Log.d(TAG, "openAssetFileDescriptor failed for $uri: ${e.message}")
        }

        if (DocumentsContract.isDocumentUri(context, uri)) {
            val docId = DocumentsContract.getDocumentId(uri)
            if (docId.startsWith("image:")) {
                val mediaId = docId.substringAfter("image:").toLongOrNull() ?: return null
                val mediaUri = ContentUris.withAppendedId(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    mediaId,
                )
                openImageStream(mediaUri)?.use { return it.readBytes() }
            }
        }
        return null
    }

    private fun openImageStream(uri: Uri): InputStream? {
        return try {
            context.contentResolver.openInputStream(uri)
        } catch (e: SecurityException) {
            Log.w(TAG, "openInputStream denied for $uri", e)
            null
        } catch (e: Exception) {
            Log.w(TAG, "openInputStream failed for $uri: ${e.message}")
            null
        }
    }

    private fun encodeImageBytes(bytes: ByteArray, declaredMime: String?): Pair<String, String>? {
        if (bytes.isEmpty()) return null
        val compressed = compressForUpload(bytes)
        if (compressed.size > MAX_IMAGE_BYTES) return null
        val uploadMime = normalizeImageMime(declaredMime ?: "", compressed)
        return Base64.encodeToString(compressed, Base64.NO_WRAP) to uploadMime
    }

    /** Same bytes → base64 pipeline used for uploads; for dedupe hashing after in-app copy. */
    fun fingerprintImageBytes(bytes: ByteArray, declaredMime: String?): String? {
        return encodeImageBytes(bytes, declaredMime)?.first?.let { ClipboardSyncCoordinator.hashContent(it) }
    }

    private fun compressForUpload(bytes: ByteArray): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return bytes
        val scaled = scaleDown(bitmap, 1920)
        if (scaled !== bitmap) bitmap.recycle()
        var quality = 85
        var out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)
        while (out.size() > 2_000_000 && quality > 55) {
            quality -= 10
            out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)
        }
        scaled.recycle()
        return out.toByteArray()
    }

    private fun scaleDown(bitmap: Bitmap, maxDim: Int): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        val largest = maxOf(w, h)
        if (largest <= maxDim) return bitmap
        val scale = maxDim.toFloat() / largest
        val nw = (w * scale).toInt().coerceAtLeast(1)
        val nh = (h * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, nw, nh, true)
    }

    private fun applyRemoteImage(base64: String, contentType: String) {
        val bytes = Base64.decode(base64, Base64.DEFAULT)
        val ext = when {
            contentType.contains("jpeg") || contentType.contains("jpg") -> "jpg"
            contentType.contains("webp") -> "webp"
            else -> "png"
        }
        val file = File(context.cacheDir, "sync_clip.$ext")
        file.writeBytes(bytes)
        val mime = when (ext) {
            "jpg" -> "image/jpeg"
            "webp" -> "image/webp"
            else -> "image/png"
        }
        setClipboardImageFile(context, file, mime)
    }

    private fun extractImageUriFromHtml(html: String): Uri? {
        val match = IMG_SRC_REGEX.find(html) ?: return null
        val src = match.groupValues[1]
        return if (src.startsWith("content://")) Uri.parse(src) else null
    }

    private fun normalizeImageMime(declared: String, bytes: ByteArray): String {
        if (declared.removeSuffix("/*") in UPLOAD_MIMES.map { it.substringBefore("/") }) {
            val clean = declared.removeSuffix("/*")
            if (clean == "image") return sniffImageBytes(bytes)
            if (declared in UPLOAD_MIMES) return declared
        }
        if (declared in UPLOAD_MIMES) return declared
        val sniffed = sniffImageBytes(bytes)
        if (sniffed in UPLOAD_MIMES) return sniffed
        return "image/jpeg"
    }

    private fun sniffImageBytes(data: ByteArray): String {
        if (data.size < 12) return "image/jpeg"
        return when {
            data[0] == 0xFF.toByte() && data[1] == 0xD8.toByte() -> "image/jpeg"
            data[0] == 0x89.toByte() && data[1] == 0x50.toByte() -> "image/png"
            data[0] == 0x47.toByte() && data[1] == 0x49.toByte() -> "image/gif"
            else -> "image/jpeg"
        }
    }

    companion object {
        private const val TAG = "ClipboardRepository"
        private const val MAX_IMAGE_BYTES = 7 * 1024 * 1024
        private val UPLOAD_MIMES = setOf("image/jpeg", "image/png", "image/gif", "image/webp")
        private val IMG_SRC_REGEX = Regex("""src=["'](content://[^"']+)["']""", RegexOption.IGNORE_CASE)
    }
}
