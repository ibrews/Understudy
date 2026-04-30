//
//  SetPresets.swift
//  Understudy
//
//  Curated prefab prop arrangements. A director taps "Drop Set…" → picks
//  "Throne Room" and the stage instantly populates with a throne, two
//  pillars, a side table, and a banner. Ten seconds of work becomes one tap.
//
//  Each preset is a small array of PropObject builders that get instantiated
//  with fresh IDs at drop time. The catalogue ships visionOS-ready
//  primitives (cubes/spheres/cylinders) — when the proper set arrives the
//  director swaps the placeholders for the real thing.
//

import Foundation

public enum SetPreset: String, CaseIterable, Identifiable {
    case throneRoom        = "Throne Room"
    case tavern            = "Tavern"
    case forestClearing    = "Forest Clearing"
    case modernCourtroom   = "Modern Courtroom"
    case minimalStudio     = "Minimal Studio"
    case filmInteriorRoom  = "Film — Interior Room"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .throneRoom:       return "crown.fill"
        case .tavern:           return "wineglass.fill"
        case .forestClearing:   return "tree.fill"
        case .modernCourtroom:  return "books.vertical.fill"
        case .minimalStudio:    return "rectangle.dashed"
        case .filmInteriorRoom: return "house.fill"
        }
    }

    public var blurb: String {
        switch self {
        case .throneRoom:
            return "Throne, two pillars, banner, side table. Period palette: deep red + gold."
        case .tavern:
            return "Bar counter, three barrels, two chairs, hearth-mark. Earth tones."
        case .forestClearing:
            return "Five tree trunks of varied heights and a fallen log. Site-specific outdoor staging."
        case .modernCourtroom:
            return "Judge's bench, two counsel tables, witness stand, gallery rail. Slate / oak palette."
        case .minimalStudio:
            return "One stool. The empty stage."
        case .filmInteriorRoom:
            return "Sofa, coffee table, side chair, two walls. Standard apartment-set blocking diagram."
        }
    }

    /// Generate fresh PropObjects (with new IDs) at the given world origin.
    /// All coordinates are local to the preset's origin point — the caller
    /// can offset by adding to each prop's pose.
    public func makeProps(originX: Float = 0, originZ: Float = 0) -> [PropObject] {
        switch self {
        case .throneRoom:
            return [
                .init(name: "Throne",
                      pose: Pose(x: originX, y: 0, z: originZ - 1.8),
                      width: 0.9, height: 1.6, depth: 0.7,
                      shape: .cube, r: 0.6, g: 0.1, b: 0.15),
                .init(name: "L Pillar",
                      pose: Pose(x: originX - 1.6, y: 0, z: originZ - 1.5),
                      width: 0.5, height: 2.6, depth: 0.5,
                      shape: .cylinder, r: 0.85, g: 0.7, b: 0.4),
                .init(name: "R Pillar",
                      pose: Pose(x: originX + 1.6, y: 0, z: originZ - 1.5),
                      width: 0.5, height: 2.6, depth: 0.5,
                      shape: .cylinder, r: 0.85, g: 0.7, b: 0.4),
                .init(name: "Banner",
                      pose: Pose(x: originX, y: 0, z: originZ - 2.4),
                      width: 1.4, height: 2.0, depth: 0.05,
                      shape: .cube, r: 0.7, g: 0.1, b: 0.1),
                .init(name: "Side Table",
                      pose: Pose(x: originX + 1.2, y: 0, z: originZ - 1.2),
                      width: 0.6, height: 0.85, depth: 0.4,
                      shape: .cube, r: 0.55, g: 0.4, b: 0.25),
            ]

        case .tavern:
            return [
                .init(name: "Bar",
                      pose: Pose(x: originX, y: 0, z: originZ - 1.6),
                      width: 2.4, height: 1.0, depth: 0.6,
                      shape: .cube, r: 0.45, g: 0.3, b: 0.18),
                .init(name: "Barrel L",
                      pose: Pose(x: originX - 2.0, y: 0, z: originZ - 0.4),
                      width: 0.55, height: 0.9, depth: 0.55,
                      shape: .cylinder, r: 0.5, g: 0.32, b: 0.18),
                .init(name: "Barrel C",
                      pose: Pose(x: originX - 1.5, y: 0, z: originZ - 0.5),
                      width: 0.55, height: 0.9, depth: 0.55,
                      shape: .cylinder, r: 0.5, g: 0.32, b: 0.18),
                .init(name: "Barrel R",
                      pose: Pose(x: originX + 2.0, y: 0, z: originZ - 0.4),
                      width: 0.55, height: 0.9, depth: 0.55,
                      shape: .cylinder, r: 0.5, g: 0.32, b: 0.18),
                .init(name: "Chair L",
                      pose: Pose(x: originX - 0.8, y: 0, z: originZ + 0.4),
                      width: 0.45, height: 0.9, depth: 0.45,
                      shape: .cube, r: 0.4, g: 0.28, b: 0.16),
                .init(name: "Chair R",
                      pose: Pose(x: originX + 0.8, y: 0, z: originZ + 0.4),
                      width: 0.45, height: 0.9, depth: 0.45,
                      shape: .cube, r: 0.4, g: 0.28, b: 0.16),
                .init(name: "Hearth",
                      pose: Pose(x: originX + 2.6, y: 0, z: originZ - 1.6),
                      width: 1.0, height: 1.4, depth: 0.6,
                      shape: .cube, r: 0.35, g: 0.22, b: 0.14),
            ]

        case .forestClearing:
            return [
                .init(name: "Tree 1",
                      pose: Pose(x: originX - 2.0, y: 0, z: originZ - 1.8),
                      width: 0.4, height: 3.2, depth: 0.4,
                      shape: .cylinder, r: 0.3, g: 0.22, b: 0.15),
                .init(name: "Tree 2",
                      pose: Pose(x: originX + 2.2, y: 0, z: originZ - 2.4),
                      width: 0.45, height: 3.6, depth: 0.45,
                      shape: .cylinder, r: 0.3, g: 0.22, b: 0.15),
                .init(name: "Tree 3",
                      pose: Pose(x: originX - 1.8, y: 0, z: originZ + 1.8),
                      width: 0.35, height: 3.0, depth: 0.35,
                      shape: .cylinder, r: 0.3, g: 0.22, b: 0.15),
                .init(name: "Tree 4",
                      pose: Pose(x: originX + 1.6, y: 0, z: originZ + 0.8),
                      width: 0.35, height: 2.8, depth: 0.35,
                      shape: .cylinder, r: 0.3, g: 0.22, b: 0.15),
                .init(name: "Tree 5",
                      pose: Pose(x: originX - 0.4, y: 0, z: originZ - 2.6),
                      width: 0.5, height: 3.8, depth: 0.5,
                      shape: .cylinder, r: 0.3, g: 0.22, b: 0.15),
                .init(name: "Fallen Log",
                      pose: Pose(x: originX, y: 0, z: originZ + 0.2),
                      width: 1.8, height: 0.4, depth: 0.4,
                      shape: .cylinder, r: 0.4, g: 0.28, b: 0.18),
            ]

        case .modernCourtroom:
            return [
                .init(name: "Judge's Bench",
                      pose: Pose(x: originX, y: 0, z: originZ - 2.0),
                      width: 2.0, height: 1.2, depth: 0.7,
                      shape: .cube, r: 0.35, g: 0.25, b: 0.18),
                .init(name: "Witness Stand",
                      pose: Pose(x: originX - 1.6, y: 0, z: originZ - 1.2),
                      width: 0.9, height: 1.0, depth: 0.7,
                      shape: .cube, r: 0.4, g: 0.3, b: 0.22),
                .init(name: "Counsel L",
                      pose: Pose(x: originX - 1.2, y: 0, z: originZ + 0.4),
                      width: 1.2, height: 0.85, depth: 0.6,
                      shape: .cube, r: 0.45, g: 0.32, b: 0.20),
                .init(name: "Counsel R",
                      pose: Pose(x: originX + 1.2, y: 0, z: originZ + 0.4),
                      width: 1.2, height: 0.85, depth: 0.6,
                      shape: .cube, r: 0.45, g: 0.32, b: 0.20),
                .init(name: "Gallery Rail",
                      pose: Pose(x: originX, y: 0, z: originZ + 1.8),
                      width: 3.6, height: 1.0, depth: 0.15,
                      shape: .cube, r: 0.5, g: 0.5, b: 0.5),
            ]

        case .minimalStudio:
            return [
                .init(name: "Stool",
                      pose: Pose(x: originX, y: 0, z: originZ - 0.5),
                      width: 0.4, height: 0.5, depth: 0.4,
                      shape: .cylinder, r: 0.85, g: 0.85, b: 0.85),
            ]

        case .filmInteriorRoom:
            return [
                .init(name: "Sofa",
                      pose: Pose(x: originX, y: 0, z: originZ - 1.2),
                      width: 2.0, height: 0.8, depth: 0.9,
                      shape: .cube, r: 0.55, g: 0.4, b: 0.35),
                .init(name: "Coffee Table",
                      pose: Pose(x: originX, y: 0, z: originZ - 0.2),
                      width: 1.0, height: 0.45, depth: 0.6,
                      shape: .cube, r: 0.35, g: 0.25, b: 0.18),
                .init(name: "Side Chair",
                      pose: Pose(x: originX + 1.6, y: 0, z: originZ - 0.4),
                      width: 0.7, height: 0.95, depth: 0.7,
                      shape: .cube, r: 0.6, g: 0.45, b: 0.35),
                .init(name: "Wall Back",
                      pose: Pose(x: originX, y: 0, z: originZ - 2.4),
                      width: 4.0, height: 2.4, depth: 0.1,
                      shape: .cube, r: 0.85, g: 0.82, b: 0.78),
                .init(name: "Wall Side",
                      pose: Pose(x: originX - 2.4, y: 0, z: originZ - 1.4),
                      width: 0.1, height: 2.4, depth: 2.0,
                      shape: .cube, r: 0.85, g: 0.82, b: 0.78),
            ]
        }
    }
}

