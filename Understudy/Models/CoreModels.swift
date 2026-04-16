//
//  CoreModels.swift
//  Understudy
//
//  The data model for a shared piece of spatial theater.
//  A `Blocking` is a recorded piece — a sequence of `Mark`s in 3D space,
//  each with zero or more `Cue`s that fire when a `Performer` enters the mark.
//

import Foundation
import simd

// MARK: - Identifiers

nonisolated public struct ID: Hashable, Codable, CustomStringConvertible, Sendable {
    public let raw: String
    public init(_ raw: String = UUID().uuidString) { self.raw = raw }
    public var description: String { raw }
}

// MARK: - Spatial primitives

/// World-space pose. Position in meters, yaw in radians (about +Y).
/// We keep this lightweight (no quaternion) because blocking direction is yaw-only
/// for human performers — pitch/roll add complexity without rehearsal value.
nonisolated public struct Pose: Codable, Hashable, Sendable {
    public var x: Float
    public var y: Float
    public var z: Float
    public var yaw: Float

    public init(x: Float = 0, y: Float = 0, z: Float = 0, yaw: Float = 0) {
        self.x = x; self.y = y; self.z = z; self.yaw = yaw
    }

    public var position: SIMD3<Float> { SIMD3(x, y, z) }

    public func distance(to other: Pose) -> Float {
        simd_distance(self.position, other.position)
    }
}

// MARK: - Cues

/// A thing that happens when a performer arrives on a mark.
/// Kept as a simple enum-with-associated-values so it serializes cleanly over the wire.
nonisolated public enum Cue: Codable, Hashable, Sendable, Identifiable {
    case line(id: ID, text: String, character: String?)
    case sfx(id: ID, name: String)          // name maps to a bundled audio file
    case light(id: ID, color: LightColor, intensity: Float)
    case note(id: ID, text: String)         // director-only note, not shown to performer
    case wait(id: ID, seconds: Double)      // beat / hold

    public var id: ID {
        switch self {
        case .line(let id, _, _),
             .sfx(let id, _),
             .light(let id, _, _),
             .note(let id, _),
             .wait(let id, _):
            return id
        }
    }

    public var humanLabel: String {
        switch self {
        case .line(_, let t, let c):
            return c.map { "\($0): \(t)" } ?? t
        case .sfx(_, let n): return "♪ \(n)"
        case .light(_, let c, _): return "◐ \(c.rawValue)"
        case .note(_, let t): return "note: \(t)"
        case .wait(_, let s): return "• hold \(String(format: "%.1f", s))s"
        }
    }
}

nonisolated public enum LightColor: String, Codable, Hashable, Sendable, CaseIterable {
    case warm, cool, red, blue, green, amber, blackout
}

// MARK: - Marks

/// A spatial position with radius. When a performer's pose enters a mark's
/// radius, the mark fires its cues in order.
nonisolated public struct Mark: Codable, Hashable, Identifiable, Sendable {
    public var id: ID
    public var name: String
    public var pose: Pose
    /// Radius in meters. A mark is really a "zone" — performers rarely hit
    /// an exact point, and fat-radius zones feel better than precise ones.
    public var radius: Float
    public var cues: [Cue]
    /// Sequence index in the blocking — what order the director expects this
    /// mark to be hit. -1 means "freeform, not part of the linear sequence."
    public var sequenceIndex: Int

    public init(
        id: ID = ID(),
        name: String,
        pose: Pose,
        radius: Float = 0.6,
        cues: [Cue] = [],
        sequenceIndex: Int = -1
    ) {
        self.id = id
        self.name = name
        self.pose = pose
        self.radius = radius
        self.cues = cues
        self.sequenceIndex = sequenceIndex
    }
}

// MARK: - Performers

/// A live participant. Director is typically on visionOS; performers on iOS/Android.
nonisolated public struct Performer: Codable, Hashable, Identifiable, Sendable {
    public var id: ID
    public var displayName: String
    public var role: Role
    public var pose: Pose
    /// 0…1, low-confidence when ARKit tracking is degraded.
    public var trackingQuality: Float
    /// Mark currently occupied, if any.
    public var currentMarkID: ID?

    public enum Role: String, Codable, Sendable {
        case director   // visionOS — authors the blocking
        case performer  // iOS/Android — walks the blocking
        case observer   // watch-only
    }

    public init(
        id: ID = ID(),
        displayName: String,
        role: Role,
        pose: Pose = Pose(),
        trackingQuality: Float = 1.0,
        currentMarkID: ID? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.pose = pose
        self.trackingQuality = trackingQuality
        self.currentMarkID = currentMarkID
    }
}

// MARK: - Blocking

/// The whole piece. Think of this as the "document" — save to disk, sync over network.
nonisolated public struct Blocking: Codable, Hashable, Identifiable, Sendable {
    public var id: ID
    public var title: String
    public var authorName: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var marks: [Mark]
    /// Origin anchor — all marks are expressed relative to this.
    /// When a new performer joins, they align to this origin via their own AR session.
    public var origin: Pose
    /// Optional recorded performance: the director's ideal walkthrough, so
    /// late-joining performers can scrub a ghost.
    public var reference: RecordedWalk?

    public init(
        id: ID = ID(),
        title: String = "Untitled Piece",
        authorName: String = "",
        marks: [Mark] = [],
        origin: Pose = Pose()
    ) {
        self.id = id
        self.title = title
        self.authorName = authorName
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.marks = marks
        self.origin = origin
        self.reference = nil
    }

    /// Return the mark a given pose is currently inside, if any.
    /// Ambiguity (overlapping marks) resolves to the closest center.
    public func mark(containing pose: Pose) -> Mark? {
        marks
            .map { ($0, $0.pose.distance(to: pose)) }
            .filter { $0.1 <= $0.0.radius }
            .min(by: { $0.1 < $1.1 })?
            .0
    }
}

/// A time-sampled walk. Phones record these as they walk blockings so the
/// director can replay a ghost.
nonisolated public struct RecordedWalk: Codable, Hashable, Sendable {
    public var performerName: String
    public var samples: [Sample]
    public var duration: TimeInterval

    public struct Sample: Codable, Hashable, Sendable {
        public var t: TimeInterval
        public var pose: Pose
    }
}
