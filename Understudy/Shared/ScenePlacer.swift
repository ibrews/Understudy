//
//  ScenePlacer.swift
//  Understudy
//
//  Given a Scene from the bundled script and an origin pose in the room,
//  generate a natural arrangement of Marks with the scene's dialogue
//  distributed across them. One "Drop Whole Scene" tap produces a
//  walkable staged blocking.
//
//  Placement algorithm:
//    - Walk the scene's entries in order, grouping consecutive entries
//      (lines + inline stage directions) into "beats" when a speaker
//      changes, an exit/entrance happens, or the beat exceeds ~4 lines.
//    - Arrange beats along a gentle zig-zag path in front of the author,
//      spaced ~1.2 m apart, offset alternating left/right by ~0.8 m.
//    - Each beat becomes one Mark: name = "<CHARACTER> (beat N)",
//      cues = any stage direction as a .note + the lines as .line cues.
//    - Preamble stage directions (before the first line) go on mark 1
//      as leading notes.
//

import Foundation
import simd

public enum ScenePlacer {

    /// Public entry: given a scene and a starting pose, return a set of
    /// freshly-built Marks ready to insert into a BlockingStore.
    public static func layout(
        scene: PlayScript.Scene,
        origin: Pose,
        spacing: Float = 1.2,
        lateralOffset: Float = 0.8,
        sequenceOffset: Int = 0
    ) -> [Mark] {
        // Direction the author is facing when they tap "Drop Whole Scene."
        // Marks walk forward from that direction, zig-zagging side to side.
        let forward = SIMD3<Float>(sin(origin.yaw), 0, -cos(origin.yaw))
        let right = SIMD3<Float>(cos(origin.yaw), 0, sin(origin.yaw))

        let beats = bucket(entries: scene.entries)

        var marks: [Mark] = []
        for (i, beat) in beats.enumerated() {
            let side: Float = (i % 2 == 0) ? -1 : 1
            let step = forward * (Float(i + 1) * spacing)
            let lateral = right * side * lateralOffset
            let origin3 = SIMD3<Float>(origin.x, 0, origin.z)
            let position = origin3 + step + lateral

            // Face the next beat (or scene center if last).
            let yaw: Float
            if i < beats.count - 1 {
                let nextStep = forward * Float(i + 2) * spacing
                let nextLat = right * -side * lateralOffset
                let nextPos = origin3 + nextStep + nextLat
                let d = nextPos - position
                yaw = atan2f(d.x, -d.z)
            } else {
                yaw = atan2f(-lateral.x, lateral.z)
            }

            let mark = Mark(
                id: ID(),
                name: beat.title,
                pose: Pose(x: position.x, y: 0, z: position.z, yaw: yaw),
                radius: 0.6,
                cues: beat.cues(),
                sequenceIndex: sequenceOffset + i
            )
            marks.append(mark)
        }

        return marks
    }

    // MARK: - Beat bucketing

    /// One "beat" — a speaker's turn, possibly spanning multiple consecutive
    /// line entries plus inline stage directions. Capped at ~4 dialogue
    /// entries to keep beats walkable.
    private struct Beat {
        var leadingStage: [String] = []      // stage directions before the first line
        var speaker: String = ""
        var lines: [(text: String, character: String)] = []
        var trailingStage: [String] = []

        var title: String {
            if lines.isEmpty {
                return leadingStage.first.map { shortened($0, to: 24) } ?? "Beat"
            }
            let speakerLabel = lines[0].character
            return "\(speakerLabel.capitalized)"
        }

        func cues() -> [Cue] {
            var result: [Cue] = []
            for stage in leadingStage {
                result.append(.note(id: ID(), text: stage))
            }
            for l in lines {
                result.append(.line(id: ID(), text: l.text, character: l.character))
            }
            for stage in trailingStage {
                result.append(.note(id: ID(), text: stage))
            }
            return result
        }
    }

    private static let maxLinesPerBeat = 4

    private static func bucket(entries: [PlayScript.Entry]) -> [Beat] {
        // Step 1: build raw beats, one per speaker turn (or preamble-stage).
        var beats: [Beat] = []
        var current = Beat()

        func flush() {
            if !current.lines.isEmpty || !current.leadingStage.isEmpty {
                beats.append(current)
            }
            current = Beat()
        }

        for entry in entries {
            switch entry {
            case .stage(let text):
                if current.lines.isEmpty {
                    current.leadingStage.append(text)
                } else {
                    current.trailingStage.append(text)
                }
            case .line(let character, let text, _):
                if current.lines.isEmpty {
                    current.speaker = character
                    current.lines.append((text: text, character: character))
                } else if character == current.speaker,
                          current.lines.count < maxLinesPerBeat {
                    current.lines.append((text: text, character: character))
                } else {
                    flush()
                    current.speaker = character
                    current.lines.append((text: text, character: character))
                }
            }
        }
        flush()

        // Step 2: merge leading-stage-only beats into the next beat, so every
        // output mark has at least one line (unless the whole scene has none).
        var merged: [Beat] = []
        var carryStage: [String] = []
        for beat in beats {
            if beat.lines.isEmpty {
                carryStage.append(contentsOf: beat.leadingStage)
                carryStage.append(contentsOf: beat.trailingStage)
            } else {
                var b = beat
                b.leadingStage.insert(contentsOf: carryStage, at: 0)
                carryStage.removeAll()
                merged.append(b)
            }
        }
        if !carryStage.isEmpty {
            if var last = merged.popLast() {
                last.trailingStage.append(contentsOf: carryStage)
                merged.append(last)
            } else {
                // No dialogue at all — keep a single stage-only beat.
                merged.append(Beat(leadingStage: carryStage))
            }
        }
        return merged
    }

    private static func shortened(_ s: String, to max: Int) -> String {
        s.count <= max ? s : String(s.prefix(max - 1)) + "…"
    }
}
