package com.syncbridge.android.localsend

import android.content.Context
import android.net.Uri
import android.os.Environment
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.RandomAccessFile
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.max

class LocalSendManager(private val context: Context) {
    private var scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val deviceId = LocalSendDiscovery.deviceId(context)
    private val discovery = LocalSendDiscovery(context, deviceId)

    val peers: StateFlow<List<LocalPeer>> = discovery.peers

    private val _progress = MutableStateFlow<LocalTransferProgress?>(null)
    val progress: StateFlow<LocalTransferProgress?> = _progress.asStateFlow()

    private val _incomingOffer = MutableStateFlow<IncomingOffer?>(null)
    val incomingOffer: StateFlow<IncomingOffer?> = _incomingOffer.asStateFlow()

    private var serverSocket: ServerSocket? = null
    private var activeJob: Job? = null
    private var acceptDeferred: CompletableDeferred<Boolean>? = null
    private val resumeOffsets = mutableMapOf<String, MutableMap<Int, Long>>()
    @Volatile private var running = false

    val friendlyName: String get() = discovery.friendlyName

    fun start() {
        if (running) return
        running = true
        scope.launch {
            val socket = ServerSocket(0)
            serverSocket = socket
            discovery.start(socket.localPort)
            acceptLoop(socket)
        }
    }

    fun stop() {
        if (!running) return
        running = false
        activeJob?.cancel()
        acceptDeferred?.complete(false)
        discovery.stop()
        runCatching { serverSocket?.close() }
        serverSocket = null
        scope.cancel()
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    }

    fun dismissIncomingOffer() {
        acceptDeferred?.complete(false)
        _incomingOffer.value = null
    }

    fun acceptIncoming() {
        acceptDeferred?.complete(true)
        _incomingOffer.value = null
    }

    fun rejectIncoming() {
        acceptDeferred?.complete(false)
        _incomingOffer.value = null
    }

    fun sendToPeer(peer: LocalPeer, uris: List<Uri>) {
        activeJob?.cancel()
        activeJob = scope.launch { sendTransfer(peer, uris) }
    }

    fun cancelTransfer() {
        activeJob?.cancel()
        _progress.value = null
    }

    fun clearCompletedTransfer() {
        if (_progress.value?.phase == LocalTransferPhase.Completed) {
            _progress.value = null
        }
    }

    private suspend fun acceptLoop(socket: ServerSocket) {
        while (scope.isActive) {
            val client = withContext(Dispatchers.IO) {
                runCatching { socket.accept() }.getOrNull()
            } ?: break
            if (activeJob?.isActive == true) {
                runCatching {
                    client.use { c ->
                        c.getOutputStream().write(
                            LocalSendProtocol.encodeReject("busy", "Busy").toByteArray(),
                        )
                    }
                }
                continue
            }
            activeJob = scope.launch { handleIncomingConnection(client) }
        }
    }

    private suspend fun handleIncomingConnection(socket: Socket) {
        withContext(Dispatchers.IO) {
            socket.use { sock ->
                val reader = BufferedReader(InputStreamReader(sock.getInputStream()))
                val out = sock.getOutputStream()
                val line = reader.readLine() ?: return@withContext
                val msg = LocalSendProtocol.parseMessage(line)
                if (msg.getString("op") != "offer") return@withContext

                val offer = LocalSendProtocol.parseOffer(msg)
                val peer = peers.value.firstOrNull { it.host == sock.inetAddress.hostAddress }
                    ?: LocalPeer(
                        id = "unknown",
                        name = offer.sender,
                        platform = "unknown",
                        host = sock.inetAddress.hostAddress ?: "",
                        port = sock.port,
                    )
                val deferred = CompletableDeferred<Boolean>()
                acceptDeferred = deferred
                _incomingOffer.value = IncomingOffer(offer, peer)

                val accepted = deferred.await()
                acceptDeferred = null
                if (!accepted) {
                    out.write(LocalSendProtocol.encodeReject(offer.id, "Declined").toByteArray())
                    out.flush()
                    return@withContext
                }

                receiveOnSocket(sock, reader, out, offer, peer)
            }
        }
    }

