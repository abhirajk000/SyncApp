package com.syncbridge.android.localsend

import org.json.JSONArray
import org.json.JSONObject
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID

object LocalSendProtocol {
    const val SERVICE_TYPE = "_syncbridge-localsend._tcp."
    const val CHUNK_SIZE = 4 * 1024 * 1024
    private val CHUNK_MAGIC = byteArrayOf(0x53, 0x42, 0x4C, 0x53) // SBLS

    data class FileEntry(
        val index: Int,
        val name: String,
        val relativePath: String,
        val size: Long,
    )

    data class Offer(
        val id: String,
        val sender: String,
        val files: List<FileEntry>,
    )

    data class Resume(
        val id: String,
        val offsets: Map<Int, Long>,
    )

    fun newTransferId(): String = UUID.randomUUID().toString()

    fun encodeOffer(offer: Offer): String {
        val files = JSONArray()
        offer.files.forEach { f ->
            files.put(
                JSONObject()
                    .put("index", f.index)
                    .put("name", f.name)
                    .put("relativePath", f.relativePath)
                    .put("size", f.size),
            )
        }
        return JSONObject()
            .put("op", "offer")
            .put("id", offer.id)
            .put("sender", offer.sender)
            .put("files", files)
            .toString() + "\n"
    }

    fun encodeAccept(id: String): String =
        JSONObject().put("op", "accept").put("id", id).toString() + "\n"

    fun encodeReject(id: String, reason: String): String =
        JSONObject().put("op", "reject").put("id", id).put("reason", reason).toString() + "\n"

    fun encodeFileBegin(id: String, index: Int, offset: Long): String =
        JSONObject()
            .put("op", "file_begin")
            .put("id", id)
            .put("index", index)
            .put("offset", offset)
            .toString() + "\n"

    fun encodeChunkAck(id: String, index: Int, offset: Long): String =
        JSONObject()
            .put("op", "chunk_ack")
            .put("id", id)
            .put("index", index)
            .put("offset", offset)
            .toString() + "\n"

    fun encodeFileEnd(id: String, index: Int): String =
        JSONObject().put("op", "file_end").put("id", id).put("index", index).toString() + "\n"

    fun encodeComplete(id: String): String =
        JSONObject().put("op", "complete").put("id", id).toString() + "\n"

    fun encodeResume(id: String, offsets: Map<Int, Long>): String {
        val arr = JSONArray()
        offsets.forEach { (idx, off) ->
            arr.put(JSONObject().put("index", idx).put("offset", off))
        }
        return JSONObject().put("op", "resume").put("id", id).put("files", arr).toString() + "\n"
    }

    fun parseMessage(line: String): JSONObject = JSONObject(line.trim())

    fun parseOffer(obj: JSONObject): Offer {
        val files = mutableListOf<FileEntry>()
        val arr = obj.getJSONArray("files")
        for (i in 0 until arr.length()) {
            val f = arr.getJSONObject(i)
            files.add(
                FileEntry(
                    index = f.getInt("index"),
                    name = f.getString("name"),
                    relativePath = f.getString("relativePath"),
                    size = f.getLong("size"),
                ),
            )
        }
        return Offer(
            id = obj.getString("id"),
            sender = obj.getString("sender"),
            files = files,
        )
    }

    fun parseResume(obj: JSONObject): Resume {
        val offsets = mutableMapOf<Int, Long>()
        val arr = obj.getJSONArray("files")
        for (i in 0 until arr.length()) {
            val f = arr.getJSONObject(i)
            offsets[f.getInt("index")] = f.getLong("offset")
        }
        return Resume(id = obj.getString("id"), offsets = offsets)
    }

    fun writeChunk(out: OutputStream, fileIndex: Int, offset: Long, data: ByteArray, length: Int) {
        val buf = ByteBuffer.allocate(18 + length).order(ByteOrder.BIG_ENDIAN)
        buf.put(CHUNK_MAGIC)
        buf.putShort(fileIndex.toShort())
        buf.putLong(offset)
        buf.putInt(length)
        buf.put(data, 0, length)
        out.write(buf.array())
        out.flush()
    }

    fun readChunk(`in`: InputStream): Chunk? {
        val header = ByteArray(18)
        var read = 0
        while (read < 18) {
            val n = `in`.read(header, read, 18 - read)
            if (n < 0) return null
            read += n
        }
        if (!header.copyOfRange(0, 4).contentEquals(CHUNK_MAGIC)) return null
        val buf = ByteBuffer.wrap(header, 4, 14).order(ByteOrder.BIG_ENDIAN)
        val fileIndex = buf.short.toInt() and 0xFFFF
        val offset = buf.long
        val length = buf.int
        val payload = ByteArray(length)
        DataInputStream(`in`).readFully(payload)
        return Chunk(fileIndex, offset, payload)
    }

    data class Chunk(val fileIndex: Int, val offset: Long, val data: ByteArray)
}
