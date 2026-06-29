// ImageThumbDecode.swift — Downsampled decode for list thumbnails (low RAM)

import Foundation
import ImageIO
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

enum ImageThumbDecode {
    static let maxEdge: CGFloat = 512

    static func decode(_ data: Data, maxEdge: CGFloat = maxEdge) -> PlatformImage? {
        guard !data.isEmpty else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
        else {
            #if os(iOS)
            return UIImage(data: data)
            #else
            return NSImage(data: data)
            #endif
        }
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #else
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }
}
