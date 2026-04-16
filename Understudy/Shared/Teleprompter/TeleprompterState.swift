//
//  TeleprompterState.swift
//  Understudy
//
//  Observable state for the teleprompter view. Four scrolling inputs
//  contend to set `scrollProgress`:
//    1. Manual drag — user's finger
//    2. Auto-scroll timer — constant rate based on `speed`
//    3. Voice mode — SpeechRecognitionDriver calls in with new positions
//    4. Mark follow — when a performer enters a mark, we snap to that
//       mark's position unless the user has recently overridden manually
//
//  `lastUserOverrideAt` records the wall-clock time of the most recent
//  manual drag, so mark-follow can defer to the user for a few seconds.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class TeleprompterState {
    /// 0.0 = top of script, 1.0 = end.
    public var scrollProgress: Double = 0
    /// Number of chars per second for auto-scroll. ~14 cps ≈ theatrical pace.
    public var speed: Double = 14
    public var isAutoScrollEnabled: Bool = false
    public var isVoiceModeEnabled: Bool = false
    /// Follow the performer onto each mark — snap the teleprompter when
    /// the local performer's currentMarkID changes. On by default; turns
    /// off when the user manually scrolls.
    public var isMarkFollowEnabled: Bool = true
    /// Font size for the teleprompter body text, in points. Stage-readable
    /// defaults to fairly large.
    public var textSize: Double = 28
    /// The last displayed sliver of recognized speech — used for a small
    /// "heard: ..." indicator at the bottom of the teleprompter UI.
    public var lastHeardPhrase: String = ""
    /// Timestamp of most recent user drag override. When recent (< 3s),
    /// mark-follow defers to the user.
    public var lastUserOverrideAt: Date? = nil
    /// The currently-displayed document — derived from the Blocking.
    public var document: TeleprompterDocument = TeleprompterDocument(
        text: "", markOffsets: [], lowercasedText: "", dialogueRanges: []
    )

    public init() {}

    /// Rebuild from the current blocking. Called on open + whenever the
    /// blocking mutates.
    public func refreshDocument(from blocking: Blocking) {
        document = TeleprompterDocument.from(blocking)
    }

    // MARK: - Input handlers

    public func applyManualProgress(_ p: Double) {
        scrollProgress = max(0, min(1, p))
        lastUserOverrideAt = Date()
        // Manual drag implicitly turns off auto-scroll and mark-follow.
        isAutoScrollEnabled = false
    }

    public func applyVoiceMatch(_ p: Double) {
        // Voice mode only ever moves forward.
        if p > scrollProgress {
            scrollProgress = min(1, p)
        }
    }

    /// Snap to a mark's position if the user hasn't manually dragged recently.
    public func snapToMark(_ markID: ID) {
        guard isMarkFollowEnabled else { return }
        if let override = lastUserOverrideAt,
           Date().timeIntervalSince(override) < 3.0 { return }
        if let p = document.progress(forMark: markID) {
            scrollProgress = p
        }
    }
}
