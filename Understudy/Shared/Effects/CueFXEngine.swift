//
//  CueFXEngine.swift
//  Understudy
//
//  Turns `FiredCue` events in the store's cueQueue into actual effects:
//  system sounds for SFX, a flash state for lighting, a countdown for waits.
//  The engine itself is @Observable so SwiftUI views can drive overlays and
//  Reality entities off of its published state.
//

import Foundation
import SwiftUI
import Observation

#if canImport(AudioToolbox)
import AudioToolbox
#endif

@Observable
@MainActor
public final class CueFXEngine {

    /// A transient lighting flash. Views read this and fade out over `fadeDuration`.
    public struct FlashState: Equatable {
        public let color: Color
        /// Initial alpha at the moment the cue fires. Flash holds for `holdDuration`
        /// then fades to zero over `fadeDuration`.
        public let alpha: Double
        public let holdDuration: Double
        public let fadeDuration: Double
        public let firedAt: Date
        public let cueID: UUID

        public init(
            color: Color,
            alpha: Double = 0.65,
            holdDuration: Double = 0.25,
            fadeDuration: Double = 0.5,
            firedAt: Date = Date(),
            cueID: UUID = UUID()
        ) {
            self.color = color
            self.alpha = alpha
            self.holdDuration = holdDuration
            self.fadeDuration = fadeDuration
            self.firedAt = firedAt
            self.cueID = cueID
        }
    }

