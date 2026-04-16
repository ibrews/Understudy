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
    /// Optional LiDAR mesh of the location. When present, the visionOS
    /// director sees it as a wireframe ghost over their stage.
    public var roomScan: RoomScan?

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
        self.roomScan = nil
    }

    // Backward-compatible decoder — older .understudy files didn't have
    // `roomScan`, so we let that key be absent.
    private enum CodingKeys: String, CodingKey {
        case id, title, authorName, createdAt, modifiedAt, marks, origin, reference, roomScan
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(ID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.authorName = try c.decode(String.self, forKey: .authorName)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        self.marks = try c.decode([Mark].self, forKey: .marks)
        self.origin = try c.decode(Pose.self, forKey: .origin)
        self.reference = try c.decodeIfPresent(RecordedWalk.self, forKey: .reference)
        self.roomScan = try c.decodeIfPresent(RoomScan.self, forKey: .roomScan)
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

// MARK: - Room scan (LiDAR)

/// A LiDAR-captured mesh of the rehearsal / filming location. Captured
/// on an iPhone Pro via `ARSceneReconstruction` and shared over the wire
/// so the visionOS director can stand in their office and see the
/// scouted location as a wireframe ghost.
///
/// Binary layout (wire-efficient, base64-wrapped inside JSON):
///
///   positions : [Float32]  interleaved xyz, 12 bytes / vertex
///   indices   : [UInt32]   triangle corners, 4 bytes / index
///   triangleCount = indices.count / 3
///   vertexCount   = positions.count / 3
///
/// We don't ship normals — the renderer can compute them per-triangle, and
/// normals double the wire weight. Quantizing positions is a nice-to-have
/// but not worth the complexity at the sizes we care about (typical
/// ~3-8k triangles after `ARMeshGeometry` dedupes).
nonisolated public struct RoomScan: Codable, Hashable, Sendable {
    /// Base64 of the interleaved Float32 positions (big-endian).
    public var positionsBase64: String
    /// Base64 of the UInt32 triangle indices (big-endian).
    public var indicesBase64: String
    /// Wall-clock time of capture.
    public var capturedAt: Date
    /// Human label — "Brooklyn studio 4F", "Client's Williamsburg loft", etc.
    public var name: String
    /// Optional transform (yaw/translation) applied to the scan when rendered
    /// in the director's space, so a scouted Manhattan loft can be aligned
    /// to a Brooklyn rehearsal room.
    public var overlayOffset: Pose

    public init(
        positionsBase64: String,
        indicesBase64: String,
        capturedAt: Date = Date(),
        name: String = "Room scan",
        overlayOffset: Pose = Pose()
    ) {
        self.positionsBase64 = positionsBase64
        self.indicesBase64 = indicesBase64
        self.capturedAt = capturedAt
        self.name = name
        self.overlayOffset = overlayOffset
    }

    /// Derived: number of vertices in the mesh (three floats per vertex).
    public var vertexCount: Int {
        guard let data = Data(base64Encoded: positionsBase64) else { return 0 }
        return data.count / (MemoryLayout<Float>.size * 3)
    }
    public var triangleCount: Int {
        guard let data = Data(base64Encoded: indicesBase64) else { return 0 }
        return data.count / (MemoryLayout<UInt32>.size * 3)
    }
    /// Approximate wire cost in kilobytes (base64 payload only).
    public var wireKB: Int {
        (positionsBase64.utf8.count + indicesBase64.utf8.count + 512) / 1024
    }

    public func decodePositions() -> [Float] {
        guard let data = Data(base64Encoded: positionsBase64) else { return [] }
        // Memory contains big-endian Float32 bitpatterns. Read as UInt32,
        // swap to host byte order, then reinterpret as Float.
        let count = data.count / MemoryLayout<UInt32>.size
        var out = [Float](repeating: 0, count: count)
        data.withUnsafeBytes { raw in
            let words = raw.bindMemory(to: UInt32.self)
            for i in 0..<count {
                out[i] = Float(bitPattern: UInt32(bigEndian: words[i]))
            }
        }
        return out
    }

    public func decodeIndices() -> [UInt32] {
        guard let data = Data(base64Encoded: indicesBase64) else { return [] }
        let count = data.count / MemoryLayout<UInt32>.size
        var out = [UInt32](repeating: 0, count: count)
        data.withUnsafeBytes { raw in
            let words = raw.bindMemory(to: UInt32.self)
            for i in 0..<count {
                out[i] = UInt32(bigEndian: words[i])
            }
        }
        return out
    }

    /// Build from raw arrays — writes each scalar as big-endian bytes.
    public static func from(positions: [SIMD3<Float>], indices: [UInt32], name: String) -> RoomScan {
        // Positions.
        var posData = Data(capacity: positions.count * 3 * 4)
        for p in positions {
            for v in [p.x, p.y, p.z] {
                var be = v.bitPattern.bigEndian
                withUnsafeBytes(of: &be) { posData.append(contentsOf: $0) }
            }
        }
        // Indices.
        var idxData = Data(capacity: indices.count * 4)
        for i in indices {
            var be = i.bigEndian
            withUnsafeBytes(of: &be) { idxData.append(contentsOf: $0) }
        }
        return RoomScan(
            positionsBase64: posData.base64EncodedString(),
            indicesBase64: idxData.base64EncodedString(),
            name: name
        )
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
