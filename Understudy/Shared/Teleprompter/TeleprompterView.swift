//
//  TeleprompterView.swift
//  Understudy
//
//  Cross-platform teleprompter. Opens as a sheet on iPhone and as a
//  separate window on visionOS. Shares rendering + scroll logic; only
//  the presentation chrome differs.
//
//  Karaoke rendering (inspired by Alex's Gemini-Live-ToDo teleprompter):
//    - Past text rendered in a dimmed gray
//    - A narrow "active" window of ~30 chars rendered cyan
//    - Future text in readable white
//
//  Four scrolling inputs (see TeleprompterState):
//    - Manual drag (two-finger or scroll wheel)
//    - Auto-scroll at `speed` chars/sec
//    - Voice match via SpeechRecognitionDriver
//    - Mark follow: snap when performer enters a new mark (unless
//      user-overridden recently)
//

import SwiftUI
import Combine
#if canImport(Speech)
import Speech
#endif

public struct TeleprompterView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(CueFXEngine.self) private var fx
    @Environment(\.dismiss) private var dismiss
    @State private var state = TeleprompterState()
    #if canImport(Speech)
    @State private var speech = SpeechRecognitionDriver()
    #endif
    @State private var autoScrollTimer: Timer?
    @State private var lastMarkID: ID?
    @State private var voiceAuthRequested = false
    /// Last count of auto-fired cues, for the "🔥 3 cues fired" feedback flash.
    @State private var autoFireFlashCount: Int = 0
    @State private var autoFireFlashAt: Date?

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if state.document.text.isEmpty {
                emptyState
            } else {
                scrollingText
            }
            VStack {
                topBar
                Spacer()
                controls
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            state.refreshDocument(from: store.blocking)
            // Snap to current performer mark if there is one.
            if let markID = store.localPerformer?.currentMarkID {
                state.snapToMark(markID)
                lastMarkID = markID
            }
        }
        .onDisappear {
            stopAutoScroll()
            stopVoiceMode()
        }
        // Rebuild document if the blocking mutates while the teleprompter is open.
        .onChange(of: store.blocking.modifiedAt) { _, _ in
            state.refreshDocument(from: store.blocking)
        }
        // Mark-follow.
        .onChange(of: store.localPerformer?.currentMarkID ?? ID("")) { _, newID in
            guard newID != lastMarkID else { return }
            lastMarkID = newID
            state.snapToMark(newID)
        }
    }

    // MARK: - Top bar

    @ViewBuilder private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Text(store.blocking.title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            if let mark = state.document.markAt(progress: state.scrollProgress) {
                Text(mark.name)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "text.quote")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            Text("No lines on this blocking yet.")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
            Text("Author mode → tap a mark → Pick from Hamlet…")
                .font(.body)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Scrolling text

    @ViewBuilder private var scrollingText: some View {
        GeometryReader { geo in
            let totalLen = state.document.text.count
            let cursor = Int(Double(totalLen) * state.scrollProgress)
                .clamped(to: 0...max(0, totalLen - 1))
            // Active cyan window — about 30 chars, same as Alex's teleprompter.
            let activeWindow = 30
            let activeEnd = (cursor + activeWindow).clamped(to: 0...totalLen)

            let annotated: AttributedString = {
                var past = AttributedString(String(state.document.text.prefix(cursor)))
                past.foregroundColor = .white.opacity(0.35)
                var active = AttributedString(
                    String(state.document.text[
                        state.document.text.index(state.document.text.startIndex, offsetBy: cursor)
                        ..<
                        state.document.text.index(state.document.text.startIndex, offsetBy: activeEnd)
                    ])
                )
                active.foregroundColor = .cyan
                var future = AttributedString(
                    String(state.document.text[
                        state.document.text.index(state.document.text.startIndex, offsetBy: activeEnd)...
                    ])
                )
                future.foregroundColor = .white
                var joined = past
                joined.append(active)
                joined.append(future)
                return joined
            }()

            // Center the active window at viewport middle. The full text
            // renders at (state.scrollProgress * contentHeight) above center.
            // We do this with a vertical offset rather than a ScrollView so
            // we have exact per-frame control — Alex's approach.
            let viewport = geo.size.height
            // Rough: each line is approximately textSize * 1.4 tall. We don't
            // have TextLayoutResult in SwiftUI, so the teleprompter uses the
            // whole text's fractional scroll — imprecise but works cleanly.
            let estimatedLineHeight = CGFloat(state.textSize * 1.4)
            let estimatedContentHeight = CGFloat(totalLen) / 60 * estimatedLineHeight
            let scrollPixels = CGFloat(state.scrollProgress) * max(0, estimatedContentHeight - viewport)

            Text(annotated)
                .font(.system(size: CGFloat(state.textSize), weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(CGFloat(state.textSize) * 0.35)
                .frame(maxWidth: geo.size.width * 0.9, alignment: .top)
                .offset(y: viewport * 0.3 - scrollPixels)
                .animation(.easeOut(duration: 0.25), value: state.scrollProgress)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    let delta = -value.translation.height / 1200
                    state.applyManualProgress(state.scrollProgress + delta)
                }
        )
    }

    // MARK: - Controls

    @ViewBuilder private var controls: some View {
        VStack(spacing: 10) {
            if let flashAt = autoFireFlashAt,
               Date().timeIntervalSince(flashAt) < 2.0 {
                Text("🔥 \(autoFireFlashCount) cue\(autoFireFlashCount == 1 ? "" : "s") fired")
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.85), in: Capsule())
                    .foregroundStyle(.black)
                    .transition(.opacity.combined(with: .scale))
            }
            if !state.lastHeardPhrase.isEmpty {
                Text("heard: \(state.lastHeardPhrase)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.cyan.opacity(0.7))
                    .lineLimit(1)
                    .transition(.opacity)
            }
            HStack(spacing: 16) {
                Button {
                    state.scrollProgress = 0
                    state.lastUserOverrideAt = Date()
                    fx.resetVoiceFiredCues()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.15))

                Button {
                    state.isAutoScrollEnabled.toggle()
                    if state.isAutoScrollEnabled { startAutoScroll() } else { stopAutoScroll() }
                } label: {
                    Image(systemName: state.isAutoScrollEnabled ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.isAutoScrollEnabled ? .orange : .white.opacity(0.2))

                VStack {
                    Text("Speed  \(Int(state.speed)) cps")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                    Slider(value: $state.speed, in: 4...40, step: 1)
                        .frame(width: 160)
                }

                VStack {
                    Text("Size")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Slider(value: $state.textSize, in: 18...56, step: 1)
                        .frame(width: 100)
                }

                #if canImport(Speech)
                Button {
                    toggleVoiceMode()
                } label: {
                    Image(systemName: state.isVoiceModeEnabled ? "mic.fill" : "mic.slash")
                        .font(.title2)
                        .frame(width: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.isVoiceModeEnabled ? .red : .white.opacity(0.2))

                // Auto-fire toggle — only meaningful when voice mode is on.
                // Orange flame = the show runs itself; grey = voice just
                // scrolls the teleprompter.
                Button {
                    state.isAutoFireEnabled.toggle()
                } label: {
                    Image(systemName: state.isAutoFireEnabled ? "flame.fill" : "flame")
                        .font(.title2)
                        .frame(width: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.isAutoFireEnabled ? .orange : .white.opacity(0.2))
                .disabled(!state.isVoiceModeEnabled)
                .help(state.isAutoFireEnabled
                      ? "Voice finishes a line → SFX/light/wait cues auto-fire"
                      : "Voice only scrolls the teleprompter; cues stay manual")
                #endif
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Auto-scroll

    private func startAutoScroll() {
        stopAutoScroll()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                let totalLen = state.document.text.count
                guard totalLen > 0, state.isAutoScrollEnabled else { return }
                let charsPerFrame = state.speed / 30
                let progressStep = charsPerFrame / Double(totalLen)
                state.scrollProgress = min(1, state.scrollProgress + progressStep)
                if state.scrollProgress >= 1 { stopAutoScroll() }
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        state.isAutoScrollEnabled = false
    }

    // MARK: - Voice mode

    #if canImport(Speech)
    private func toggleVoiceMode() {
        if state.isVoiceModeEnabled {
            stopVoiceMode()
        } else {
            if !voiceAuthRequested {
                voiceAuthRequested = true
                speech.requestAuthorization { granted in
                    if granted { self.startVoiceMode() }
                }
            } else {
                startVoiceMode()
            }
        }
    }

    private func startVoiceMode() {
        state.isVoiceModeEnabled = true
        state.isAutoScrollEnabled = false
        speech.onHeard = { transcript in
            Task { @MainActor in
                state.lastHeardPhrase = String(transcript.suffix(64))
                if let p = VoiceMatcher.nextProgress(
                    spoken: transcript,
                    document: state.document,
                    currentProgress: state.scrollProgress
                ) {
                    let oldProgress = state.scrollProgress
                    state.applyVoiceMatch(p)
                    // Auto-fire: check which line cues the jump crossed,
                    // then ask the engine to fire their trailing SFX/light/wait.
                    if state.isAutoFireEnabled {
                        let finished = state.document.linesFinishedBetween(
                            oldProgress: oldProgress,
                            newProgress: state.scrollProgress
                        )
                        var total = 0
                        for marker in finished {
                            total += fx.voiceLineFinished(cueID: marker.cueID, on: marker.markID)
                        }
                        if total > 0 {
                            autoFireFlashCount = total
                            autoFireFlashAt = Date()
                        }
                    }
                }
            }
        }
        speech.start()
    }

    private func stopVoiceMode() {
        state.isVoiceModeEnabled = false
        speech.stop()
    }
    #else
    private func startVoiceMode() {}
    private func stopVoiceMode() {}
    #endif
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