    /// Lightweight debug log entry.
    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let cue: Cue
        public let markName: String
        public let at: Date
    }

    /// Most recent flash. Nil when no light cue is active.
    public var currentFlash: FlashState? = nil

    /// When a `.wait` cue fires, this counts down (in seconds) until it clears.
    public var currentHold: Double? = nil

    /// A rolling buffer of recent cues for the debug HUD.
    public var recentLog: [LogEntry] = []
    public let maxLog: Int = 24

    private weak var store: BlockingStore?
    private var drainTask: Task<Void, Never>?
    private var flashClearTask: Task<Void, Never>?
    private var holdTask: Task<Void, Never>?
    /// Track the last mark name we dispatched a cue from, so we can send
    /// a single `/understudy/mark/enter` OSC message per entry rather than
    /// spamming one per cue.
    private var lastDispatchedMark: String?

    /// Optional OSC bridge — when configured + enabled, every fired cue is
    /// also sent out over UDP to a listening host (QLab, TouchDesigner, etc.).
    public let osc = OSCBridge()

    /// Inbound OSC receiver. When a stage manager sends `/understudy/go`
    /// from QLab, we fire the next mark's cues as though a performer had
    /// just walked onto it. Gives stage management control of pacing
    /// without requiring performers to actually move.
    public let oscIn = OSCReceiver()

    /// Sequence index of the last mark advanced by an OSC /go. -1 means
    /// "no GO has been sent yet; next /go fires the first mark." Survives
    /// across performer moves — purely driven by the inbound bus.
    public var goCursor: Int = -1

    /// Cues fired by voice mode this run. Prevents a cue from firing
    /// twice when scroll progress bounces. Cleared on reset().
    private var voiceFiredCueIDs: Set<ID> = []

    public init() {}

    /// Attach the engine to a store. Safe to call once at app launch.
    public func attach(store: BlockingStore) {
        self.store = store
        drainTask?.cancel()
        drainTask = Task { [weak self] in
            await self?.runDrainLoop()
        }
        // Wire the inbound OSC receiver.
        oscIn.onMessage = { [weak self] msg in
            self?.handleOSCInbound(msg)
        }
    }

    /// Configure and optionally start the inbound OSC receiver. Called
    /// when the user edits the OSC settings.
    public func configureOSCReceive(port: UInt16, enabled: Bool) {
        if enabled {
            oscIn.start(port: port)
        } else {
            oscIn.stop()
        }
    }

    private func handleOSCInbound(_ msg: OSCReceiver.Message) {
        switch msg.address {
        case "/understudy/go", "/understudy/next":
            goForward()
        case "/understudy/back":
            goBack()
        case "/understudy/reset":
            goCursor = -1
        case "/understudy/mark":
            if let idx = msg.firstInt {
                goToMark(sequenceIndex: Int(idx))
            }
        default:
            break
        }
    }

    /// Advance the cursor and fire the next mark's cues.
    public func goForward() {
        guard let store else { return }
        let ordered = store.blocking.marks
            .filter { $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        guard !ordered.isEmpty else { return }
        let next = goCursor + 1
        if next < ordered.count {
            let mark = ordered[next]
            goCursor = next
            fireMarkAsIfEntered(mark)
        }
    }

    public func goBack() {
        guard let store else { return }
        let ordered = store.blocking.marks
            .filter { $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        guard !ordered.isEmpty else { return }
        let prev = goCursor - 1
        if prev >= 0 && prev < ordered.count {
            let mark = ordered[prev]
            goCursor = prev
            fireMarkAsIfEntered(mark)
        }
    }

    public func goToMark(sequenceIndex: Int) {
        guard let store else { return }
        let ordered = store.blocking.marks
            .filter { $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        guard let idx = ordered.firstIndex(where: { $0.sequenceIndex == sequenceIndex }) else {
            return
        }
        goCursor = idx
        fireMarkAsIfEntered(ordered[idx])
    }

    /// Enqueue every cue on the given mark as though a performer just entered
    /// it. The rest of the system (UI + OSC outbound + FX) treats it
    /// identically to a real walk-on.
    private func fireMarkAsIfEntered(_ mark: Mark) {
        guard let store else { return }
        let performer = store.localPerformer?.id ?? ID("stage-manager")
        for cue in mark.cues {
            store.cueQueue.append(BlockingStore.FiredCue(
                cue: cue, markName: mark.name, performerID: performer
            ))
        }
    }

    // MARK: - Voice-driven cue firing

    /// Called by the teleprompter when voice mode detects the performer
    /// just finished speaking a line. Fires all subsequent non-line cues
    /// on the same mark, up to the next line (or end of mark). Already-
    /// fired cues are skipped.
    ///
    /// Returns the number of cues fired, so the UI can show feedback.
    @discardableResult
    public func voiceLineFinished(cueID: ID, on markID: ID) -> Int {
        guard let store else { return 0 }
        guard let mark = store.blocking.marks.first(where: { $0.id == markID }) else {
            return 0
        }
        guard let lineIdx = mark.cues.firstIndex(where: { $0.id == cueID }) else {
            return 0
        }
        // Mark the line itself as "voice-handled" so we don't re-visit it.
        voiceFiredCueIDs.insert(cueID)

        let performer = store.localPerformer?.id ?? ID("voice")
        var fired = 0
        for cue in mark.cues.dropFirst(lineIdx + 1) {
            // Stop at the next line — that's a future voice trigger.
            if case .line = cue { break }
            if voiceFiredCueIDs.contains(cue.id) { continue }
            voiceFiredCueIDs.insert(cue.id)
            store.cueQueue.append(BlockingStore.FiredCue(
                cue: cue, markName: mark.name, performerID: performer
            ))
            fired += 1
        }
        return fired
    }

    /// Clear voice-fired memory. Called when the teleprompter resets to
    /// the top so a second read of the script fires cues again.
    public func resetVoiceFiredCues() {
        voiceFiredCueIDs.removeAll()
    }

    public func detach() {
        drainTask?.cancel()
        drainTask = nil
        flashClearTask?.cancel()
        holdTask?.cancel()
    }

    // MARK: - Drain loop

    /// Polls the store's cueQueue on the MainActor. Every ~60 Hz is plenty —
    /// the queue is only appended to on pose updates (~30 Hz).
    private func runDrainLoop() async {
        while !Task.isCancelled {
            guard let store else {
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }
            if !store.cueQueue.isEmpty {
                let batch = store.cueQueue
                // Drain by id so we don't fight the store's own drainCue API.
                for fired in batch {
                    dispatch(fired)
                    store.drainCue(fired.id)
                }
            }
            try? await Task.sleep(nanoseconds: 16_000_000) // ~60 Hz
        }
    }

    /// Fire a cue once, without requiring it to be enqueued by mark entry.
    /// Used by the mark editor "preview" buttons so authors can hear/see
    /// a cue immediately while they're building it.
    public func preview(_ cue: Cue) {
        appendLog(cue: cue, markName: "Preview")
        switch cue {
        case .line: break
        case .sfx(_, let name): playSFX(named: name)
        case .light(_, let color, let intensity): flash(color: color, intensity: intensity)
        case .wait(_, let seconds): beginHold(seconds)
        case .note: break
        }
    }

    private func dispatch(_ fired: BlockingStore.FiredCue) {
        appendLog(cue: fired.cue, markName: fired.markName)
        // Emit one mark-enter OSC per mark transition (not per cue).
        if fired.markName != lastDispatchedMark {
            lastDispatchedMark = fired.markName
            let seq = store?.blocking.marks.first { $0.name == fired.markName }?.sequenceIndex ?? -1
            osc.sendMarkEnter(name: fired.markName, sequenceIndex: seq)
        }
        switch fired.cue {
        case .line:
            // UI owns lines; engine just logs.
            break
        case .sfx(_, let name):
            playSFX(named: name)
        case .light(_, let color, let intensity):
            flash(color: color, intensity: intensity)
        case .wait(_, let seconds):
            beginHold(seconds)
        case .note:
            break
        }
        // Forward the cue to any listening OSC target (QLab etc.).
        osc.sendCue(fired.cue)
    }

    private func appendLog(cue: Cue, markName: String) {
        recentLog.append(LogEntry(cue: cue, markName: markName, at: Date()))
        if recentLog.count > maxLog {
            recentLog.removeFirst(recentLog.count - maxLog)
        }
    }

    // MARK: - SFX

    private func playSFX(named name: String) {
        #if canImport(AudioToolbox)
        let id = Self.systemSoundID(for: name)
        AudioServicesPlaySystemSound(id)
        #endif
    }

    /// Map well-known cue names to iOS system sound IDs. These are built-in
    /// to every Apple platform so we don't have to ship audio assets.
    static func systemSoundID(for name: String) -> UInt32 {
        switch name.lowercased() {
        case "thunder":  return 1005
        case "bell":     return 1013
        case "chime":    return 1022
        case "knock":    return 1306
        case "applause": return 1016
        default:         return 1007
        }
    }

    // MARK: - Lighting flash

    private func flash(color: LightColor, intensity: Float) {
        let swiftColor = Self.color(for: color)
        // Clamp alpha to a theatrical ceiling so full-white cues don't blind.
        let alpha = min(0.85, max(0.3, Double(intensity)))
        let state = FlashState(
            color: swiftColor,
            alpha: alpha,
            holdDuration: 0.25,
            fadeDuration: 0.5
        )
        currentFlash = state
        flashClearTask?.cancel()
        flashClearTask = Task { [weak self, cueID = state.cueID] in
            let total = state.holdDuration + state.fadeDuration
            try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }
                if self.currentFlash?.cueID == cueID {
                    self.currentFlash = nil
                }
            }
        }
    }

    public static func color(for lightColor: LightColor) -> Color {
        switch lightColor {
        case .warm:     return Color(red: 1.0, green: 0.85, blue: 0.55)
        case .cool:     return Color(red: 0.55, green: 0.85, blue: 1.0)
        case .red:      return .red
        case .blue:     return .blue
        case .green:    return .green
        case .amber:    return Color(red: 1.0, green: 0.75, blue: 0.2)
        case .blackout: return .black
        }
    }

    // MARK: - Hold / wait

    private func beginHold(_ seconds: Double) {
        currentHold = seconds
        holdTask?.cancel()
        holdTask = Task { [weak self] in
            let tickNS: UInt64 = 100_000_000 // 0.1 s
            var remaining = seconds
            while remaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: tickNS)
                remaining -= 0.1
                let clamped = max(0, remaining)
                await MainActor.run { [weak self] in
                    self?.currentHold = clamped > 0 ? clamped : nil
                }
            }
        }
    }
}
