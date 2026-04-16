//
//  DMXCueMapping.swift
//  Understudy
//
//  Translates an abstract `.light(color, intensity)` cue into concrete DMX
//  channel values across a small rig of fixtures. v1 is deliberately simple:
//  a hard-coded "4 RGBW par cans on channels 1/6/11/16" default that anyone
//  can edit in one place. Future work: load from JSON per blocking file,
//  add UI for fixture patching, support moving heads with pan/tilt.
//
//  The philosophy: when a cue fires, blast every fixture in the rig with
//  the same color at the given intensity. Theatrical lighting almost always
//  wants the rig washed uniformly for a single "light cue" — individual
//  fixture control is what cue *sequences* are for.
//

import Foundation

/// One DMX fixture in the default rig. Start channel is 1-indexed
/// (DMX slot 1 == channel index 0 in the slot array).
public struct DMXFixture: Sendable {
    public var name: String
    /// 1-based DMX address (1..512). Matches how console UIs number them.
    public var startChannel: Int
    /// Profile that tells us which slot is red/green/blue/white/intensity.
    public var profile: DMXFixtureProfile

    public init(name: String, startChannel: Int, profile: DMXFixtureProfile) {
        self.name = name
        self.startChannel = startChannel
        self.profile = profile
    }
}

/// A compact channel layout shared by almost every LED par on the market.
/// Each offset is relative to `startChannel` (0 = startChannel itself).
/// `nil` means the fixture doesn't have that channel — e.g. an RGB-only
/// par has `white == nil`.
public struct DMXFixtureProfile: Sendable {
    public var footprint: Int        // how many DMX slots this fixture eats
    public var red: Int?
    public var green: Int?
    public var blue: Int?
    public var white: Int?
    public var amber: Int?
    public var intensity: Int?       // dimmer / master channel, if any

    public init(footprint: Int,
                red: Int? = nil, green: Int? = nil, blue: Int? = nil,
                white: Int? = nil, amber: Int? = nil, intensity: Int? = nil) {
        self.footprint = footprint
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
        self.amber = amber
        self.intensity = intensity
    }

    /// 5-channel RGBW + dimmer (very common cheap LED par).
    /// Slot layout: [dim, R, G, B, W].
    public static let rgbwDim5: DMXFixtureProfile = .init(
        footprint: 5,
        red: 1, green: 2, blue: 3, white: 4, intensity: 0
    )
}

/// Translates Cue.light into a 512-byte DMX frame.
public struct DMXCueMapping: Sendable {
    /// The fixture rig. Edit this literal (or swap it out at runtime) to
    /// match your actual patching. The default is 4 × 5-channel RGBW+dim
    /// pars at addresses 1, 6, 11, 16 — a sensible starter kit.
    public var fixtures: [DMXFixture]

    public init(fixtures: [DMXFixture] = DMXCueMapping.defaultFixtures) {
        self.fixtures = fixtures
    }

    /// Four RGBW pars, channels 1/6/11/16. Edit here for v1 customization.
    public static let defaultFixtures: [DMXFixture] = [
        DMXFixture(name: "Par 1", startChannel: 1,  profile: .rgbwDim5),
        DMXFixture(name: "Par 2", startChannel: 6,  profile: .rgbwDim5),
        DMXFixture(name: "Par 3", startChannel: 11, profile: .rgbwDim5),
        DMXFixture(name: "Par 4", startChannel: 16, profile: .rgbwDim5),
    ]

    /// Build a full 512-byte DMX universe for a light cue. Every fixture
    /// in the rig lights the same color; unused channels stay at 0.
    public func frame(for color: LightColor, intensity: Float) -> [UInt8] {
        var frame = [UInt8](repeating: 0, count: 512)
        let rgbw = Self.rgbw(for: color)
        // Intensity is 0..1 in the cue model; map directly to 0..255.
        let dim = UInt8(max(0, min(255, Int((intensity.isFinite ? intensity : 0) * 255))))
        // Pre-multiply RGBW by intensity for fixtures without a dimmer
        // channel — otherwise a red+50% cue on an RGB-only par would still
        // blast full red. Fixtures with a dimmer get full RGBW + scaled dim.
        func scale(_ v: UInt8) -> UInt8 {
            UInt8((Int(v) * Int(dim)) / 255)
        }
        for fixture in fixtures {
            let base = fixture.startChannel - 1  // convert to 0-based slot index
            guard base >= 0, base + fixture.profile.footprint <= 512 else { continue }
            let p = fixture.profile
            let hasDim = p.intensity != nil

            if let off = p.intensity {
                frame[base + off] = dim
            }
            let r = hasDim ? rgbw.r : scale(rgbw.r)
            let g = hasDim ? rgbw.g : scale(rgbw.g)
            let b = hasDim ? rgbw.b : scale(rgbw.b)
            let w = hasDim ? rgbw.w : scale(rgbw.w)
            let a = hasDim ? rgbw.a : scale(rgbw.a)

            if let off = p.red    { frame[base + off] = r }
            if let off = p.green  { frame[base + off] = g }
            if let off = p.blue   { frame[base + off] = b }
            if let off = p.white  { frame[base + off] = w }
            if let off = p.amber  { frame[base + off] = a }
        }
        return frame
    }

    /// Color palette used when firing Understudy cues. Tuned to look roughly
    /// like the on-screen `CueFXEngine.color(for:)` wash.
    public struct RGBWA {
        public let r: UInt8
        public let g: UInt8
        public let b: UInt8
        public let w: UInt8
        public let a: UInt8
    }

    public static func rgbw(for color: LightColor) -> RGBWA {
        switch color {
        case .warm:     return RGBWA(r: 255, g: 180, b: 80,  w: 255, a: 180)
        case .cool:     return RGBWA(r: 140, g: 200, b: 255, w: 255, a: 0)
        case .red:      return RGBWA(r: 255, g: 0,   b: 0,   w: 0,   a: 0)
        case .blue:     return RGBWA(r: 0,   g: 0,   b: 255, w: 0,   a: 0)
        case .green:    return RGBWA(r: 0,   g: 255, b: 0,   w: 0,   a: 0)
        case .amber:    return RGBWA(r: 255, g: 160, b: 0,   w: 0,   a: 255)
        case .blackout: return RGBWA(r: 0,   g: 0,   b: 0,   w: 0,   a: 0)
        }
    }
}
