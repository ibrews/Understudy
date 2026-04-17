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
    private static func load(_ resourceName: String, fallbackTitle: String) -> PlayScript {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let script = try? JSONDecoder().decode(PlayScript.self, from: data) else {
            return PlayScript(
                title: "\(fallbackTitle) (unavailable)",
                author: "William Shakespeare",
                source: "",
                acts: []
            )
        }
        return script
    }

    /// Hamlet — parsed from Project Gutenberg eBook #1524. ~1100 lines of dialogue.
    public static let hamlet: PlayScript = load("hamlet", fallbackTitle: "Hamlet")

    /// Macbeth — Project Gutenberg eBook #1533. ~650 lines.
    public static let macbeth: PlayScript = load("macbeth", fallbackTitle: "Macbeth")

    /// A Midsummer Night's Dream — Project Gutenberg eBook #1514. ~485 lines.
    public static let midsummerNightsDream: PlayScript = load("midsummer", fallbackTitle: "A Midsummer Night's Dream")

    /// The Seagull (Chekhov) — Project Gutenberg eBook #1754. ~625 lines,
    /// 4 acts, Constance Garnett's translation. Parsed with the modern
    /// (speaker-inline) parser.
    public static let seagull: PlayScript = load("seagull", fallbackTitle: "The Seagull")

    /// The Importance of Being Earnest (Wilde) — Project Gutenberg eBook #844.
    /// ~870 lines, 3 acts. Parsed with the modern parser.
    public static let earnest: PlayScript = load("earnest", fallbackTitle: "The Importance of Being Earnest")

    /// The Cherry Orchard (Chekhov) — Project Gutenberg eBook #7986
    /// (Julius West translation). ~640 lines, 4 acts. Parsed with the modern
    /// (speaker-inline) parser.
    public static let cherryOrchard: PlayScript = load("cherry-orchard", fallbackTitle: "The Cherry Orchard")

    /// Three Sisters (Chekhov) — Project Gutenberg eBook #7986
    /// (Julius West translation). ~750 lines, 4 acts. Parsed with the modern
    /// (speaker-inline) parser.
    public static let threeSisters: PlayScript = load("three-sisters", fallbackTitle: "Three Sisters")

    /// Ghosts (Ibsen) — Project Gutenberg eBook #8492.
    /// ~1120 lines, 3 acts, William Archer translation.
    public static let ghosts: PlayScript = load("ghosts", fallbackTitle: "Ghosts")

    /// Uncle Vanya (Chekhov) — Project Gutenberg eBook #1756.
    /// ~520 lines, 4 acts.
    public static let uncleVanya: PlayScript = load("uncle_vanya", fallbackTitle: "Uncle Vanya")

    /// Salomé (Wilde) — Project Gutenberg eBook #42704.
    /// ~360 lines, single act, Lord Alfred Douglas translation.
    public static let salome: PlayScript = load("salome", fallbackTitle: "Salomé")

    /// All currently-bundled scripts. Extend when more plays are added to
    /// Resources/ and update this list — ScriptBrowser will pick up the new
    /// entries automatically.
    public static let all: [PlayScript] = [
        hamlet, macbeth, midsummerNightsDream,
        seagull, cherryOrchard, threeSisters, uncleVanya,
        earnest, salome,
        ghosts,
    ]
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
