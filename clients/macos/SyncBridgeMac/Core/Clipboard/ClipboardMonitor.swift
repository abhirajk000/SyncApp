// ClipboardMonitor.swift
// Watches NSPasteboard for changes and syncs new content to the server.
//
// Design:
//   • Polls `NSPasteboard.general.changeCount` every 100 ms — event-driven via
//     changeCount (no full scheduled sync; lowest-latency approach on macOS).
//   • SHA-256 deduplication: only syncs if the content hash changed since the
//     last successful sync.
//   • Echo suppression: when the monitor writes to the pasteboard (in response
//     to a clipboard.new WS event from another device), it sets a suppression
//     flag for 500 ms so it doesn't re-upload the same content.
//   • Supported content types: text/plain, text/uri-list, text/html, and
//     image/* (converted to PNG or JPEG for the server allowlist).

import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

final class ClipboardMonitor {

    // MARK: – Public interface

    /// Called on main queue when a new entry arrives from another device.
    var onRemoteEntry: ((ClipboardEntryResponse) -> Void)?

    /// Called on main queue after this device successfully uploads clipboard content.
    var onLocalSync: ((ClipboardEntryResponse) -> Void)?

    // MARK: – Private

    private let authService: AuthService
    private let keychain = KeychainService.shared
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.syncbridge.clipboard", qos: .utility)
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastSyncedHash: String = ""
    private var suppressUntil: Date = .distantPast
    private var lastLocalUserCopyAt: Date = .distantPast
    private var isSyncing = false