// MARK: - Light gel presets

/// Multi-cue light gel presets — drop a sequence of light cues that build
/// a mood. Each preset returns a list of Cue.light values that get dropped
/// onto the currently-selected mark in author mode (or fired in sequence
/// from the Director Panel).
public enum LightGelPreset: String, CaseIterable, Identifiable {
    case warmWash      = "Warm Wash"
    case coolMoonlight = "Cool Moonlight"
    case sunsetFade    = "Sunset Fade"
    case stormyCool    = "Stormy / Cool"
    case romanticPink  = "Romantic Pink"
    case courtroomDay  = "Courtroom Day"
    case ghostBlue     = "Ghost Blue"

    public var id: String { rawValue }

    public var blurb: String {
        switch self {
        case .warmWash:      return "Single warm at 70%. Clean, classic, daylit-interior."
        case .coolMoonlight: return "Cool wash at 50% — that exterior-night studio look."
        case .sunsetFade:    return "Amber → red over 2 beats. End-of-day reveal."
        case .stormyCool:    return "Blue at 80% with a thunder cue + brief amber lightning."
        case .romanticPink:  return "Warm + low red. Intimate, candle-lit feel."
        case .courtroomDay:  return "Cool at 90% — the harsh daylit institutional wash."
        case .ghostBlue:     return "Blue at 95% + thunder + brief amber flash. Hamlet's Ghost cue."
        }
    }

