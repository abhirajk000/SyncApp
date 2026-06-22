// WSClient.swift
// Persistent WebSocket connection to the SyncBridge server.
//
// Features:
//   • URLSessionWebSocketTask — no third-party library.
//   • Exponential-backoff reconnect (1 s → 2 → 4 → 8 … 60 s cap).
//   • Application-level heartbeat: sends {"type":"ping"} every 54 s.
//   • NWPathMonitor detects network changes and triggers immediate reconnect.
//   • Dispatches received messages to registered handlers on the main queue.
//   • Thread-safe via an internal serial queue.

import Foundation
import Network

// ── Message handler types ─────────────────────────────────────────────────────

typealias WSMessageHandler = (WSEnvelope) -> Void

// ── WSClient ──────────────────────────────────────────────────────────────────

final class WSClient: NSObject {

    // MARK: – Published state (observe from SwiftUI via AppState)
    private(set) var isConnected: Bool = false {
        didSet { onConnectionChange?(isConnected) }
    }

    // MARK: – Callbacks
    var onConnectionChange: ((Bool) -> Void)?
    var onMessage: WSMessageHandler?
    var onError: ((Error) -> Void)?

    // MARK: – Private
    private let keychain = KeychainService.shared
    private let queue = DispatchQueue(label: "com.syncbridge.wsclient", qos: .utility)
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectDelay: TimeInterval = 1
    private var reconnectTimer: DispatchWorkItem?
    private var heartbeatTimer: DispatchSourceTimer?
    private var pathMonitor: NWPathMonitor?
    private var isStopped = false

    // MARK: – Lifecycle

    /// Connect to the WebSocket endpoint.  Call once on startup; auto-reconnects thereafter.
    func connect() {
        queue.async { [weak self] in
            self?.isStopped = false
            self?.openSocket()
            self?.startPathMonitor()
        }
    }

    /// Permanently disconnect.  Call on logout or app termination.
    func disconnect() {
        queue.async { [weak self] in
            self?.isStopped = true
            self?.cancelReconnect()
            self?.stopHeartbeat()
            self?.task?.cancel(with: .normalClosure, reason: nil)
            self?.task = nil
            self?.pathMonitor?.cancel()
            self?.isConnected = false
        }
    }

    // MARK: – Send

    /// Sends a JSON-encoded envelope.  Fire-and-forget; errors are logged only.
    func send(type: String, payload: [String: Any]? = nil) {
        var body: [String: Any] = [
            "id": UUID().uuidString,
            "type": type
        ]
        if let p = payload { body["payload"] = p }

        guard let data = try? JSONSerialization.data(withJSONObject: body),
              let str = String(data: data, encoding: .utf8) else { return }

        task?.send(.string(str)) { [weak self] error in
            if let error { self?.onError?(error) }
        }
    }

    // MARK: – Private: connection

    private func openSocket() {
        guard let token = keychain.accessToken,
              let rawURL = URL(string: keychain.serverURL) else { return }

        var components = URLComponents(url: rawURL, resolvingAgainstBaseURL: false)!
        components.scheme = rawURL.scheme == "https" ? "wss" : "ws"
        components.path = "/ws"
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        guard let wsURL = components.url else { return }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = urlSession

        let newTask = urlSession.webSocketTask(with: wsURL)
        self.task = newTask
        newTask.resume()
        scheduleReceive()
        startHeartbeat()
    }

    private func scheduleReceive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.scheduleReceive()
            case .failure(let error):
                self.handleDisconnect(error: error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let str):
            guard let d = str.data(using: .utf8) else { return }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            return
        }
        guard let envelope = try? JSONDecoder().decode(WSEnvelope.self, from: data) else { return }

        if envelope.type == "pong" { return } // heartbeat reply — nothing to do

        DispatchQueue.main.async { [weak self] in
            self?.onMessage?(envelope)
        }
    }

    private func handleDisconnect(error: Error?) {
        isConnected = false
        stopHeartbeat()
        task = nil
        session = nil
        guard !isStopped else { return }
        scheduleReconnect()
    }

    // MARK: – Reconnect

    private func scheduleReconnect() {
        cancelReconnect()
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 60)

        let item = DispatchWorkItem { [weak self] in
            self?.openSocket()
        }
        reconnectTimer = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelReconnect() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    private func resetBackoff() {
        reconnectDelay = 1
    }

    // MARK: – Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 54, repeating: 54)
        timer.setEventHandler { [weak self] in
            self?.send(type: "ping")
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    // MARK: – Network path monitor

    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            if path.status == .satisfied && !self.isConnected && !self.isStopped {
                self.queue.async {
                    self.cancelReconnect()
                    self.resetBackoff()
                    self.openSocket()
                }
            }
        }
        monitor.start(queue: queue)
        pathMonitor = monitor
    }
}

// MARK: – URLSessionWebSocketDelegate

extension WSClient: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        queue.async { [weak self] in
            self?.isConnected = true
            self?.resetBackoff()
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        handleDisconnect(error: nil)
    }
}