    /// When false, local clipboard is not uploaded.
    var autoSyncEnabled = true
    /// When false, image/* content is not uploaded.
    var autoSyncImagesEnabled = true

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: – Lifecycle

    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.1, repeating: 0.1)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: – Remote clipboard update (called by WSClient handler)

    /// Writes a clipboard entry received from another device into the local pasteboard.
    func applyRemoteEntry(_ entry: ClipboardEntryResponse) {
        suppressUntil = Date().addingTimeInterval(3.0)

        DispatchQueue.main.async {
            let pb = NSPasteboard.general
            pb.clearContents()

            if entry.contentType.hasPrefix("image/"),
               let data = Data(base64Encoded: entry.content.trimmingCharacters(in: .whitespacesAndNewlines)),
               let image = NSImage(data: data) {
                pb.writeObjects([image])
                self.lastSyncedHash = sha256Data(data)
            } else {
                switch entry.contentType {
                case "text/plain", "text/uri-list":
                    pb.setString(entry.content, forType: .string)
                    if entry.contentType == "text/uri-list",
                       let url = URL(string: entry.content) {
                        pb.setString(entry.content, forType: .URL)
                        pb.writeObjects([url as NSURL])
                    }
                case "text/html":
                    if let data = entry.content.data(using: .utf8) {
                        pb.setData(data, forType: .html)
                    }
                    pb.setString(entry.content, forType: .string)
                default:
                    pb.setString(entry.content, forType: .string)
                }
                self.lastSyncedHash = sha256(entry.content)
            }
            self.lastChangeCount = pb.changeCount
        }

        onRemoteEntry?(entry)
    }

    /// Own-device WS echo — update hash without writing clipboard again.
    func rememberSyncedEntry(_ entry: ClipboardEntryResponse) {
        let hash: String
        if entry.contentType.hasPrefix("image/"),
           let data = Data(base64Encoded: entry.content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            hash = sha256Data(data)
        } else {
            hash = sha256(entry.content)
        }
        lastSyncedHash = hash
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func shouldAutoApplyRemote(
        _ entry: ClipboardEntryResponse,
        localDeviceId: String,
        forceCatchUp: Bool = false
    ) -> Bool {
        if entry.sourceDeviceId == localDeviceId { return false }
        if !forceCatchUp && entry.sourceDeviceId.isEmpty { return false }
        if entry.contentType.hasPrefix("image/"), !autoSyncImagesEnabled { return false }

        let hash: String
        if entry.contentType.hasPrefix("image/"),
           let data = Data(base64Encoded: entry.content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            hash = sha256Data(data)
        } else {
            hash = sha256(entry.content)
        }
        if !forceCatchUp && hash == lastSyncedHash { return false }
        if !forceCatchUp && Date().timeIntervalSince(lastLocalUserCopyAt) < 4 { return false }
        return true
    }

    // MARK: – Private: polling

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }

        DispatchQueue.main.async { [weak self] in
            self?.handlePasteboardChange(expectedCount: current)
        }
    }

    private func handlePasteboardChange(expectedCount: Int) {
        let pb = NSPasteboard.general
        let current = pb.changeCount
        guard current == expectedCount else {
            lastChangeCount = current
            return
        }
        lastChangeCount = current

        guard Date() > suppressUntil else { return }
        lastLocalUserCopyAt = Date()

        guard autoSyncEnabled else { return }
        guard let (content, contentType) = readPasteboard(pb) else { return }
        if contentType.hasPrefix("image/"), !autoSyncImagesEnabled { return }

        let hash: String
        if contentType.hasPrefix("image/"), let data = Data(base64Encoded: content) {
            hash = sha256Data(data)
        } else {
            hash = sha256(content)
        }
        guard hash != lastSyncedHash else { return }
        lastSyncedHash = hash

        guard keychain.isAuthenticated, !isSyncing else { return }
        isSyncing = true

        Task {
            defer { self.isSyncing = false }
            do {
                let entry = try await self.authService.syncClipboard(
                    contentType: contentType,
                    content: content
                )
                DispatchQueue.main.async {
                    self.onLocalSync?(entry)
                }
            } catch {
                // Allow retry on the next distinct clipboard change.
                self.lastSyncedHash = ""
            }
        }
    }

    // MARK: – Pasteboard reading

    private func readPasteboard(_ pb: NSPasteboard) -> (String, String)? {
        if let imageData = readImageData(from: pb) {
            return imageData
        }
        if let html = pb.string(forType: .html), !html.isEmpty {
            return (html, "text/html")
        }
        if let str = pb.string(forType: .string), !str.isEmpty {
            if URL(string: str) != nil, str.hasPrefix("http") {
                return (str, "text/uri-list")
            }
            return (str, "text/plain")
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first,
           first.isFileURL == false {
            return (first.absoluteString, "text/uri-list")
        }
        return nil
    }

    private static let maxImageBytes = 7 * 1024 * 1024
    private static let uploadTargetBytes = 2_000_000
    private static let maxUploadDimension: CGFloat = 1920

    private func readImageData(from pb: NSPasteboard) -> (String, String)? {
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let encoded = encodeImage(image) {
            return encoded
        }

        var types: [NSPasteboard.PasteboardType] = [.png, .tiff]
        types.append(contentsOf: [
            NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            NSPasteboard.PasteboardType(UTType.heic.identifier),
            NSPasteboard.PasteboardType(UTType.heif.identifier),
            NSPasteboard.PasteboardType(UTType.gif.identifier),
            NSPasteboard.PasteboardType(UTType.webP.identifier),
            NSPasteboard.PasteboardType("com.apple.pict"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
        ])

        var seen = Set<String>()
        for type in pb.types ?? [] where type != .string && type != .html && type != .URL {
            if seen.insert(type.rawValue).inserted {
                types.append(type)
            }
        }

        for type in types {
            guard let data = pb.data(forType: type), !data.isEmpty else { continue }
            if let encoded = encodeImageData(data) {
                return encoded
            }
        }

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls where url.isFileURL {
                guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
                      !data.isEmpty,
                      let encoded = encodeImageData(data) else { continue }
                return encoded
            }
        }

        return nil
    }

    private func encodeImage(_ image: NSImage) -> (String, String)? {
        guard let jpeg = compressImageForUpload(image) else { return nil }
        return (jpeg.base64EncodedString(), "image/jpeg")
    }

    private func encodeImageData(_ data: Data) -> (String, String)? {
        if let jpeg = compressImageDataForUpload(data) {
            return (jpeg.base64EncodedString(), "image/jpeg")
        }

        guard let converted = convertToUploadableImage(data) else { return nil }
        guard converted.count <= Self.maxImageBytes else { return nil }
        let mime = sniffImageMime(converted) == "image/jpeg" ? "image/jpeg" : "image/png"
        return (converted.base64EncodedString(), mime)
    }

    private func compressImageForUpload(_ image: NSImage) -> Data? {
        guard let cgImage = cgImage(from: image) else { return nil }
        let scaled = scaleCGImage(cgImage, maxDimension: Self.maxUploadDimension)
        return jpegData(from: scaled, maxBytes: Self.uploadTargetBytes)
    }

    private func compressImageDataForUpload(_ data: Data) -> Data? {
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            let scaled = scaleCGImage(cgImage, maxDimension: Self.maxUploadDimension)
            return jpegData(from: scaled, maxBytes: Self.uploadTargetBytes)
        }
        guard let image = NSImage(data: data) else { return nil }
        return compressImageForUpload(image)
    }

    private func cgImage(from image: NSImage) -> CGImage? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.cgImage
    }

    private func scaleCGImage(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        let largest = max(w, h)
        guard largest > maxDimension else { return image }

        let scale = maxDimension / largest
        let nw = max(1, Int(w * scale))
        let nh = max(1, Int(h * scale))
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
                data: nil,
                width: nw,
                height: nh,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        return ctx.makeImage() ?? image
    }

    private func jpegData(from image: CGImage, maxBytes: Int) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        var quality: CGFloat = 0.85
        while quality >= 0.55 {
            if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]),
               data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.55])
    }

    private func convertToUploadableImage(_ data: Data) -> Data? {
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let png = rep.representation(using: .png, properties: [:]), png.count <= Self.maxImageBytes {
                return png
            }
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88])
        }

        guard let image = NSImage(data: data) else { return nil }
        return pngData(from: image) ?? jpegData(from: image, quality: 0.88)
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff) else { return nil }
            return rep.representation(using: .png, properties: [:])
        }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }

    private func jpegData(from image: NSImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff) else { return nil }
            return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    private func sniffImageMime(_ data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
        if String(data: Data(bytes[0..<4]), encoding: .ascii) == "RIFF",
           String(data: Data(bytes[8..<12]), encoding: .ascii) == "WEBP" { return "image/webp" }
        if bytes.starts(with: [0x00, 0x00, 0x00]) && (bytes[4] == 0x66 || bytes[4] == 0x68) { return "image/heic" }
        return nil
    }
}

// MARK: – SHA-256 helper

private func sha256(_ input: String) -> String {
    sha256Data(Data(input.utf8))
}

private func sha256Data(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0) }.joined()
}
