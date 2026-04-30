//
//  AudioImporter.swift
//  Understudy
//
//  Manages user-imported .wav files for SFX cues.
//  Files are stored in <Documents>/ImportedAudio/<name>.wav.
//  The cue name is the filename without extension (lowercased, stripped).
//

import Foundation

public enum AudioImporter {

    public static var audioDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ImportedAudio", isDirectory: true)
    }

    /// All imported cue names (lowercased, sorted).
    public static func loadAll() -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: audioDirectory, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension.lowercased() == "wav" }
            .map { $0.deletingPathExtension().lastPathComponent.lowercased() }
            .sorted()
    }

    /// URL for a given cue name, or nil if it hasn't been imported.
    public static func url(for name: String) -> URL? {
        let url = audioDirectory.appendingPathComponent(name.lowercased() + ".wav")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Import a .wav from a security-scoped URL (from .fileImporter).
    /// Returns the cue name on success.
    public static func `import`(from url: URL) throws -> String {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        guard url.pathExtension.lowercased() == "wav" else {
            throw AudioImportError.notWav
        }

        let rawName = url.deletingPathExtension().lastPathComponent
        let cueName = sanitize(rawName)
        guard !cueName.isEmpty else { throw AudioImportError.badFilename }

        try FileManager.default.createDirectory(
            at: audioDirectory, withIntermediateDirectories: true
        )

        let dest = audioDirectory.appendingPathComponent(cueName + ".wav")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: url, to: dest)
        return cueName
    }

    public static func delete(name: String) {
        let url = audioDirectory.appendingPathComponent(name.lowercased() + ".wav")
        try? FileManager.default.removeItem(at: url)
    }

    private static func sanitize(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        return raw
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
            .lowercased()
            .prefix(40)
            .description
    }
}

public enum AudioImportError: LocalizedError {
    case notWav
    case badFilename

    public var errorDescription: String? {
        switch self {
        case .notWav:      return "Only .wav files are supported."
        case .badFilename: return "The filename could not be used as a cue name."
        }
    }
}
