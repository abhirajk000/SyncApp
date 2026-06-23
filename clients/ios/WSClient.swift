// WSClient.swift
// WebSocket push for clipboard.new while app is active.

import Foundation

@MainActor
final class WSClient: ObservableObject {
    @Published var isConnected = false

    var onClipboardNew: ((ClipboardEntry) -> Void)?
    var onClipboardPin: ((String, Bool) -> Void)?
    var onFilesUpdated: (() -> Void)?

    private var task: URLSessionWebSocketTask?
    private var receiveLoop = false
    private var reconnectTask: Task<Void, Never>?
    private var reconnectStep = 0
    private let reconnectSteps: [UInt64] = [1_000_000_000, 2_000_000_000, 5_000_000_000, 10_000_000_000]
    private var accessToken = ""
    private var serverURL = ""

    func connect(accessToken: String, serverURL: String) {
        self.accessToken = accessToken
        self.serverURL = serverURL
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectStep = 0
        openSocket()
    }

    func disconnect() {
        receiveLoop = false
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectStep = 0
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    private func openSocket() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil

        let base = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let wsBase = base.replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: "\(wsBase)/ws?token=\(accessToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? accessToken)") else {
            scheduleReconnect()
            return
        }

        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        receiveLoop = true
        isConnected = true
        reconnectStep = 0
        listen()
        startHeartbeat()
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
                    if self.receiveLoop {
                        self.scheduleReconnect()
                    }
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        if type == "pong" { return }

        if !isConnected {
            isConnected = true
            reconnectStep = 0
        }

        if type == "clipboard.new",
           let payload = json["payload"] as? [String: Any],
           let id = payload["entry_id"] as? String {
            let contentType = payload["content_type"] as? String ?? "text/plain"
            let content = payload["content"] as? String ?? ""
            let hasThumbnail = payload["has_thumbnail"] as? Bool ?? contentType.hasPrefix("image/")
            guard !content.isEmpty || hasThumbnail else { return }
            let entry = ClipboardEntry(
                id: id,
                content: content,
                contentType: contentType,
                createdAt: payload["created_at"] as? String ?? ISO8601DateFormatter().string(from: Date()),
                pinned: payload["pinned"] as? Bool ?? false,
                hasThumbnail: hasThumbnail,
                sourceDeviceId: payload["source_device_id"] as? String ?? ""
            )
            onClipboardNew?(entry)
        }

        if type == "clipboard.pin",
           let payload = json["payload"] as? [String: Any],
           let entryId = payload["entry_id"] as? String {
            let pinned = payload["pinned"] as? Bool ?? false
            onClipboardPin?(entryId, pinned)
        }

        if type == "file.ready" || type == "file.progress" {
            onFilesUpdated?()
        }
    }

    private func scheduleReconnect() {
        guard receiveLoop, reconnectTask == nil else { return }
        reconnectTask = Task { @MainActor in
            while receiveLoop && !Task.isCancelled {
                let delay = reconnectSteps[min(reconnectStep, reconnectSteps.count - 1)]
                reconnectStep = min(reconnectStep + 1, reconnectSteps.count - 1)
                try? await Task.sleep(nanoseconds: delay)
                guard receiveLoop, !Task.isCancelled else { return }
                openSocket()
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if isConnected { return }
            }
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
    var hasThumbnail: Bool = false
    var sourceDeviceId: String = ""
}
