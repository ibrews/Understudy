//
//  DeviceCalibration.swift
//  Understudy
//
//  Maps between a device's raw AR world frame (ARKit / ARCore, origin = wherever
//  the session started) and the shared "blocking frame" that every device in a
//  multiplayer rehearsal agrees on. Phones that want to stand on the same stage
//  need the same (0,0,0) in the real world.
//
//  The ceremony: everyone stands at the agreed-upon stage center, facing the
//  agreed-upon upstage direction, and taps "Set Origin Here" at the same time.
//  Each device stores a `DeviceCalibration` whose `anchor` is the raw-frame
//  pose at the moment of calibration. From then on:
//
//    - Pose updates go through `toBlocking(_:)` before reaching the store
//      and the wire, so the pose everyone sees is expressed in the shared
//      frame.
//    - When rendering a Mark (which lives in the shared frame) into the
//      device's own AR scene, the scene uses `toRaw(_:)` to place the
//      entity at the correct spot in the real room.
//
//  Yaw-only rotation — we assume everyone is standing on the same floor plane.
//  No pitch, no roll; this matches the existing Pose model.
//

import Foundation

nonisolated public struct DeviceCalibration: Codable, Hashable, Sendable {
    /// Pose in the device's raw AR world frame that corresponds to
    /// blocking origin (0,0,0) facing +yaw = 0.
    public var anchor: Pose
    /// When the calibration was set — useful for "re-calibrated 12s ago" UI.
    public var capturedAt: Date

    public init(anchor: Pose, capturedAt: Date = Date()) {
        self.anchor = anchor
        self.capturedAt = capturedAt
    }

    /// Raw-frame pose → blocking-frame pose.
    /// Inverse rotation about +Y, then translation by -anchor.position.
    public func toBlocking(_ raw: Pose) -> Pose {
        let dx = raw.x - anchor.x
        let dz = raw.z - anchor.z
        let c = cosf(anchor.yaw)
        let s = sinf(anchor.yaw)
        // Rotate by -anchor.yaw:
        //   bx = cos(a) * dx + sin(a) * dz
        //   bz = -sin(a) * dx + cos(a) * dz
        return Pose(
            x: c * dx + s * dz,
            y: raw.y - anchor.y,
            z: -s * dx + c * dz,
            yaw: raw.yaw - anchor.yaw
        )
    }

    /// Blocking-frame pose → raw-frame pose.
    /// Rotation by +anchor.yaw about +Y, then translation by anchor.position.
    public func toRaw(_ blocking: Pose) -> Pose {
        let c = cosf(anchor.yaw)
        let s = sinf(anchor.yaw)
        return Pose(
            x: anchor.x + c * blocking.x - s * blocking.z,
            y: anchor.y + blocking.y,
            z: anchor.z + s * blocking.x + c * blocking.z,
            yaw: blocking.yaw + anchor.yaw
        )
    }
}