    private suspend fun receiveOnSocket(
        sock: Socket,
        reader: BufferedReader,
        out: OutputStream,
        offer: LocalSendProtocol.Offer,
        peer: LocalPeer,
    ) {
        val offsets = resumeOffsets.getOrPut(offer.id) { mutableMapOf() }
        val resume = offsets.filter { (_, v) -> v > 0 }
        if (resume.isNotEmpty()) {
            out.write(LocalSendProtocol.encodeResume(offer.id, resume).toByteArray())
        } else {
            out.write(LocalSendProtocol.encodeAccept(offer.id).toByteArray())
        }
        out.flush()

        val destRoot = receiveDir()
        val fileProgress = offer.files.map {
            LocalFileProgress(it.index, it.name, it.size, offsets[it.index] ?: 0L)
        }.toMutableList()

        updateProgress(
            LocalTransferProgress(
                transferId = offer.id,
                peerName = offer.sender,
                direction = LocalTransferDirection.Receiving,
                phase = LocalTransferPhase.Transferring,
                files = fileProgress.toList(),
            ),
        )

        val speedTracker = SpeedTracker()
        var currentStream: FileOutputStream? = null
        var currentFileIndex = -1
        val input = sock.getInputStream()

        while (sock.isConnected && !sock.isClosed) {
            if (input.available() > 0 && looksLikeChunk(input)) {
                val chunk = LocalSendProtocol.readChunk(input) ?: break
                if (chunk.fileIndex != currentFileIndex) {
                    currentStream?.close()
                    val entry = offer.files.first { it.index == chunk.fileIndex }
                    val dest = File(destRoot, entry.relativePath)
                    dest.parentFile?.mkdirs()
                    currentFileIndex = chunk.fileIndex
                    currentStream = FileOutputStream(dest, chunk.offset > 0)
                }
                currentStream?.write(chunk.data)
                offsets[chunk.fileIndex] = chunk.offset + chunk.data.size
                val idx = fileProgress.indexOfFirst { it.index == chunk.fileIndex }
                if (idx >= 0) {
                    fileProgress[idx] = fileProgress[idx].copy(transferred = offsets[chunk.fileIndex] ?: 0L)
                }
                speedTracker.add(chunk.data.size)
                updateProgress(
                    _progress.value?.copy(
                        files = fileProgress.toList(),
                        speedBytesPerSec = speedTracker.bytesPerSec(),
                    ),
                )
                val entry = offer.files.firstOrNull { it.index == chunk.fileIndex }
                if (entry != null && (offsets[chunk.fileIndex] ?: 0L) >= entry.size) {
                    out.write(
                        LocalSendProtocol.encodeChunkAck(offer.id, chunk.fileIndex, offsets[chunk.fileIndex] ?: 0L)
                            .toByteArray(),
                    )
                    out.flush()
                }
                continue
            }

            if (!reader.ready()) {
                delay(5)
                continue
            }

            val ctrl = reader.readLine() ?: break
            val ctrlMsg = LocalSendProtocol.parseMessage(ctrl)
            when (ctrlMsg.getString("op")) {
                "file_begin" -> {
                    currentStream?.close()
                    val index = ctrlMsg.getInt("index")
                    val offset = ctrlMsg.getLong("offset")
                    val entry = offer.files.first { it.index == index }
                    val dest = File(destRoot, entry.relativePath)
                    dest.parentFile?.mkdirs()
                    currentFileIndex = index
                    currentStream = FileOutputStream(dest, offset > 0)
                    offsets[index] = offset
                }
                "file_end" -> {
                    currentStream?.close()
                    currentStream = null
                }
                "complete" -> {
                    currentStream?.close()
                    updateProgress(_progress.value?.copy(phase = LocalTransferPhase.Completed, speedBytesPerSec = 0))
                    return
                }
            }
        }

        currentStream?.close()
        if (_progress.value?.phase != LocalTransferPhase.Completed) {
            updateProgress(_progress.value?.copy(phase = LocalTransferPhase.Paused))
        }
    }

