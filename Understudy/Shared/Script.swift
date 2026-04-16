//
//  Script.swift
//  Understudy
//
//  Structured play script — acts → scenes → entries (lines or stage directions).
//  Used by Author mode's Script Browser to let the user add lines directly
//  from the text as cues, rather than typing them by hand.
//
//  Parsing lives in /tmp/parse_hamlet.py (checked in under /scripts/) and
//  produces Resources/hamlet.json, which is bundled at build time.
//

import Foundation

nonisolated public struct PlayScript: Codable, Sendable, Identifiable {
    public var title: String
    public var author: String
    public var source: String
    public var acts: [Act]
    public var id: String { title }

    public struct Act: Codable, Sendable, Identifiable, Hashable {
        public var number: Int
        public var roman: String
        public var scenes: [Scene]
        public var id: Int { number }
    }

    public struct Scene: Codable, Sendable, Identifiable, Hashable {
        public var number: Int
        public var roman: String
        public var location: String
        public var entries: [Entry]
        /// Composite id: "<actNum>.<sceneNum>" for stable lookups.
        public var id: String { "\(number).\(roman)" }
    }

    public enum Entry: Codable, Sendable, Hashable, Identifiable {
        case line(character: String, text: String, lineID: String)
        case stage(text: String)

        public var id: String {
            switch self {
            case .line(_, _, let lineID): return "line:\(lineID)"
            case .stage(let text): return "stage:\(text.hashValue)"
            }
        }

        /// "Act.Scene.LineNumber" for line entries; nil for stage directions.
        public var lineID: String? {
            if case .line(_, _, let id) = self { return id }
            return nil
        }

        public var isLine: Bool {
            if case .line = self { return true }
            return false
        }

        // Custom Codable to match the JSON shape: {"kind": "line"|"stage", ...}
        enum CodingKeys: String, CodingKey { case kind, character, text, lineID }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(String.self, forKey: .kind)
            switch kind {
            case "line":
                self = .line(
                    character: try c.decode(String.self, forKey: .character),
                    text: try c.decode(String.self, forKey: .text),
                    lineID: try c.decode(String.self, forKey: .lineID)
                )
            case "stage":
                self = .stage(text: try c.decode(String.self, forKey: .text))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .kind, in: c,
                    debugDescription: "Unknown entry kind: \(kind)"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .line(let character, let text, let lineID):
                try c.encode("line", forKey: .kind)
                try c.encode(character, forKey: .character)
                try c.encode(text, forKey: .text)
                try c.encode(lineID, forKey: .lineID)
            case .stage(let text):
                try c.encode("stage", forKey: .kind)
                try c.encode(text, forKey: .text)
            }
        }
    }
}

// MARK: - Bundled scripts

public enum Scripts {
    /// Full Hamlet, parsed from Project Gutenberg eBook #1524. ~1100 lines.
    public static let hamlet: PlayScript = {
        guard let url = Bundle.main.url(forResource: "hamlet", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let script = try? JSONDecoder().decode(PlayScript.self, from: data) else {
            // Fallback: empty script. Should never hit this if the bundle includes the JSON.
            return PlayScript(
                title: "Hamlet (unavailable)",
                author: "William Shakespeare",
                source: "",
                acts: []
            )
        }
        return script
    }()

    /// All currently-bundled scripts. Today just Hamlet; extend when more plays
    /// are added to the Resources folder.
    public static let all: [PlayScript] = [hamlet]
}

// MARK: - Helpers

public extension PlayScript {
    /// Flat list of all line entries in reading order, carrying their
    /// Act/Scene location for header rendering.
    struct LocatedLine: Identifiable, Hashable {
        public let actRoman: String
        public let sceneRoman: String
        public let location: String
        public let character: String
        public let text: String
        public let lineID: String
        public var id: String { lineID }
    }

    var allLines: [LocatedLine] {
        var out: [LocatedLine] = []
        out.reserveCapacity(1200)
        for act in acts {
            for scene in act.scenes {
                for entry in scene.entries {
                    if case .line(let character, let text, let lineID) = entry {
                        out.append(LocatedLine(
                            actRoman: act.roman,
                            sceneRoman: scene.roman,
                            location: scene.location,
                            character: character,
                            text: text,
                            lineID: lineID
                        ))
                    }
                }
            }
        }
        return out
    }

    /// Case-insensitive full-text filter over character + line text.
    func linesMatching(_ query: String) -> [LocatedLine] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return allLines }
        let needle = trimmed.lowercased()
        return allLines.filter {
            $0.text.lowercased().contains(needle) ||
            $0.character.lowercased().contains(needle)
        }
    }
}