    public var systemImage: String {
        switch self {
        case .warmWash:      return "lightbulb.fill"
        case .coolMoonlight: return "moon.stars.fill"
        case .sunsetFade:    return "sun.horizon.fill"
        case .stormyCool:    return "cloud.bolt.rain.fill"
        case .romanticPink:  return "heart.fill"
        case .courtroomDay:  return "building.columns.fill"
        case .ghostBlue:     return "theatermasks.fill"
        }
    }

    public func makeCues() -> [Cue] {
        // newCueID() resolves the global `ID` struct unambiguously, since
        // inside this enum's scope the Identifiable conformance shadows
        // `ID` with the typealias `LightGelPreset.ID == String`.
        switch self {
        case .warmWash:
            return [.light(id: newCueID(), color: .warm, intensity: 0.7)]
        case .coolMoonlight:
            return [.light(id: newCueID(), color: .cool, intensity: 0.5)]
        case .sunsetFade:
            return [
                .light(id: newCueID(), color: .amber, intensity: 0.85),
                .wait(id: newCueID(), seconds: 1.2),
                .light(id: newCueID(), color: .red, intensity: 0.6),
                .wait(id: newCueID(), seconds: 1.0),
                .light(id: newCueID(), color: .red, intensity: 0.25),
            ]
        case .stormyCool:
            return [
                .light(id: newCueID(), color: .blue, intensity: 0.8),
                .sfx(id: newCueID(), name: "thunder"),
                .light(id: newCueID(), color: .amber, intensity: 0.9),
                .wait(id: newCueID(), seconds: 0.4),
                .light(id: newCueID(), color: .blue, intensity: 0.6),
            ]
        case .romanticPink:
            return [
                .light(id: newCueID(), color: .warm, intensity: 0.55),
                .light(id: newCueID(), color: .red, intensity: 0.35),
            ]
        case .courtroomDay:
            return [.light(id: newCueID(), color: .cool, intensity: 0.9)]
        case .ghostBlue:
            return [
                .light(id: newCueID(), color: .blue, intensity: 0.95),
                .sfx(id: newCueID(), name: "thunder"),
                .wait(id: newCueID(), seconds: 1.0),
                .light(id: newCueID(), color: .amber, intensity: 0.7),
                .wait(id: newCueID(), seconds: 0.3),
                .light(id: newCueID(), color: .blue, intensity: 0.85),
            ]
        }
    }
}

/// File-scope helper so `ID()` resolves to the global model `ID` struct
/// rather than `LightGelPreset.ID` (== `String` via Identifiable).
private func newCueID() -> ID { ID() }
