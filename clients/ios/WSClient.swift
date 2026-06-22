// WSClient.swift
// WebSocket push for clipboard.new while app is active.

import Foundation

@MainActor
final class WSClient: ObservableObject {
    @Published var isConnected = false

    var onClipboardNew: ((ClipboardEntry) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var receiveLoop = false

    func connect(accessToken: String, serverURL: String) {
        disconnect()
        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let wsBase = base.replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: "\(wsBase)/ws?token=\(accessToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? accessToken)") else {
            return
        }

        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        receiveLoop = true
        listen()
        startHeartbeat()
    }

    func disconnect() {
        receiveLoop = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    Task { @MainActor in
                        self.handle(text)
                    }
                }
                if self.receiveLoop {
                    self.listen()
                }
            case .failure:
                Task { @MainActor in
                    self.isConnected = false
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        if type == "pong" { return }

        if type == "clipboard.new",
           let payload = json["payload"] as? [String: Any],
           let id = payload["entry_id"] as? String,
           let content = payload["content"] as? String {
            let entry = ClipboardEntry(
                id: id,
                content: content,
                contentType: payload["content_type"] as? String ?? "text/plain",
                createdAt: payload["created_at"] as? String ?? ISO8601DateFormatter().string(from: Date()),
                pinned: payload["pinned"] as? Bool ?? false
            )
            onClipboardNew?(entry)
        }
    }

    private func startHeartbeat() {
        Task {
            while receiveLoop {
                try? await Task.sleep(nanoseconds: 54_000_000_000)
                task?.send(.string("{\"type\":\"ping\"}")) { _ in }
            }
        }
    }
}

struct ClipboardEntry: Identifiable, Equatable {
    let id: String
    let content: String
    let contentType: String
    let createdAt: String
    let pinned: Bool
}
