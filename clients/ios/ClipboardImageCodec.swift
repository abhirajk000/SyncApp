// ClipboardImageCodec.swift — Shared JPEG compression for clipboard image uploads.

import UIKit
import UniformTypeIdentifiers

enum ClipboardImageCodec {
    private static let uploadTargetBytes = 2_000_000
    private static let maxUploadDimension: CGFloat = 1920

    static func encodePasteboardImage(_ image: UIImage) -> (String, String)? {
        guard let jpeg = compress(image) else { return nil }
        return (jpeg.base64EncodedString(), "image/jpeg")
    }

    static func encodeImageData(_ data: Data) -> (String, String)? {
        if let image = UIImage(data: data) {
            return encodePasteboardImage(image)
        }
        return nil
    }

    static func decodeImageData(from entry: ClipboardEntry) -> Data? {
        let raw = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let b64 = raw.hasPrefix("data:") ? String(raw.split(separator: ",").last ?? "") : raw
        return Data(base64Encoded: b64)
    }

    private static func compress(_ image: UIImage) -> Data? {
        let scaled = scale(image, maxDimension: maxUploadDimension)
        var quality: CGFloat = 0.85
        var data = scaled.jpegData(compressionQuality: quality)
        while let current = data, current.count > uploadTargetBytes, quality > 0.55 {
            quality -= 0.1
            data = scaled.jpegData(compressionQuality: quality)
        }
        return data
    }

    private static func scale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
