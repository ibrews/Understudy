//
//  VoiceMatcher.swift
//  Understudy
//
//  Ported from Alex's Gemini-Live-ToDo AI Glasses teleprompter
//  (TeleprompterControlActivity.processSpokenText). Given the last few
//  words of transcribed speech and a TeleprompterDocument, find the
//  best-match position ahead of the current cursor and report the new
//  scrollProgress.
//
//  Algorithm:
//    1. Take the last 1..3 words of the spoken phrase.
//    2. Look for that phrase (lowercased) in a forward window starting at
//       the current cursor — searchWindowSize = 50 chars by default.
//    3. If found, new position = window_start + match_offset + phrase_length.
//    4. Only ever moves FORWARD — re-reads and stumbles don't drag the
//       cursor back mid-performance.
//
//  Why the last-words approach: speech recognition produces rolling
//  partial results; matching only the tail lets us keep advancing even
//  as the recognizer keeps updating its guess at earlier words.
//

import Foundation

nonisolated public struct VoiceMatcher {
    /// How far forward to search from the current cursor. 50 characters
    /// is about 10 words — enough tolerance for an actor's pause + rephrase
    /// without letting the matcher jump across a whole scene.
    public static let defaultSearchWindow: Int = 50

    public static func nextProgress(
        spoken: String,
        document: TeleprompterDocument,
        currentProgress: Double,
        searchWindow: Int = defaultSearchWindow
    ) -> Double? {
        let text = document.lowercasedText
        let totalLen = text.count
        guard totalLen > 0 else { return nil }

        let lower = spoken.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return nil }

        let currentIdx = Int(Double(totalLen) * currentProgress)
            .clamped(to: 0...(totalLen - 1))
        let searchEnd = min(currentIdx + searchWindow, totalLen)
        guard searchEnd > currentIdx else { return nil }

        let startIdx = text.index(text.startIndex, offsetBy: currentIdx)
        let endIdx = text.index(text.startIndex, offsetBy: searchEnd)
        let window = text[startIdx..<endIdx]

        // Build candidate search phrases: prefer longer (more unique) but
        // fall back to shorter if no match.
        let words = lower.split(separator: " ").map(String.init)
        let candidates: [String] = {
            var out: [String] = []
            if words.count >= 3 { out.append(words.suffix(3).joined(separator: " ")) }
            if words.count >= 2 { out.append(words.suffix(2).joined(separator: " ")) }
            if !words.isEmpty { out.append(words.last!) }
            return out
        }()

        for phrase in candidates {
            guard phrase.count >= 2 else { continue } // avoid matching "a"/"i"
            if let r = window.range(of: phrase) {
                let windowOffset = window.distance(from: window.startIndex, to: r.lowerBound)
                let matchEnd = currentIdx + windowOffset + phrase.count
                return Double(matchEnd) / Double(totalLen)
            }
        }
        return nil
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
