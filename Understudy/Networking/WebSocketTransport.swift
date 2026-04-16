//
//  WebSocketTransport.swift
//  Understudy
//
//  URLSessionWebSocketTask-based transport. Talks to the Python relay in
//  /relay/server.py and exchanges the exact same Envelope JSON we use over
//  MultipeerConnectivity. Auto-reconnects with exponential backoff.
//

import Foundation

public final class WebSocketTransport: NSObject, Transport {
    public var onMessage: ((Envelope) -> Void)?
    public var onPeerCountChanged: ((Int) -> Void)?

    /// "ws://host:8765"  (we append ?room=&id=&name= ourselves).
    private let baseURLString: String

    private var task: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var localID: ID = ID()
    private var displayName: String = "anon"
    private var roomCode: String = "default"
    private var shouldReconnect = false
    private var backoffSeconds: Double = 1.0
    private var peerCount: Int = 0

    public init(baseURL: String) {
        self.baseURLString = baseURL
    }

    public func start(roomCode: String, localID: ID, displayName: String) {
        self.roomCode = roomCode
        self.localID = localID
        self.displayName = displayName
        self.shouldReconnect = true
        connect()
    }

    public func stop() {
        shouldReconnect = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    public func send(_ message: NetMessage, from senderID: ID) {
        guard let task else { return }
        let envelope = Envelope(senderID: senderID, message: message)
        guard let data = try? WireCoding.encoder.encode(envelope),
              let s = String(data: data, encoding: .utf8) else { return }
        task.send(.string(s)) { _ in /* best-effort; reconnect handles failures */ }
    }

    // MARK: - Internals

    private func connect() {
        guard shouldReconnect else { return }
        guard var components = URLComponents(string: baseURLString) else { return }
        // Compose query.
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "room", value: roomCode))
        items.append(URLQueryItem(name: "id",   value: localID.raw))
        items.append(URLQueryItem(name: "name", value: displayName))
        components.queryItems = items
        guard let url = components.url else { return }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let newTask = session.webSocketTask(with: url)
        self.urlSession = session
        self.task = newTask
        newTask.resume()
        listen()
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                self.handle(msg)
                self.listen()
            case .failure:
                self.scheduleReconnect()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let s): text = s
        case .data(let d):   text = String(data: d, encoding: .utf8) ?? ""
        @unknown default: return
        }
        guard let data = text.data(using: .utf8) else { return }

        // Relay welcome frames come as { "_relay": "welcome", "peers": N }.
        if let any = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           (any["_relay"] as? String) == "welcome",
           let peers = any["peers"] as? Int {
            self.peerCount = max(0, peers - 1) // subtract self
            onPeerCountChanged?(self.peerCount)
            return
        }
        guard let env = try? WireCoding.decoder.decode(Envelope.self, from: data) else { return }
        guard env.version == Envelope.currentVersion else { return }
        onMessage?(env)
    }

    private func scheduleReconnect() {
        task = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        guard shouldReconnect else { return }
        let delay = min(backoffSeconds, 15.0)
        backoffSeconds = min(backoffSeconds * 2, 15.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }
}

extension WebSocketTransport: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didOpenWithProtocol protocol: String?) {
        backoffSeconds = 1.0
    }
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                           reason: Data?) {
        peerCount = 0
        onPeerCountChanged?(0)
        scheduleReconnect()
    }
}
