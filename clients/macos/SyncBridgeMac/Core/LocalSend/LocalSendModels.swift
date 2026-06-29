// LocalSendModels.swift

import Foundation

struct LocalPeer: Identifiable, Equatable {
    let id: String
    let name: String
    let platform: String
    let host: String
    let port: Int
}

enum LocalTransferPhase: String {
    case idle, connecting, waitingAccept, transferring, paused, completed, failed
}

enum LocalTransferDirection { case sending, receiving }

struct LocalFileProgress: Identifiable {
    let index: Int
    let name: String
    let size: Int64
    var transferred: Int64

    var id: Int { index }
    var percent: Double { size > 0 ? Double(transferred) / Double(size) : 0 }
    var remaining: Int64 { max(0, size - transferred) }
}

struct LocalTransferProgress: Identifiable {
    let transferId: String
    let peerName: String
    let direction: LocalTransferDirection
    var phase: LocalTransferPhase
    var files: [LocalFileProgress]
    var speedBytesPerSec: Int64 = 0
    var error: String?

    var id: String { transferId }
}

struct IncomingLocalOffer: Identifiable {
    let offer: LocalSendProtocol.Offer
    let peer: LocalPeer
    var id: String { offer.id }
}
