//
//  Avatar.swift
//  Understudy
//
//  Performer avatars — pick a style + colour and that's how you show up to
//  every other peer's stage. Travels over the wire as part of the
//  Performer struct.
//
//  This is what makes the "Understudy" name resonate: an avatar walks the
//  blocking once, anyone else can replay it as a ghost they chase. The
//  director's lead actor records the show, the understudy practices
//  against the avatar — exactly what the role exists for.
//

import Foundation

// MARK: - Avatar

/// A performer's chosen visual representation.
nonisolated public struct Avatar: Codable, Hashable, Sendable {
    public var style: Style
    /// Primary body colour, hex (without #), e.g. "FF3366".
    public var primaryHex: String
    /// Secondary accent colour, hex (without #).
    public var secondaryHex: String

    public enum Style: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
        case performer  // upright body + slightly tapered head
        case dancer     // tall slim with raised arms, arms-out silhouette
        case ghost      // translucent floating sphere with a long trail
        case minimal    // single sphere (the legacy magenta orb)
        case villain    // wider, darker shoulders, longer cape
        case hero       // crowned with a star halo, bright

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .performer: return "Performer"
            case .dancer:    return "Dancer"
            case .ghost:     return "Ghost"
            case .minimal:   return "Minimal"
            case .villain:   return "Villain"
            case .hero:      return "Hero"
            }
        }

        public var blurb: String {
            switch self {
            case .performer: return "Standing actor silhouette. Reads as 'a person on the stage' from any angle."
            case .dancer:    return "Tall and slim with raised arms. Best for movement-heavy work."
            case .ghost:     return "Translucent. Use this for understudy playback so the live performer reads through it."
            case .minimal:   return "A simple orb. Lowest visual noise — good for very crowded stages."
            case .villain:   return "Broader silhouette, darker base. The antagonist."
            case .hero:      return "A bright crown of light. The protagonist."
            }
        }

        public var systemImage: String {
            switch self {
            case .performer: return "figure.stand"
            case .dancer:    return "figure.dance"
            case .ghost:     return "sparkle"
            case .minimal:   return "circle.fill"
            case .villain:   return "theatermasks.fill"
            case .hero:      return "star.fill"
            }
        }
    }

    public init(
        style: Style = .performer,
        primaryHex: String = "FF3366",
        secondaryHex: String = "FFFFFF"
    ) {
        self.style = style
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
    }

    /// A small palette of curated colours — keeps avatars readable across
    /// stages and avoids the "everyone picked beige" problem.
    public static let palette: [String] = [
        "FF3366", // signature red
        "FF8C42", // amber
        "FFD23F", // gold
        "5BC0BE", // teal
        "3A86FF", // blue
        "8338EC", // violet
        "FF006E", // hot pink
        "06FFA5", // mint
        "FFFFFF", // white
        "B8B8B8", // silver
    ]

    public static let defaultPick = Avatar(
        style: .performer,
        primaryHex: "FF3366",
        secondaryHex: "FFFFFF"
    )
}

// MARK: - Hex → SIMD4<Float>

public extension Avatar {
    /// Decode a hex like "FF3366" into RGBA float components.
    static func rgba(from hex: String) -> SIMD4<Float> {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard h.count == 6, let v = UInt32(h, radix: 16) else {
            return SIMD4<Float>(1, 0.2, 0.4, 1)
        }
        let r = Float((v & 0xFF0000) >> 16) / 255
        let g = Float((v & 0x00FF00) >> 8) / 255
        let b = Float( v & 0x0000FF      ) / 255
        return SIMD4<Float>(r, g, b, 1)
    }

    var primaryRGBA: SIMD4<Float> { Avatar.rgba(from: primaryHex) }
    var secondaryRGBA: SIMD4<Float> { Avatar.rgba(from: secondaryHex) }
}

// MARK: - Named recordings

/// One named walk-through. Distinct from the legacy single `reference`
/// field on Blocking — a Blocking can now hold many of these, each with
/// its own performer + avatar so an understudy can pick whose blocking to
/// rehearse against.
nonisolated public struct NamedRecording: Codable, Hashable, Identifiable, Sendable {
    public var id: ID
    public var name: String
    public var performerName: String
    public var avatar: Avatar?
    public var samples: [RecordedWalk.Sample]
    public var duration: TimeInterval
    public var createdAt: Date
    /// Which blocking this recording belongs to. Useful for re-attaching
    /// after import, and for displaying in cross-blocking pickers.
    public var blockingTitle: String

    public init(
        id: ID = ID(),
        name: String,
        performerName: String,
        avatar: Avatar? = nil,
        samples: [RecordedWalk.Sample],
        duration: TimeInterval,
        createdAt: Date = Date(),
        blockingTitle: String
    ) {
        self.id = id
        self.name = name
        self.performerName = performerName
        self.avatar = avatar
        self.samples = samples
        self.duration = duration
        self.createdAt = createdAt
        self.blockingTitle = blockingTitle
    }

    /// Migrate a legacy unnamed `RecordedWalk` into a NamedRecording so
    /// older `.understudy` files keep working.
    public init(legacyWalk walk: RecordedWalk, blockingTitle: String) {
        self.id = ID()
        self.name = "Reference walk"
        self.performerName = walk.performerName
        self.avatar = nil
        self.samples = walk.samples
        self.duration = walk.duration
        self.createdAt = Date()
        self.blockingTitle = blockingTitle
    }

    /// Linear interpolation along the recorded path at normalized time t (0…1).
    /// Same logic as BlockingStore.ghostPose but operating on a specific
    /// NamedRecording instead of the legacy reference.
    public func pose(at normalizedT: Double) -> Pose? {
        guard !samples.isEmpty else { return nil }
        let t = max(0, min(1, normalizedT)) * duration
        if samples.count == 1 { return samples[0].pose }
        if t <= samples.first!.t { return samples.first!.pose }
        if t >= samples.last!.t { return samples.last!.pose }
        var lo = 0
        var hi = samples.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if samples[mid].t <= t { lo = mid } else { hi = mid }
        }
        let a = samples[lo]
        let b = samples[hi]
        let span = b.t - a.t
        let alpha: Float = span > 0 ? Float((t - a.t) / span) : 0
        let x = a.pose.x + (b.pose.x - a.pose.x) * alpha
        let y = a.pose.y + (b.pose.y - a.pose.y) * alpha
        let z = a.pose.z + (b.pose.z - a.pose.z) * alpha
        var dy = b.pose.yaw - a.pose.yaw
        while dy >  .pi { dy -= 2 * .pi }
        while dy < -.pi { dy += 2 * .pi }
        let yaw = a.pose.yaw + dy * alpha
        return Pose(x: x, y: y, z: z, yaw: yaw)
    }
}
