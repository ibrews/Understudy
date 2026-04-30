//
//  ScriptImporter.swift
//  Understudy
//
//  Manages user-imported play scripts. Scripts are stored as PlayScript JSON in
//  <Documents>/ImportedScripts/. Supports two input formats:
//    - .json  — must match the PlayScript schema
//    - .txt   — simple "CHARACTER: line" format, optional ACT/SCENE headers
//

import Foundation

public enum ScriptImporter {

    // MARK: - Storage

    public static var scriptsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ImportedScripts", isDirectory: true)
    }

    public static func loadAll() -> [PlayScript] {
        let dir = scriptsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(PlayScript.self, from: data)
            }
    }

    public static func save(_ script: PlayScript) throws {
        let dir = scriptsDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = sanitizeFilename(script.title) + ".json"
        let url = dir.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(script)
        try data.write(to: url, options: .atomicWrite)
    }

    public static func delete(_ script: PlayScript) {
        let filename = sanitizeFilename(script.title) + ".json"
        let url = scriptsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Import from file URL

    /// Called with a security-scoped URL from .fileImporter. Returns the parsed script.
    public static func `import`(from url: URL) throws -> PlayScript {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "json":
            return try importJSON(data)
        case "txt":
            let name = url.deletingPathExtension().lastPathComponent
            return try importTxt(data, suggestedName: name)
        default:
            // Try JSON then plain-text as fallback
            if let s = try? importJSON(data) { return s }
            let name = url.deletingPathExtension().lastPathComponent
            return try importTxt(data, suggestedName: name)
        }
    }

    // MARK: - JSON import

    static func importJSON(_ data: Data) throws -> PlayScript {
        do {
            return try JSONDecoder().decode(PlayScript.self, from: data)
        } catch {
            throw ImportError.invalidJSON(error.localizedDescription)
        }
    }

    // MARK: - Plain-text parser
    //
    // Supported formats:
    //   • Optional metadata header:  "TITLE: ...", "AUTHOR: ..."
    //   • Act heading:               "ACT I", "ACT ONE", "FIRST ACT"
    //   • Scene heading:             "SCENE I. Location" or "SCENE 1. Location"
    //   • Speaker + inline line:     "CHARACTER: dialogue"
    //   • Stage directions:          "[...]"  or  "_..._"
    //   • Blank lines separate beats (no effect on structure)
    //
    // If no ACT heading is found, all content goes in Act I, Scene I.

    static func importTxt(_ data: Data, suggestedName: String) throws -> PlayScript {
        guard let raw = String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unreadable
        }

        var title = suggestedName
        var author = ""
        var source = "User import"

        var lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        // Pull leading metadata lines.
        var idx = 0
        while idx < lines.count {
            let stripped = lines[idx].trimmingCharacters(in: .whitespaces)
            if let v = metadataValue("TITLE", from: stripped) { title = v; idx += 1 }
            else if let v = metadataValue("AUTHOR", from: stripped) { author = v; idx += 1 }
            else if let v = metadataValue("SOURCE", from: stripped) { source = v; idx += 1 }
            else if stripped.isEmpty { idx += 1 }
            else { break }
        }
        lines = Array(lines[idx...])

        // Build acts/scenes.
        var acts: [PlayScript.Act] = []
        var currentActNum = 0
        var currentActRoman = "I"
        var currentSceneNum = 0
        var currentSceneRoman = "I"
        var currentLocation = ""
        var entries: [PlayScript.Entry] = []
        var lineCounter = 0

        func commitScene() {
            guard !entries.isEmpty || currentSceneNum > 0 else { return }
            let scene = PlayScript.Scene(
                number: max(currentSceneNum, 1),
                roman: currentSceneRoman,
                location: currentLocation,
                entries: entries
            )
            if acts.isEmpty {
                acts.append(PlayScript.Act(number: 1, roman: "I", scenes: [scene]))
            } else {
                var last = acts.removeLast()
                last = PlayScript.Act(number: last.number, roman: last.roman, scenes: last.scenes + [scene])
                acts.append(last)
            }
            entries = []
            lineCounter = 0
        }

        func commitAct() {
            commitScene()
            currentSceneNum = 0
            currentSceneRoman = "I"
            currentLocation = ""
        }

        func ensureDefaultAct() {
            if acts.isEmpty && currentActNum == 0 {
                currentActNum = 1
                currentActRoman = "I"
                currentSceneNum = 1
                currentSceneRoman = "I"
            }
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)

            // Act heading
            if let (num, roman) = parseActHeading(line) {
                commitAct()
                currentActNum = num
                currentActRoman = roman
                acts.append(PlayScript.Act(number: num, roman: roman, scenes: []))
                continue
            }

            // Scene heading
            if let (num, roman, loc) = parseSceneHeading(line) {
                commitScene()
                currentSceneNum = num
                currentSceneRoman = roman
                currentLocation = loc
                ensureDefaultAct()
                continue
            }

            // Stage direction [...]
            if line.hasPrefix("[") && line.hasSuffix("]") && line.count > 2 {
                ensureDefaultAct()
                entries.append(.stage(text: String(line.dropFirst().dropLast())))
                continue
            }
            if line.hasPrefix("_") && line.hasSuffix("_") && line.count > 2 {
                ensureDefaultAct()
                entries.append(.stage(text: String(line.dropFirst().dropLast())))
                continue
            }

            // Speaker: dialogue  (colon separator — most common for user scripts)
            if let (speaker, text) = parseSpeakerLine(line) {
                ensureDefaultAct()
                lineCounter += 1
                let sceneN = max(currentSceneNum, 1)
                entries.append(.line(
                    character: speaker,
                    text: text,
                    lineID: "\(currentActNum).\(sceneN).\(lineCounter)"
                ))
                continue
            }

            // Everything else (blank lines, prose) — ignore silently.
        }

        commitAct()

        // If nothing was parsed, error out.
        let totalLines = acts.flatMap(\.scenes).flatMap(\.entries).filter(\.isLine).count
        if totalLines == 0 {
            throw ImportError.noLinesFound
        }

        return PlayScript(title: title, author: author, source: source, acts: acts)
    }

    // MARK: - Parsing helpers

    private static let romanMap = ["I":1,"II":2,"III":3,"IV":4,"V":5,"VI":6,"VII":7,"VIII":8,"IX":9,"X":10]
    private static let wordMap  = ["ONE":"I","TWO":"II","THREE":"III","FOUR":"IV","FIVE":"V",
                                   "FIRST":"I","SECOND":"II","THIRD":"III","FOURTH":"IV","FIFTH":"V"]

    private static let actRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:ACT\s+([IVXONE TWO THREE FOUR FIVE]+?)[\.\s]?$|(FIRST|SECOND|THIRD|FOURTH|FIFTH)\s+ACT[\.\s]?$)"#,
        options: [.caseInsensitive]
    )

    static func parseActHeading(_ line: String) -> (Int, String)? {
        let up = line.uppercased()
        // Simple: starts with "ACT " followed by roman or word
        guard up.hasPrefix("ACT ") || up.hasSuffix(" ACT") else { return nil }
        let parts = up.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // "ACT I", "ACT ONE"
        if parts.count >= 2 && parts[0] == "ACT" {
            let token = parts[1].replacingOccurrences(of: ".", with: "")
            return resolveActToken(token)
        }
        // "FIRST ACT", "SECOND ACT"
        if parts.count >= 2 && parts.last == "ACT" {
            let token = parts[0].replacingOccurrences(of: ".", with: "")
            return resolveActToken(token)
        }
        return nil
    }

    private static func resolveActToken(_ token: String) -> (Int, String)? {
        let t = token.uppercased()
        if let roman = wordMap[t] {
            let num = romanMap[roman] ?? 1
            return (num, roman)
        }
        if let num = romanMap[t] { return (num, t) }
        if let n = Int(t), n >= 1 {
            let romans = ["I","II","III","IV","V","VI","VII","VIII","IX","X"]
            return (n, romans[min(n-1, romans.count-1)])
        }
        return nil
    }

    static func parseSceneHeading(_ line: String) -> (Int, String, String)? {
        let up = line.uppercased()
        guard up.hasPrefix("SCENE") else { return nil }
        // "SCENE I. Location" or "SCENE 1. Location" or "SCENE I" or "SCENE 1"
        var rest = String(up.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix(".") { rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces) }
        if rest.isEmpty { return (1, "I", "") }

        let parts = rest.components(separatedBy: .init(charactersIn: ". "))
        let token = parts[0].replacingOccurrences(of: ".", with: "")
        var num = 1; var roman = "I"
        if let r = resolveActToken(token) { (num, roman) = r }
        else if let n = Int(token), n >= 1 {
            num = n
            let romans = ["I","II","III","IV","V","VI","VII","VIII","IX","X"]
            roman = romans[min(n-1, romans.count-1)]
        }
        // Location: everything after the first ". " or after the token
        let location: String
        if let dotRange = line.range(of: ". ", range: line.index(line.startIndex, offsetBy: min(6, line.count))..<line.endIndex) {
            location = String(line[dotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            location = ""
        }
        return (num, roman, location)
    }

    static func parseSpeakerLine(_ line: String) -> (String, String)? {
        guard let colonIdx = line.firstIndex(of: ":") else { return nil }
        let speaker = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let text = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        // Speaker must be ALL CAPS or Title Case, 2-40 chars, no lowercase-heavy strings
        guard speaker.count >= 2 && speaker.count <= 40 && !text.isEmpty else { return nil }
        let alphas = speaker.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard alphas.count >= 2 else { return nil }
        let uppercased = alphas.filter { CharacterSet.uppercaseLetters.contains($0) }
        // At least 50% uppercase letters → treat as a character name
        guard Double(uppercased.count) / Double(alphas.count) >= 0.5 else { return nil }
        return (speaker.uppercased(), text)
    }

    private static func metadataValue(_ key: String, from line: String) -> String? {
        let prefix = key + ":"
        guard line.uppercased().hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func sanitizeFilename(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: " -_"))
        return title
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
            .prefix(60)
            .description
    }
}

// MARK: - Errors

public enum ImportError: LocalizedError {
    case unreadable
    case invalidJSON(String)
    case noLinesFound

    public var errorDescription: String? {
        switch self {
        case .unreadable:    return "Could not read the file. Check the encoding is UTF-8."
        case .invalidJSON(let d): return "JSON didn't match PlayScript format: \(d)"
        case .noLinesFound:  return "No dialogue lines found. Use \"CHARACTER: line\" format."
        }
    }
}
