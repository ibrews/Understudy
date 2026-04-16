//
//  TeleprompterDocument.swift
//  Understudy
//
//  Flattens a `Blocking` into a single flowing script with mark-boundary
//  markers. The teleprompter reads ONE document, not a tree of marks, so
//  voice matching and scroll math happen on a single String coordinate
//  system.
//
//  Format:
//    Mark 1 — Francisco's Post
//
//    FRANCISCO
//    You come most carefully upon your hour.
//
//    Mark 2 — Bernardo Enters
//
//    BERNARDO
//    'Tis now struck twelve. Get thee to bed, Francisco.
//    ...
//
//  Each mark's header occupies a range of characters; each line cue does
//  too. We keep per-mark character offsets so the teleprompter can snap
//  to the right position when a performer walks onto a mark.
//

import Foundation

nonisolated public struct TeleprompterDocument: Equatable {
    /// The full flowing text — headers, character labels, line content.
    public var text: String
    /// Per-mark index into `text`. When performer walks onto mark N, the
    /// teleprompter's scrollProgress jumps to `markOffsets[N]` / text.count.
    public var markOffsets: [MarkOffset]
    /// Lowercased copy, cached for voice matching.
    public var lowercasedText: String
    /// Character ranges that represent actual DIALOGUE (spoken) — voice
    /// matching only searches inside these ranges, so character-name headers
    /// or "Mark 3 —" banners don't confuse the matcher.
    public var dialogueRanges: [Range<Int>]
    /// Per-line-cue metadata — (markID, cueID, endOffset) tuples. Used
    /// for voice-driven cue firing: when scrollProgress crosses a line's
    /// endOffset, the teleprompter reports it to the CueFXEngine which
    /// then fires the remaining non-line cues on that mark.
    public var lineCueEnds: [LineCueMarker]

    public struct MarkOffset: Equatable, Sendable {
        public let markID: ID
        public let name: String
        /// Character offset into `text` of the mark's header.
        public let headerStart: Int
        /// Character offset into `text` where this mark's first line starts.
        /// For marks with no line cues, equals headerStart.
        public let firstLineStart: Int
        /// Offset just past this mark's last line.
        public let endOffset: Int
    }

    public struct LineCueMarker: Equatable, Sendable {
        public let markID: ID
        public let cueID: ID
        /// Character offset in `text` of the last character of this line's
        /// dialogue. When scrollProgress passes this, the line is "said."
        public let endOffset: Int
    }

    /// Build from a blocking. Only considers marks with `kind == .actor` and
    /// `sequenceIndex >= 0` (camera marks + freeform marks don't appear in
    /// the teleprompter flow — they're pre-viz, not cue points).
    public static func from(_ blocking: Blocking) -> TeleprompterDocument {
        let ordered = blocking.marks
            .filter { $0.kind == .actor && $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }

        var builder = ""
        var markOffsets: [MarkOffset] = []
        var dialogueRanges: [Range<Int>] = []
        var lineCueEnds: [LineCueMarker] = []

        for (i, mark) in ordered.enumerated() {
            let headerStart = builder.count
            let header = "\(mark.sequenceIndex + 1). \(mark.name.uppercased())\n"
            builder += header

            let beforeLines = builder.count
            for cue in mark.cues {
                guard case .line(let cueID, let text, let character) = cue else { continue }
                // Character label on its own line, uppercased.
                if let character, !character.isEmpty {
                    builder += "\n\(character.uppercased())\n"
                } else {
                    builder += "\n"
                }
                let spokenStart = builder.count
                builder += text
                let spokenEnd = builder.count
                dialogueRanges.append(spokenStart..<spokenEnd)
                lineCueEnds.append(LineCueMarker(
                    markID: mark.id,
                    cueID: cueID,
                    endOffset: spokenEnd
                ))
                builder += "\n"
            }
            // Blank line between marks.
            if i < ordered.count - 1 { builder += "\n" }

            markOffsets.append(MarkOffset(
                markID: mark.id,
                name: mark.name,
                headerStart: headerStart,
                firstLineStart: beforeLines,
                endOffset: builder.count
            ))
        }

        return TeleprompterDocument(
            text: builder,
            markOffsets: markOffsets,
            lowercasedText: builder.lowercased(),
            dialogueRanges: dialogueRanges,
            lineCueEnds: lineCueEnds
        )
    }

    /// Given two scroll positions (old and new, both 0…1), return the line
    /// cues whose endOffset lies strictly between them. Used by voice mode
    /// to detect which lines the performer just finished speaking.
    public func linesFinishedBetween(oldProgress: Double, newProgress: Double) -> [LineCueMarker] {
        guard !text.isEmpty, newProgress > oldProgress else { return [] }
        let total = Double(text.count)
        let oldIdx = Int(oldProgress * total)
        let newIdx = Int(newProgress * total)
        return lineCueEnds.filter { $0.endOffset > oldIdx && $0.endOffset <= newIdx }
    }

    /// Given a scrollProgress (0...1), return the mark the user is currently
    /// reading (or last passed). Nil if the doc has no marks.
    public func markAt(progress: Double) -> MarkOffset? {
        guard !markOffsets.isEmpty, !text.isEmpty else { return nil }
        let idx = Int(Double(text.count) * progress.clamped(to: 0...1))
        var last: MarkOffset? = nil
        for mo in markOffsets {
            if mo.headerStart <= idx { last = mo } else { break }
        }
        return last ?? markOffsets.first
    }

    /// Character index within `text` that corresponds to the given mark's
    /// header. Used to snap progress when a performer walks onto a mark.
    public func progress(forMark id: ID) -> Double? {
        guard !text.isEmpty else { return nil }
        guard let mo = markOffsets.first(where: { $0.markID == id }) else { return nil }
        return Double(mo.headerStart) / Double(text.count)
    }

    /// True if the given character index is inside a dialogue range (used to
    /// color the active word — we only highlight actual spoken text, not
    /// headers or character labels).
    public func isDialogue(at index: Int) -> Bool {
        dialogueRanges.contains { $0.contains(index) }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
