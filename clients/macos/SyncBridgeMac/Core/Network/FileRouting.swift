// FileRouting.swift — automatic file transfer routing (clipboard uses relay separately).

import Foundation

enum FileRouting {
    static let relayMaxBytes = 100 * 1024 * 1024

    static func resolve(
        fileSizeBytes: Int,
        fileCount: Int = 1,
        isFolder: Bool = false
    ) -> (transferMode: String, route: String, fallback: String?) {
        let attemptWebRtc = fileSizeBytes > relayMaxBytes || fileCount > 1 || isFolder
        if !attemptWebRtc {
            return ("relay", "cloud", nil)
        }
        return (
            "webrtc",
            "webrtc",
            "WebRTC attempted — automatic relay fallback if P2P unavailable"
        )
    }
}
