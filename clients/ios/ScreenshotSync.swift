// ScreenshotSync.swift — Upload the latest screenshot when the app opens (iOS has no clipboard in background).

import Photos
import UIKit

enum ScreenshotSync {
    private static let lastAssetIdKey = "com.syncbridge.lastScreenshotAssetId"

    static func syncLatestScreenshot(
        upload: @escaping (String, String) async throws -> Void
    ) async {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else { return }

        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )
        guard let collection = collections.firstObject else { return }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        let assets = PHAsset.fetchAssets(in: collection, options: options)
        guard let asset = assets.firstObject else { return }

        let assetId = asset.localIdentifier
        if assetId == UserDefaults.standard.string(forKey: lastAssetIdKey) { return }

        let data = await loadImageData(for: asset)
        guard let data,
              let encoded = ClipboardImageCodec.encodeImageData(data) else { return }

        do {
            try await upload(encoded.0, encoded.1)
            UserDefaults.standard.set(assetId, forKey: lastAssetIdKey)
        } catch {
            // Retry on next foreground.
        }
    }

    private static func loadImageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
