package com.syncbridge.android.data

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.syncbridge.android.network.NetworkManager
import java.security.MessageDigest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class UploadProgress(
    val name: String,
    val progress: Float,
    val status: UploadStatus,
    val error: String? = null,
)

enum class UploadStatus { Uploading, Success, Error }

class FileUploader(
    private val context: Context,
    private val api: ApiClient,
    private val networkManager: NetworkManager? = null,
) {
    suspend fun uploadUris(
        uris: List<Uri>,
        onProgress: (UploadProgress) -> Unit,
    ): Pair<Int, Int> = withContext(Dispatchers.IO) {
        var ok = 0
        var fail = 0
        val batchCount = uris.size
        val isFolder = batchCount > 1
        for (uri in uris) {
            val name = queryName(uri) ?: "file"
            try {
                context.contentResolver.openInputStream(uri)?.use { stream ->
                    val bytes = stream.readBytes()
                    uploadBytes(name, guessMime(uri, name), bytes, batchCount, isFolder) { p ->
                        onProgress(UploadProgress(name, p, UploadStatus.Uploading))
                    }
                } ?: throw ApiException("Cannot read file")
                onProgress(UploadProgress(name, 1f, UploadStatus.Success))
                ok++
            } catch (e: Exception) {
                onProgress(
                    UploadProgress(
                        name,
                        0f,
                        UploadStatus.Error,
                        e.message ?: "Upload failed",
                    ),
                )
                fail++
            }
        }
        ok to fail
    }

    suspend fun uploadBytes(
        name: String,
        mimeType: String,
        bytes: ByteArray,
        fileCount: Int = 1,
        isFolder: Boolean = false,
        onProgress: (Float) -> Unit = {},
    ): FileEntry {
        val hash = sha256Hex(bytes)
        val chunkSize = ApiClient.CHUNK_SIZE
        val chunkCount = (bytes.size + chunkSize - 1) / chunkSize
        val route = networkManager?.resolveUploadRoute(bytes.size.toLong(), fileCount, isFolder)
        val transferMode = route?.transferMode ?: "relay"
        val t0 = System.currentTimeMillis()
        val init = api.initFileUpload(name, mimeType, bytes.size.toLong(), hash, chunkSize, transferMode)
        var uploaded = 0
        for (index in 0 until chunkCount) {
            val start = index * chunkSize
            val end = minOf(start + chunkSize, bytes.size)
            val chunk = bytes.copyOfRange(start, end)
            api.uploadChunk(init.fileId, index, chunk, sha256Hex(chunk))
            uploaded++
            onProgress(uploaded.toFloat() / chunkCount)
        }
        val elapsed = (System.currentTimeMillis() - t0).coerceAtLeast(1)
        val bps = (bytes.size * 1000L) / elapsed
        route?.let { r ->
            networkManager?.logTransfer(
                name = name,
                method = r.route,
                fallbackReason = r.fallbackReason,
                bytesPerSec = bps,
                peerDeviceId = r.peerDeviceId,
            )
            networkManager?.markSync()
        }
        return api.completeFileUpload(init.fileId)
    }

    private fun queryName(uri: Uri): String? {
        if (uri.scheme == "content") {
            context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) return cursor.getString(idx)
            }
        }
        return uri.lastPathSegment
    }

    private fun guessMime(uri: Uri, name: String): String {
        context.contentResolver.getType(uri)?.let { return it }
        return when (name.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "mp4" -> "video/mp4"
            "pdf" -> "application/pdf"
            "txt" -> "text/plain"
            else -> "application/octet-stream"
        }
    }

    private fun sha256Hex(data: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(data)
        return digest.joinToString("") { "%02x".format(it) }
    }
}
