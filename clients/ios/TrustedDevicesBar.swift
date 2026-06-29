// TrustedDevicesBar.swift — Online device chips

import SwiftUI

struct DeviceItem: Identifiable, Decodable {
    let id: String
    let name: String
    let platform: String
    let online: Bool
    let isCurrent: Bool
    let lastSeenAt: String?
    let trustedUntil: String?

    enum CodingKeys: String, CodingKey {
        case id, name, platform, online
        case isCurrent = "is_current"
        case lastSeenAt = "last_seen_at"
        case trustedUntil = "trusted_until"
    }
}

enum DeviceAPI {
    static func fetchDevices(serverURL: String, accessToken: String) async throws -> [DeviceItem] {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/devices") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let devices = json["devices"] as? [[String: Any]] ?? []
        let decoder = JSONDecoder()
        return try devices.map { dict in
            let itemData = try JSONSerialization.data(withJSONObject: dict)
            return try decoder.decode(DeviceItem.self, from: itemData)
        }
    }

    static func renameDevice(serverURL: String, accessToken: String, id: String, name: String) async throws {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/devices/\(id)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func trustDevice(serverURL: String, accessToken: String, id: String) async throws {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/devices/\(id)/trust") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func revokeDevice(serverURL: String, accessToken: String, id: String) async throws {
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/v1/devices/\(id)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

func isDeviceTrusted(_ device: DeviceItem) -> Bool {
    guard let until = device.trustedUntil else { return false }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: until) ?? ISO8601DateFormatter().date(from: until) {
        return date > Date()
    }
    return false
}

struct TrustedDevicesBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let serverURL: String
    let accessToken: String?

    @State private var devices: [DeviceItem] = []

    var body: some View {
        Group {
            let visible = devices.filter { !$0.isCurrent }
            if visible.isEmpty {
                EmptyView()
            } else {
                AppCard {
                    AppSectionTitle(title: "Trusted devices")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SyncTokens.space2) {
                            ForEach(visible) { device in
                                devicePill(device)
                            }
                        }
                    }
                }
            }
        }
        .task(id: accessToken) { await load() }
    }

    private func devicePill(_ device: DeviceItem) -> some View {
        HStack(spacing: SyncTokens.space2) {
            Circle()
                .fill(device.online ? SyncTokens.success : SyncTokens.slateMuted.opacity(0.5))
                .frame(width: 8, height: 8)
            Image(systemName: platformIcon(device.platform))
                .font(.system(size: 14))
                .foregroundStyle(SyncTokens.slateSecondary)
            Text(device.name)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, SyncTokens.space4)
        .padding(.vertical, SyncTokens.space2)
        .background(AppSurfaces.surfaceVariant(colorScheme).opacity(0.5))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1))
    }

    private func platformIcon(_ platform: String) -> String {
        switch platform {
        case "macos": return "desktopcomputer"
        case "ios": return "iphone"
        case "web": return "globe"
        default: return "candybarphone"
        }
    }

    func load() async {
        guard let token = accessToken else { return }
        if let list = try? await DeviceAPI.fetchDevices(serverURL: serverURL, accessToken: token) {
            devices = list
        }
    }
}
