//
//  DemoRunner.swift
//  Understudy
//
//  Auto-plays a curated demo blocking with cinematic timing — the "show me
//  what this thing does in 90 seconds" feature for FMX, conferences, and
//  showing the app to theatre friends in a London pub.
//
//  Drops a curated blocking into the store, then walks the GO cursor through
//  every actor mark with per-cue dwells: lines read at theatrical pace,
//  light cues hold for 1.5s so the wash registers, sound cues get 0.6s,
//  notes and waits respect their own timing.
//
//  Pause / resume / stop are all supported. The runner is @Observable so
//  views can render the title card, current beat, and progress in real time.
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
public final class DemoRunner {

    public enum Phase: Equatable {
        case idle
        case openingTitle(title: String, subtitle: String)
        case running(markIndex: Int, totalMarks: Int)
        case closingTitle(title: String, subtitle: String)
        case finished
    }

    public private(set) var phase: Phase = .idle
    public private(set) var currentMarkName: String? = nil
    public private(set) var currentMarkBlurb: String? = nil
    public private(set) var elapsedSeconds: Double = 0
    public private(set) var totalEstimatedSeconds: Double = 0
    /// Optional callout text shown alongside the running phase
    /// (e.g. "Camera mark — 24mm" when a camera mark fires).
    public private(set) var calloutText: String? = nil

    private var task: Task<Void, Never>?
    private weak var store: BlockingStore?
    private weak var fx: CueFXEngine?
    /// Saved blocking before the demo started — restored on stop().
    private var savedBlocking: Blocking?

    public init() {}

    public var isActive: Bool {
        if case .idle = phase { return false }
        if case .finished = phase { return false }
        return true
    }

    // MARK: - Lifecycle

    /// Start running a showcase. Replaces the current blocking with the
    /// showcase one for the duration of the run; restores on stop().
    public func start(
        showcase: DemoBlockings.ShowcaseEntry,
        store: BlockingStore,
        fx: CueFXEngine,
        sessionController: SessionController? = nil
    ) {
        // Tear down anything in flight.
        stop()

        self.store = store
        self.fx = fx

        // Save current state and load the showcase blocking.
        savedBlocking = store.blocking
        let showcaseBlocking = showcase.blocking()
        store.blocking = showcaseBlocking
        BlockingAutosave.save(showcaseBlocking)
        sessionController?.transport.send(
            .blockingSnapshot(showcaseBlocking),
            from: store.localPerformer?.id ?? ID()
        )

        // Reset GO cursor so playback starts from beat 1.
        fx.goCursor = -1

        let actorMarks = showcaseBlocking.marks
            .filter { $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }

        totalEstimatedSeconds = Double(showcase.estimatedSeconds)
        elapsedSeconds = 0
        phase = .openingTitle(
            title: showcase.title,
            subtitle: showcase.blurb
        )

        task = Task { @MainActor [weak self] in
            await self?.runLoop(actorMarks: actorMarks, showcase: showcase)
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        // Restore the user's pre-demo blocking if we replaced it.
        if let saved = savedBlocking, let store = store {
            store.blocking = saved
            BlockingAutosave.save(saved)
        }
        savedBlocking = nil
        phase = .idle
        currentMarkName = nil
        currentMarkBlurb = nil
        calloutText = nil
        elapsedSeconds = 0
    }

    // MARK: - Run loop

    private func runLoop(actorMarks: [Mark], showcase: DemoBlockings.ShowcaseEntry) async {
        // Opening title — hold for 3.5s so it lands.
        try? await Task.sleep(nanoseconds: 3_500_000_000)
        guard !Task.isCancelled else { return }

        // Walk every beat.
        for (i, mark) in actorMarks.enumerated() {
            guard !Task.isCancelled else { return }
            phase = .running(markIndex: i, totalMarks: actorMarks.count)
            currentMarkName = mark.name
            currentMarkBlurb = blurbForMark(mark, in: showcase)
            calloutText = calloutForMark(mark, in: showcase)

            // Fire all cues on this mark via the FX engine's GO path —
            // same code path as a real walk-on, so OSC + DMX + light flash
            // all happen identically.
            fx?.goForward()

            // Dwell time = sum of per-cue dwells, with a floor of 3s so
            // every beat reads even if the cues are quick.
            let dwell = max(3.0, dwellSeconds(for: mark.cues))
            try? await Task.sleep(nanoseconds: UInt64(dwell * 1_000_000_000))
            elapsedSeconds += dwell
        }

        guard !Task.isCancelled else { return }

        // Closing title.
        currentMarkName = nil
        currentMarkBlurb = nil
        calloutText = nil
        phase = .closingTitle(
            title: "End of \(showcase.title)",
            subtitle: "Built with Understudy. Try the same flow with your own piece — tap Author to start."
        )
        try? await Task.sleep(nanoseconds: 4_500_000_000)
        guard !Task.isCancelled else { return }

        phase = .finished
    }

    /// Time to spend on each mark — sum the per-cue dwells.
    private func dwellSeconds(for cues: [Cue]) -> Double {
        var total: Double = 0
        for cue in cues {
            switch cue {
            case .line(_, let text, _):
                // Theatrical pace ≈ 14 chars/sec, with a minimum of 1.8s
                // so even one-word lines breathe.
                let secs = max(1.8, Double(text.count) / 14.0)
                total += secs
            case .sfx:
                total += 0.7
            case .light:
                total += 1.5
            case .wait(_, let s):
                total += s
            case .note:
                total += 0.8
            }
        }
        return total
    }

    /// Optional blurb that surfaces the storytelling beat — pulled from a
    /// .note cue if present, otherwise the first line.
    private func blurbForMark(_ mark: Mark, in showcase: DemoBlockings.ShowcaseEntry) -> String? {
        for cue in mark.cues {
            if case .note(_, let text) = cue { return text }
        }
        for cue in mark.cues {
            if case .line(_, let text, _) = cue {
                return text.count > 80 ? String(text.prefix(80)) + "…" : text
            }
        }
        return nil
    }

    /// Showcase-specific callout that explains the mark to a viewer who's
    /// new to Understudy — e.g. "Camera mark · 24mm wide" for film mode.
    private func calloutForMark(_ mark: Mark, in showcase: DemoBlockings.ShowcaseEntry) -> String? {
        switch showcase.id {
        case "film":
            if mark.kind == .camera, let spec = mark.camera {
                return String(format: "Camera mark · %dmm · HFOV %.0f°",
                              Int(spec.focalLengthMM),
                              Double(spec.horizontalFOV) * 180 / .pi)
            }
            return "Actor mark · \(mark.cues.filter { if case .line = $0 { return true } else { return false } }.count) lines"
        case "theater":
            let charNames = Set(mark.cues.compactMap { cue -> String? in
                if case .line(_, _, let c) = cue { return c } else { return nil }
            })
            if !charNames.isEmpty {
                return charNames.sorted().joined(separator: " · ")
            }
            return nil
        case "gallery":
            return "Beat \(mark.sequenceIndex + 1) of 6"
        default:
            return nil
        }
    }
}
