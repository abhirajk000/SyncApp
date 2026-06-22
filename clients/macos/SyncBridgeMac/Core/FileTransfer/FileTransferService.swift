// FileTransferService.swift
// Chunked file upload/download with resume support.
//
// Transfer routing:
//   Same LAN  → transfer_mode = "webrtc": the server Phase 6 signaling is
//               triggered; the actual data flows over an NWConnection directly
//               to the peer.  Server still stores a backup copy via relay so
//               offline devices can download later.
//   Other net → transfer_mode = "relay": standard chunked HTTP upload.
//
// Chunk size: 4 MiB by default; configurable.
// Integrity: SHA-256 of each chunk (X-Chunk-Hash header) + full file hash.
// Resume: on restart, GET /files/:id/status to find missing chunk indices.

import Foundation
import CryptoKit
import Network

// ── Progress callback ─────────────────────────────────────────────────────────

typealias TransferProgressHandler = (Double) -> Void   // 0.0 – 1.0
typealias TransferCompletionHandler = (Result<FileResponse, Error>) -> Void

// ── FileTransferService ───────────────────────────────────────────────────────

final class FileTransferService {

    static let chunkSize = 4 * 1024 * 1024   // 4 MiB

    private let api: APIClient
    private let authService: AuthService

    // In-progress uploads keyed by local file URL.
    private var uploads: [URL: String] = [:]   // fileURL → server fileId

    init(api: APIClient = .shared, authService: AuthService) {
        self.api = api
        self.authService = authService
    }

    // ── Upload ────────────────────────────────────────────────────────────────

    /// Uploads a file at `fileURL` to the server.
    /// Detects LAN peers and switches to relay vs webrtc mode automatically.
    func upload(
        fileURL: URL,
        onProgress: @escaping TransferProgressHandler,
        onComplete: @escaping TransferCompletionHandler
    ) {
        Task {
            do {
                let result = try await uploadAsync(fileURL: fileURL, onProgress: onProgress)
                await MainActor.run { onComplete(.success(result)) }
            } catch {
                await MainActor.run { onComplete(.failure(error)) }
            }
        }
    }

    func uploadAsync(
        fileURL: URL,
        onProgress: TransferProgressHandler? = nil
    ) async throws -> FileResponse {
        let data = try Data(contentsOf: fileURL)
        let mimeType = mimeType(for: fileURL)
        let fileHash = sha256Hex(data)
        let fileName = fileURL.lastPathComponent
        let chunkCount = Int(ceil(Double(data.count) / Double(Self.chunkSize)))

        // ── Init upload ───────────────────────────────────────────────────────
        let initReq = FileInitRequest(
            name: fileName,
            mimeType: mimeType,
            totalSize: Int64(data.count),
            chunkSize: Self.chunkSize,
            fileHash: fileHash,
            transferMode: transferMode(for: data.count),
            forceRelay: false
        )
        let initResp = try await authService.initFileUpload(initReq)
        let fileId = initResp.fileId
        uploads[fileURL] = fileId

        // ── Check for existing progress (resume) ──────────────────────────────
        let statusResp = try? await authService.getFileUploadStatus(fileId: fileId)
        let missingIndices = Set(statusResp?.missingChunks ?? Array(0..<chunkCount))

        // ── Upload chunks ─────────────────────────────────────────────────────
        var uploaded = chunkCount - missingIndices.count
        for index in missingIndices.sorted() {
            let start = index * Self.chunkSize
            let end = min(start + Self.chunkSize, data.count)
            let chunk = data[start..<end]
            let chunkHash = sha256Hex(Data(chunk))

            try await api.uploadChunk(
                fileId: fileId,
                chunkIndex: index,
                data: Data(chunk),
                chunkHash: chunkHash
            )
            uploaded += 1
            onProgress?(Double(uploaded) / Double(chunkCount))
        }

        // ── Complete ──────────────────────────────────────────────────────────
        let result = try await authService.completeFileUpload(fileId: fileId)
        uploads.removeValue(forKey: fileURL)
        return result
    }

    // ── Download ──────────────────────────────────────────────────────────────

    /// Downloads a file to the user's Downloads directory.
    func download(
        fileId: String,
        fileName: String,
        onProgress: @escaping TransferProgressHandler,
        onComplete: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                let url = try await downloadAsync(fileId: fileId, fileName: fileName, onProgress: onProgress)
                await MainActor.run { onComplete(.success(url)) }
            } catch {
                await MainActor.run { onComplete(.failure(error)) }
            }
        }
    }

    func downloadAsync(
        fileId: String,
        fileName: String,
        onProgress: TransferProgressHandler? = nil
    ) async throws -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destination = downloads.appendingPathComponent(fileName)

        // If file exists, generate unique name.
        let finalDest = uniqueURL(for: destination)

        onProgress?(0)
        try await api.downloadFile(fileId: fileId, to: finalDest)
        _ = try? await authService.markFileDelivered(id: fileId)
        onProgress?(1)
        return finalDest
    }

    /// Picks relay vs webrtc based on global size rules (server enforces >1 GB).
    private func transferMode(for byteCount: Int) -> String {
        let mb100 = 100 * 1024 * 1024
        if byteCount <= mb100 { return "relay" }
        return "webrtc"
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func uniqueURL(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 1
        var candidate: URL
        repeat {
            let newName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            candidate = url.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }
}

// ── MIME type detection ───────────────────────────────────────────────────────

private func mimeType(for url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "jpg", "jpeg": return "image/jpeg"
    case "png":         return "image/png"
    case "gif":         return "image/gif"
    case "webp":        return "image/webp"
    case "heic":        return "image/heic"
    case "mp4":         return "video/mp4"
    case "mov":         return "video/quicktime"
    case "webm":        return "video/webm"
    case "mkv":         return "video/x-matroska"
    case "pdf":         return "application/pdf"
    case "doc":         return "application/msword"
    case "docx":        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    case "xls":         return "application/vnd.ms-excel"
    case "xlsx":        return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    case "ppt":         return "application/vnd.ms-powerpoint"
    case "pptx":        return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    case "txt":         return "text/plain"
    case "md":          return "text/markdown"
    case "csv":         return "text/csv"
    case "zip":         return "application/zip"
    case "gz":          return "application/gzip"
    case "tar":         return "application/x-tar"
    case "7z":          return "application/x-7z-compressed"
    default:            return "application/octet-stream"
    }
}

// ── Crypto helpers ────────────────────────────────────────────────────────────

private func sha256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0) }.joined()
}
