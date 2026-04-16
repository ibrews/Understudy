//
//  PerformerView.swift
//  Understudy (iOS)
//
//  The phone side. Teleprompter + GPS-for-theater + haptic cueing.
//  Two modes:
//    - LIVE: follow the director, fire cues when you walk onto marks.
//    - PLAYBACK: you alone — the phone guides you through a recorded blocking
//      like turn-by-turn directions.
//

#if os(iOS)
import SwiftUI
import CoreHaptics

struct PerformerView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @State private var hapticEngine: CHHapticEngine?
    @State private var lastMarkID: ID?
    @State private var showingMarksList = false

    var body: some View {
        ZStack {
            // Background gradient that hints at theater — deep curtain red → black.
            LinearGradient(
                colors: [Color.black, Color(red: 0.15, green: 0.02, blue: 0.04)],
                startPoint: .bottom, endPoint: .top
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)
                currentCueCard
                Spacer(minLength: 12)
                guidanceRing
                Spacer(minLength: 12)
                bottomBar
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear { prepareHaptics() }
        .onChange(of: store.localPerformer?.currentMarkID ?? ID("")) { _, newID in
            if newID != lastMarkID {
                lastMarkID = newID
                pulse()
            }
        }
        .sheet(isPresented: $showingMarksList) {
            MarksOverview().environment(store)
        }
    }

    // MARK: - UI pieces

    private var topBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading) {
                Text(store.blocking.title)
                    .font(.headline)
                Text("Room: \(session.roomCode)  •  \(session.peerCount) peers  •  \(AppVersion.formatted)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button { showingMarksList = true } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
                    .foregroundStyle(.white)
            }
        }
    }

    private var currentMark: Mark? {
        guard let id = store.localPerformer?.currentMarkID else { return nil }
        return store.blocking.marks.first(where: { $0.id == id })
    }

    private var nextMark: Mark? {
        store.nextMark(after: store.localPerformer?.currentMarkID)
    }

    private var currentCueCard: some View {
        Group {
            if let mark = currentMark {
                VStack(spacing: 12) {
                    Text("On \(mark.name)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    ForEach(mark.cues, id: \.id) { cue in
                        CueRow(cue: cue)
                    }
                    if mark.cues.isEmpty {
                        Text("No cues — hold.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.red.opacity(0.35), lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    Text("Find your mark")
                        .font(.title2).bold()
                        .foregroundStyle(.white)
                    Text(nextMark.map { "Next: \($0.name)" } ?? "No blocking loaded")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    /// Big concentric ring that shrinks as you get closer to the next mark.
    private var guidanceRing: some View {
        let distance = distanceToNextMark()
        let proximity = proximityNormalized(distance)
        return ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 2)
                .frame(width: 240, height: 240)
            Circle()
                .stroke(.red.opacity(0.6), lineWidth: 3)
                .frame(width: 240 * CGFloat(1 - proximity) + 40,
                       height: 240 * CGFloat(1 - proximity) + 40)
                .animation(.easeOut(duration: 0.3), value: proximity)
            VStack {
                if let d = distance {
                    Text(String(format: "%.1f m", d))
                        .font(.system(size: 46, weight: .light, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                    Text("to \(nextMark?.name ?? "—")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("—")
                        .font(.system(size: 46, weight: .light, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            let quality = store.localPerformer?.trackingQuality ?? 0
            Label(trackingLabel(quality),
                  systemImage: quality > 0.6 ? "location.fill" : "location.slash")
                .foregroundStyle(quality > 0.6 ? .green : .orange)
                .font(.caption)
            Spacer()
            Button {
                if store.isRecording {
                    _ = store.stopRecording(
                        saveAsReference: true,
                        performerName: store.localPerformer?.displayName ?? "me"
                    )
                } else {
                    store.startRecording()
                }
            } label: {
                Image(systemName: store.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.title)
                    .foregroundStyle(store.isRecording ? .red : .white)
            }
        }
    }

    // MARK: - Logic

    private func distanceToNextMark() -> Float? {
        guard let me = store.localPerformer, let target = nextMark ?? currentMark else { return nil }
        return me.pose.distance(to: target.pose)
    }

    private func proximityNormalized(_ d: Float?) -> Double {
        guard let d else { return 0 }
        // 3m away → 0, inside mark radius → 1.
        return Double(max(0, min(1, 1 - (d / 3.0))))
    }

    private func trackingLabel(_ q: Float) -> String {
        if q > 0.8 { return "Tracking good" }
        if q > 0.4 { return "Tracking limited" }
        return "No tracking — move around"
    }

    // MARK: - Haptics

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            hapticEngine = nil
        }
    }

    private func pulse() {
        guard let hapticEngine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.6)
            ],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try hapticEngine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            // Haptics are nice-to-have; silently ignore.
        }
    }
}

private struct CueRow: View {
    let cue: Cue
    var body: some View {
        switch cue {
        case .line(_, let text, let character):
            VStack(alignment: .leading, spacing: 4) {
                if let character {
                    Text(character.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.red.opacity(0.8))
                }
                Text(text)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .sfx(_, let name):
            Label(name, systemImage: "music.note")
                .foregroundStyle(.yellow)
        case .light(_, let color, _):
            Label("Light: \(color.rawValue)", systemImage: "lightbulb")
                .foregroundStyle(.orange)
        case .note(_, let text):
            Text("(\(text))")
                .italic()
                .foregroundStyle(.white.opacity(0.5))
        case .wait(_, let s):
            Label("hold \(String(format: "%.1f", s))s", systemImage: "pause.circle")
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct MarksOverview: View {
    @Environment(BlockingStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(store.blocking.marks.sorted(by: { $0.sequenceIndex < $1.sequenceIndex })) { mark in
                VStack(alignment: .leading) {
                    Text("\(mark.sequenceIndex + 1). \(mark.name)").font(.headline)
                    ForEach(mark.cues, id: \.id) { cue in
                        Text(cue.humanLabel).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Blocking")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
