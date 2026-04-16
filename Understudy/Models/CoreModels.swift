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

/// What this mark represents. Theater blockings are all `.actor`; film
/// location scouts can mix in `.camera` marks with lens metadata.
nonisolated public enum MarkKind: String, Codable, Hashable, Sendable, CaseIterable {
    /// Where a performer stands. Radius is the "zone" they need to land in
    /// to trigger cues. Default for all theater use.
    case actor
    /// A virtual camera position. Cues may still fire (the DP entering a
    /// camera mark could trigger a lighting cue) but the primary purpose
    /// is to visualize lens FOV and frame composition from this spot.
    case camera
}

/// Lens + rig metadata for a `MarkKind.camera` mark. Units are millimetres
/// for focal length and sensor dimensions (film-industry convention).
nonisolated public struct CameraSpec: Codable, Hashable, Sendable {
    /// Focal length in mm. Common values: 14, 24, 35, 50, 85, 135.
    public var focalLengthMM: Float
    /// Sensor width in mm. Full-frame = 36.0, Super 35 = 24.89, S16 = 12.52.
    public var sensorWidthMM: Float
    /// Sensor height in mm (for aspect-ratio / vertical FOV).
    public var sensorHeightMM: Float
    /// Camera height above the floor in meters (tripod height, shoulder, etc.).
    public var heightM: Float
    /// Tilt in radians. 0 = level. Positive = up, negative = down (tilting
    /// down toward the stage). Matches the Pose yaw convention for
    /// rotations: left-hand-y positive up, so positive tilt = pitch up.
    public var tiltRadians: Float

    public init(
        focalLengthMM: Float = 35,
        sensorWidthMM: Float = 36,
        sensorHeightMM: Float = 24,
        heightM: Float = 1.55,
        tiltRadians: Float = 0
    ) {
        self.focalLengthMM = focalLengthMM
        self.sensorWidthMM = sensorWidthMM
        self.sensorHeightMM = sensorHeightMM
        self.heightM = heightM
        self.tiltRadians = tiltRadians
    }

    /// Horizontal field of view in radians: 2 * atan(sensorWidth / (2*focal)).
    public var horizontalFOV: Float { 2 * atan(sensorWidthMM / (2 * focalLengthMM)) }
    public var verticalFOV: Float { 2 * atan(sensorHeightMM / (2 * focalLengthMM)) }

    /// A human-readable lens label for UI: "35mm · 36×24 · 1.55m".
    public var shortLabel: String {
        let aspect = sensorHeightMM > 0 ? sensorWidthMM / sensorHeightMM : 1.78
        return String(format: "%.0fmm · %.2f:1 · %.1fm",
                      focalLengthMM, aspect, heightM)
    }

    // Common preset lenses for the author-mode picker.
    public static let preset14mm = CameraSpec(focalLengthMM: 14)
    public static let preset24mm = CameraSpec(focalLengthMM: 24)
    public static let preset35mm = CameraSpec(focalLengthMM: 35)
    public static let preset50mm = CameraSpec(focalLengthMM: 50)
    public static let preset85mm = CameraSpec(focalLengthMM: 85)
    public static let preset135mm = CameraSpec(focalLengthMM: 135)
    public static let presets: [CameraSpec] = [
        preset14mm, preset24mm, preset35mm, preset50mm, preset85mm, preset135mm,
    ]
}

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
    /// Actor or camera. Decoded from JSON with `.actor` default so older
    /// `.understudy` files (v0.1–v0.7) still load unchanged.
    public var kind: MarkKind
    /// Lens metadata. Nil unless `kind == .camera`. Older files have no
    /// `camera` key, which Codable decodes as nil — preserving compat.
    public var camera: CameraSpec?

    public init(
        id: ID = ID(),
        name: String,
        pose: Pose,
        radius: Float = 0.6,
        cues: [Cue] = [],
        sequenceIndex: Int = -1,
        kind: MarkKind = .actor,
        camera: CameraSpec? = nil
    ) {
        self.id = id
        self.name = name
        self.pose = pose
        self.radius = radius
        self.cues = cues
        self.sequenceIndex = sequenceIndex
        self.kind = kind
        self.camera = camera
    }

    // Custom Decodable so old files (missing `kind` / `camera`) still load.
    private enum CodingKeys: String, CodingKey {
        case id, name, pose, radius, cues, sequenceIndex, kind, camera
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(ID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.pose = try c.decode(Pose.self, forKey: .pose)
        self.radius = try c.decode(Float.self, forKey: .radius)
        self.cues = try c.decode([Cue].self, forKey: .cues)
        self.sequenceIndex = try c.decode(Int.self, forKey: .sequenceIndex)
        self.kind = try c.decodeIfPresent(MarkKind.self, forKey: .kind) ?? .actor
        self.camera = try c.decodeIfPresent(CameraSpec.self, forKey: .camera)
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
