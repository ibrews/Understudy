//
//  SessionController.swift
//  Understudy
//
//  Glue: BlockingStore <-> Transport. Converts store mutations into net messages
//  and applies incoming messages back to the store.
//

import Foundation
import Observation

public enum TransportKind: String, CaseIterable, Sendable {
    case multipeer  // MPC on LAN/Bluetooth — Apple ↔ Apple only
    case websocket  // relay-mediated — talks to Android too
}

@Observable
@MainActor
public final class SessionController {
    public private(set) var transport: Transport
    public let store: BlockingStore
    public private(set) var peerCount: Int = 0
    public var roomCode: String = "default" {
        didSet {
            if isRunning { restart() }
        }
    }
    public private(set) var isRunning: Bool = false
    /// Which transport is currently in use.
    public private(set) var transportKind: TransportKind
    /// ws://host:port — only used when transportKind == .websocket.
    public var relayURL: String = "ws://127.0.0.1:8765"
    /// Tick counter for throttling pose updates.
    private var poseTickCounter: Int = 0

    public init(
        transport: Transport,
        kind: TransportKind,
        store: BlockingStore,
        roomCode: String = "default"
    ) {
        self.transport = transport
        self.transportKind = kind
        self.store = store
        self.roomCode = roomCode
        wireCallbacks()
    }

    private func wireCallbacks() {
        self.transport.onMessage = { [weak self] env in
            Task { @MainActor in self?.handle(env) }
        }
        self.transport.onPeerCountChanged = { [weak self] n in
            Task { @MainActor in self?.peerCount = n }
        }
    }

    /// Swap the underlying transport at runtime (e.g. toggle Multipeer ↔ WebSocket).
    public func switchTransport(to kind: TransportKind) {
        if kind == transportKind { return }
        let wasRunning = isRunning
        if wasRunning { stop() }
        switch kind {
        case .multipeer:
            self.transport = MultipeerTransport()
        case .websocket:
            self.transport = WebSocketTransport(baseURL: relayURL)
        }
        self.transportKind = kind
        wireCallbacks()
        if wasRunning { start() }
    }

    public func start() {
        guard let me = store.localPerformer else { return }
        transport.start(roomCode: roomCode, localID: me.id, displayName: me.displayName)
        isRunning = true
        // Announce ourselves and, if we have a blocking, share it.
        transport.send(.hello(me), from: me.id)
        if !store.blocking.marks.isEmpty {
            transport.send(.blockingSnapshot(store.blocking), from: me.id)
        }
    }

    public func stop() {
        transport.stop()
        isRunning = false
    }

    private func restart() {
        stop(); start()
    }

    // MARK: - Outbound

    /// Call when the local performer's pose changes. Throttled to ~10 Hz to
    /// avoid saturating MPC on crowded LANs.
    public func broadcastLocalPose() {
        guard let me = store.localPerformer else { return }
        poseTickCounter += 1
        if poseTickCounter % 3 != 0 { return } // assume ~30Hz callers
        transport.send(.performerUpdate(me), from: me.id)
    }

    public func broadcastMarkAdded(_ mark: Mark) {
        guard let me = store.localPerformer else { return }
        transport.send(.markAdded(mark), from: me.id)
    }

    public func broadcastMarkUpdated(_ mark: Mark) {
        guard let me = store.localPerformer else { return }
        transport.send(.markUpdated(mark), from: me.id)
    }

    public func broadcastMarkRemoved(_ id: ID) {
        guard let me = store.localPerformer else { return }
        transport.send(.markRemoved(id), from: me.id)
    }

    public func broadcastPlayback(t: Double?) {
        guard let me = store.localPerformer else { return }
        transport.send(.playbackState(t: t), from: me.id)
    }

    // MARK: - Inbound

    private func handle(_ env: Envelope) {
        switch env.message {
        case .hello(let p):
            store.upsertPerformer(p)
            // If we're the director (have marks), send a snapshot to the newcomer.
            if let me = store.localPerformer, me.role == .director, !store.blocking.marks.isEmpty {
                transport.send(.blockingSnapshot(store.blocking), from: me.id)
            }
        case .goodbye(let id):
            store.removePerformer(id: id)
        case .performerUpdate(let p):
            store.upsertPerformer(p)
        case .blockingSnapshot(let b):
            // Prefer newer snapshots; ignore older.
            if b.modifiedAt >= store.blocking.modifiedAt {
                store.blocking = b
            }
        case .markAdded(let m):
            if !store.blocking.marks.contains(where: { $0.id == m.id }) {
                store.blocking.marks.append(m)
                store.blocking.modifiedAt = Date()
            }
        case .markUpdated(let m):
            store.updateMark(m)
        case .markRemoved(let id):
            store.removeMark(id: id)
        case .cueFired(_, _, _):
            // Currently every device computes its own cue firings from pose,
            // so we don't re-apply remote firings. Reserved for future FX sync.
            break
        case .playbackState(let t):
            store.playbackT = t
        }
    }
}