    private suspend fun sendTransfer(peer: LocalPeer, uris: List<Uri>) {
        withContext(Dispatchers.IO) {
            val transferId = LocalSendProtocol.newTransferId()
            val sources = expandUris(uris)
            if (sources.isEmpty()) return@withContext

            val files = sources.map {
                LocalSendProtocol.FileEntry(it.index, it.name, it.relativePath, it.size)
            }
            val offer = LocalSendProtocol.Offer(transferId, friendlyName, files)
            val fileProgress = files.map { LocalFileProgress(it.index, it.name, it.size, 0) }.toMutableList()
            val offsets = resumeOffsets.getOrPut(transferId) { mutableMapOf() }

            updateProgress(
                LocalTransferProgress(
                    transferId = transferId,
                    peerName = peer.name,
                    direction = LocalTransferDirection.Sending,
                    phase = LocalTransferPhase.Connecting,
                    files = fileProgress.toList(),
                ),
            )

            var attempt = 0
            while (attempt < 5 && scope.isActive) {
                attempt++
                try {
                    Socket(peer.host, peer.port).use { socket ->
                        val out = socket.getOutputStream()
                        val reader = BufferedReader(InputStreamReader(socket.getInputStream()))

                        out.write(LocalSendProtocol.encodeOffer(offer).toByteArray())
                        out.flush()
                        updateProgress(_progress.value?.copy(phase = LocalTransferPhase.WaitingAccept))

                        var accepted = false
                        while (!accepted) {
                            val line = reader.readLine() ?: throw java.io.IOException("Disconnected")
                            when (LocalSendProtocol.parseMessage(line).getString("op")) {
                                "accept" -> accepted = true
                                "resume" -> {
                                    val resume = LocalSendProtocol.parseResume(LocalSendProtocol.parseMessage(line))
                                    resume.offsets.forEach { (k, v) -> offsets[k] = v }
                                    accepted = true
                                }
                                "reject" -> throw java.io.IOException("Rejected")
                            }
                        }

                        updateProgress(_progress.value?.copy(phase = LocalTransferPhase.Transferring))
                        val speedTracker = SpeedTracker()

                        for (src in sources) {
                            val startOffset = offsets[src.index] ?: 0L
                            out.write(LocalSendProtocol.encodeFileBegin(transferId, src.index, startOffset).toByteArray())
                            out.flush()

                            val buf = ByteArray(LocalSendProtocol.CHUNK_SIZE)
                            RandomAccessFile(src.file, "r").use { raf ->
                                raf.seek(startOffset)
                                var offset = startOffset
                                while (offset < src.size) {
                                    val toRead = minOf(buf.size.toLong(), src.size - offset).toInt()
                                    val n = raf.read(buf, 0, toRead)
                                    if (n <= 0) break
                                    LocalSendProtocol.writeChunk(out, src.index, offset, buf, n)
                                    offset += n
                                    offsets[src.index] = offset
                                    val idx = fileProgress.indexOfFirst { it.index == src.index }
                                    if (idx >= 0) fileProgress[idx] = fileProgress[idx].copy(transferred = offset)
                                    speedTracker.add(n)
                                    updateProgress(
                                        _progress.value?.copy(
                                            files = fileProgress.toList(),
                                            speedBytesPerSec = speedTracker.bytesPerSec(),
                                        ),
                                    )
                                }
                            }
                            out.write(LocalSendProtocol.encodeFileEnd(transferId, src.index).toByteArray())
                            out.flush()
                        }

                        out.write(LocalSendProtocol.encodeComplete(transferId).toByteArray())
                        out.flush()
                        updateProgress(_progress.value?.copy(phase = LocalTransferPhase.Completed, speedBytesPerSec = 0))
                        return@withContext
                    }
                } catch (e: Exception) {
                    if (attempt >= 5) {
                        updateProgress(
                            _progress.value?.copy(
                                phase = LocalTransferPhase.Failed,
                                error = e.message ?: "Transfer failed",
                            ),
                        )
                    } else {
                        updateProgress(_progress.value?.copy(phase = LocalTransferPhase.Paused))
                        delay(1500)
                    }
                }
            }
        }
    }

    private data class SourceFile(val file: File, val name: String, val relativePath: String, val size: Long, val index: Int)

    private fun expandUris(uris: List<Uri>): List<SourceFile> {
        val result = mutableListOf<SourceFile>()
        var index = 0
        for (uri in uris) {
            val name = queryName(uri) ?: "file_$index"
            context.contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                val size = pfd.statSize
                val cache = File(context.cacheDir, "localsend/$name")
                cache.parentFile?.mkdirs()
                context.contentResolver.openInputStream(uri)?.use { input ->
                    cache.outputStream().use { output -> input.copyTo(output) }
                }
                result.add(SourceFile(cache, name, name, size, index++))
            }
        }
        return result
    }

    private fun queryName(uri: Uri): String? {
        val cursor = context.contentResolver.query(
            uri,
            arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )
        cursor?.use { if (it.moveToFirst()) return it.getString(0) }
        return uri.lastPathSegment
    }

    private fun receiveDir(): File {
        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val dir = File(downloads, "SyncBridge")
        dir.mkdirs()
        return dir
    }

    private fun looksLikeChunk(input: java.io.InputStream): Boolean {
        input.mark(4)
        val magic = ByteArray(4)
        val n = input.read(magic)
        input.reset()
        return n == 4 && magic.contentEquals(byteArrayOf(0x53, 0x42, 0x4C, 0x53))
    }

    private fun updateProgress(p: LocalTransferProgress?) {
        _progress.value = p
    }

    private class SpeedTracker {
        private val window = ArrayDeque<Pair<Long, Int>>()

        fun add(bytes: Int) {
            val now = System.currentTimeMillis()
            window.addLast(now to bytes)
            while (window.isNotEmpty() && now - window.first().first > 2000) window.removeFirst()
        }

        fun bytesPerSec(): Long {
            if (window.size < 2) return 0
            val span = max(1L, window.last().first - window.first().first)
            return (window.sumOf { it.second } * 1000L) / span
        }
    }
}
