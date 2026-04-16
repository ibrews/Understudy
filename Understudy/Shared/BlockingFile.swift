//
//  BlockingFile.swift
//  Understudy
//
//  FileDocument for save/load + custom UTType for `.understudy` blockings.
//  A blocking file is just a JSON-encoded `Blocking` — same shape as the
//  wire format. This means you can also use any other tool that speaks
//  Understudy's protocol to generate or consume them.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    /// Declare a custom type. Not registered in Info.plist yet — exported as
    /// a conformance of `public.json` so open/save panels accept both `.json`
    /// and `.understudy`.
    static var understudyBlocking: UTType {
        UTType(exportedAs: "com.agilelens.understudy.blocking", conformingTo: .json)
    }
}

/// ReferenceFileDocument for Author mode's `fileExporter` / `fileImporter`.
/// Stateless — holds one blocking snapshot and encodes it on save.
public struct BlockingDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.understudyBlocking, .json] }
    public static var writableContentTypes: [UTType] { [.understudyBlocking, .json] }

    public var blocking: Blocking

    public init(blocking: Blocking) {
        self.blocking = blocking
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.blocking = try WireCoding.decoder.decode(Blocking.self, from: data)
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Pretty-print so a hand-authored file is hackable.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(blocking)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Autosave

/// Persists the current Blocking between launches via UserDefaults.
/// Cheap enough for documents of the size we care about (dozens of marks).
public enum BlockingAutosave {
    private static let key = "autosave.blocking.v1"

    public static func save(_ blocking: Blocking) {
        guard let data = try? WireCoding.encoder.encode(blocking) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    public static func load() -> Blocking? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? WireCoding.decoder.decode(Blocking.self, from: data)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

