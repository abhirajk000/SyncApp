// LocalSendProtocol.swift — P2P LAN transfer control + chunk framing (no cloud).

import Foundation

enum LocalSendProtocol {
    static let serviceType = "_syncbridge-localsend._tcp"
    static let chunkSize = 4 * 1024 * 1024
    private static let chunkMagic: [UInt8] = [0x53, 0x42, 0x4C, 0x53] // SBLS

    struct FileEntry: Codable {
        let index: Int
        let name: String
        let relativePath: String
        let size: Int64
    }

    struct Offer: Codable {
        let op: String
        let id: String
        let sender: String
        let files: [FileEntry]

        init(id: String, sender: String, files: [FileEntry]) {
            op = "offer"
            self.id = id
            self.sender = sender
            self.files = files
        }
    }

    struct Accept: Codable {
        let op: String
        let id: String
        init(id: String) { op = "accept"; self.id = id }
    }

    struct Reject: Codable {
        let op: String
        let id: String
        let reason: String
        init(id: String, reason: String) { op = "reject"; self.id = id; self.reason = reason }
    }

    struct FileBegin: Codable {
        let op: String
        let id: String
        let index: Int
        let offset: Int64
        init(id: String, index: Int, offset: Int64) {
            op = "file_begin"; self.id = id; self.index = index; self.offset = offset
        }
    }

    struct FileEnd: Codable {
        let op: String
        let id: String
        let index: Int
        init(id: String, index: Int) { op = "file_end"; self.id = id; self.index = index }
    }

    struct Complete: Codable {
        let op: String
        let id: String
        init(id: String) { op = "complete"; self.id = id }
    }

    struct Resume: Codable {
        struct Entry: Codable {
            let index: Int
            let offset: Int64
        }
        let op: String
        let id: String
        let files: [Entry]
        init(id: String, files: [Entry]) { op = "resume"; self.id = id; self.files = files }
    }

    static func encodeLine<T: Encodable>(_ value: T) throws -> Data {
        var data = try JSONEncoder().encode(value)
        data.append(0x0A)
        return data
    }

    static func parseOp(_ line: String) -> (op: String, json: [String: Any])? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let op = json["op"] as? String else { return nil }
        return (op, json)
    }

    static func resumeOffsets(from json: [String: Any]) -> [Int: Int64] {
        guard let files = json["files"] as? [[String: Any]] else { return [:] }
        var out: [Int: Int64] = [:]
        for f in files {
            if let idx = f["index"] as? Int, let off = f["offset"] as? Int64 {
                out[idx] = off
            }
        }
        return out
    }
}
