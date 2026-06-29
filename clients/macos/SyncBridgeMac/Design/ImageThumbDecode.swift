// ImageThumbDecode.swift — Downsampled decode for list thumbnails (low RAM)

import AppKit
import Foundation
import ImageIO

enum ImageThumbDecode {
    static let maxEdge: CGFloat = 512

    static func decode(_ data: Data, maxEdge: CGFloat = maxEdge) -> NSImage? {
        guard !data.isEmpty else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
        else {
            return NSImage(data: data)
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
