//
//  Transport.swift
//  Understudy
//
//  Pluggable transport. MultipeerConnectivity for Apple-to-Apple on LAN.
//  An Android/WebSocket impl can be added later without touching the app logic.
//

import Foundation

/// A wire-level message. Small, serializable, versioned.
/// NOTE: when changing this enum, bump `Envelope.version` so older peers can drop
/// messages they don't understand rather than crashing.
nonisolated public enum NetMessage: Codable, Sendable {
    case hello(Performer)
    case goodbye(ID)
    case performerUpdate(Performer)
    case blockingSnapshot(Blocking)
    case markAdded(Mark)
    case markUpdated(Mark)
    case markRemoved(ID)
    case cueFired(markID: ID, cueID: ID, by: ID)
    case playbackState(t: Double?)
    /// A fresh LiDAR room scan, or nil to clear any previously-shared scan.
    /// Typically large (~100 KB base64); sent once per scan, not per frame.
    case roomScanUpdated(RoomScan?)
    /// Just the overlay transform — used by the director to align the scouted
    /// location to their actual rehearsal room without re-transmitting the mesh.
    case roomScanOverlay(Pose)
}

nonisolated public struct Envelope: Codable, Sendable {
    public static let currentVersion: Int = 1
    public var version: Int = Envelope.currentVersion
    public var senderID: ID
    public var message: NetMessage
}

public protocol Transport: AnyObject {
    var onMessage: ((Envelope) -> Void)? { get set }
    var onPeerCountChanged: ((Int) -> Void)? { get set }
    func start(roomCode: String, localID: ID, displayName: String)
    func stop()
    func send(_ message: NetMessage, from senderID: ID)
}
