//
//  MonitoringIntegration.swift
//  Understudy
//
//  Wires Understudy's BlockingStore + SessionController to the AgileLens
//  fleet Mission Control monitoring protocol. Broadcasts over Bonjour
//  (`_agilelens-mon._tcp`) and streams length-prefixed JSON events to
//  any observer (Mission Control app) that connects.
//
//  Today we copy the Monitoring types directly from the AgileLensMultiplayer
//  Swift Package (see /Users/Shared/Documents/xcodeproj/AVP_Apps/WhoAmI/
//  Packages/AgileLensMultiplayer). Migrating to a proper SPM dependency is
//  a v1.0 cleanup — once Understudy's project file gains other SPM deps.
//
//  What we forward:
//    - playerJoined / playerLeft on hello / goodbye
//    - poseUpdate on every performer update (throttled via SessionController)
//    - gameState snapshots: blocking title + performer count (periodic)
//    - meshChunk when a new room scan is captured / imported
//    - heartbeat every 2 s so observers keep the session pinned
//
//  Mission Control's 2D / 3D / heatmap views use poseUpdate + playerJoined/
//  Left. Laser-tag–specific events (blast, hit, score) don't apply here.
//

#if canImport(UIKit)
import UIKit
#endif
import Foundation

@MainActor
public final class MonitoringIntegration {
    public static let gameType = "understudy"
    public static let shared = MonitoringIntegration()

    private var broadcaster: MonitoringBroadcaster?
    private var heartbeatTask: Task<Void, Never>?
    private weak var store: BlockingStore?

    public var isRunning: Bool { broadcaster?.isRunning ?? false }

    public func start(store: BlockingStore, sessionKey: String) {
        self.store = store
        // Don't start twice.
        if let b = broadcaster, b.isRunning { return }
        let me = store.localPerformer
        let name = me?.displayName ?? "Understudy"
        guard let b = try? MonitoringBroadcaster(
            gameType: Self.gameType,
            sessionID: sessionKey,
            deviceName: name,
            platform: Self.currentPlatformLabel,
            deviceID: me?.id.raw ?? UUID().uuidString
        ) else {
            print("[MonitoringIntegration] Failed to create broadcaster (port conflict?)")
            return
        }
        b.start()
        self.broadcaster = b

        // Announce ourselves.
        if let me {
            b.send(.playerJoined(MonitoringPlayerJoined(
                peerID: Self.uuid(from: me.id),
                displayName: me.displayName,
                colorHex: nil,
                platform: Self.currentPlatformLabel,
                team: nil
            )))
        }

        // Heartbeat + periodic game-state snapshot.
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { self?.broadcaster?.sendHeartbeat() }
                tick += 1
                if tick % 5 == 0 {
                    await MainActor.run { self?.sendGameState() }
                }
            }
        }
    }

    public func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        if let me = store?.localPerformer {
            broadcaster?.send(.playerLeft(MonitoringPlayerLeft(peerID: Self.uuid(from: me.id))))
        }
        broadcaster?.stop()
        broadcaster = nil
    }

    // MARK: - Forwarding

    /// Called by SessionController whenever a performer update goes on the wire.
    public func forwardPoseUpdate(_ performer: Performer) {
        guard let b = broadcaster else { return }
        b.send(.poseUpdate(MonitoringPoseUpdate(
            peerID: Self.uuid(from: performer.id),
            x: performer.pose.x,
            y: performer.pose.y,
            z: performer.pose.z,
            yawAngle: performer.pose.yaw,
            colorComponents: nil,
            platform: Self.currentPlatformLabel,
            displayName: performer.displayName,
            isShielding: nil
        )))
    }

    public func forwardPlayerJoined(_ performer: Performer) {
        broadcaster?.send(.playerJoined(MonitoringPlayerJoined(
            peerID: Self.uuid(from: performer.id),
            displayName: performer.displayName,
            colorHex: nil,
            platform: Self.currentPlatformLabel,
            team: nil
        )))
    }

    public func forwardPlayerLeft(_ id: ID) {
        broadcaster?.send(.playerLeft(MonitoringPlayerLeft(peerID: Self.uuid(from: id))))
    }

    /// Push a brief text snapshot that Mission Control can surface.
    public func sendGameState() {
        guard let store, let me = store.localPerformer else { return }
        broadcaster?.send(.gameState(MonitoringGameState(
            peerID: Self.uuid(from: me.id),
            name: "\(store.blocking.title) — \(store.performers.count) in room",
            colorHex: "#C7232D"
        )))
    }

    /// Forward a room scan as a single mesh chunk. If the scan is large this
    /// will push a lot at once — Mission Control's broadcaster was designed
    /// for this (SharedScanner uses the same path).
    public func forwardRoomScan(_ scan: RoomScan) {
        guard let b = broadcaster, let me = store?.localPerformer else { return }
        let positions = scan.decodePositions()    // flat [Float] xyz
        let indices = scan.decodeIndices()
        // Identity transform — positions are already in world coords.
        let identity: [Float] = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        ]
        b.send(.meshChunk(MonitoringMeshChunk(
            chunkID: UUID(),
            ownerID: Self.uuid(from: me.id),
            vertices: positions,
            indices: indices,
            transform: identity,
            classification: scan.name
        )))
    }

    // MARK: - Helpers

    private static var currentPlatformLabel: String {
        #if os(visionOS)
        return "visionOS"
        #elseif os(iOS)
        return "iOS"
        #else
        return "unknown"
        #endif
    }

    /// Monitoring types use Foundation `UUID`; our `ID` wraps a raw String.
    /// When the raw happens to be a valid UUID, round-trip it; otherwise
    /// derive a stable UUID from its bytes.
    static func uuid(from id: ID) -> UUID {
        if let u = UUID(uuidString: id.raw) { return u }
        // Hash the raw string into a v5-ish synthetic UUID so the same ID
        // maps to the same UUID across sends.
        var bytes = [UInt8](repeating: 0, count: 16)
        let data = Array(id.raw.utf8)
        for (i, b) in data.enumerated() {
            bytes[i % 16] ^= b
        }
        // Set version + variant bits so it looks like a real UUID.
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
