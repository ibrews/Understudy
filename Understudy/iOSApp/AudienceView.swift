//
//  AudienceView.swift
//  Understudy (iOS)
//
//  Audience mode. The phone becomes a self-paced audio guide through a
//  finished blocking — the audience *is* the performer, walking the show
//  after the show. Site-specific theater as a finished product.
//
//  Key differences from Perform mode:
//    - The reference walk is streamed at your own walking pace. The phone
//      matches your pose against the recorded path and plays cues at the
//      corresponding sample time, not at wall-clock time. Walk slow, the
//      show holds. Walk fast, it catches up.
//    - No "authoring" buttons. A large "Begin" / "Resume" control,
//      progress bar, and a prominent cue display fill the screen.
//    - Over the wire, this device is `observer` — its pose is shared
//      (so directors can see audience positions live) but it doesn't
//      own any marks.
//

#if os(iOS)
import SwiftUI
import simd

struct AudienceView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(CueFXEngine.self) private var fx
    @AppStorage("showARStage") private var showARStage: Bool = true

    @State private var started: Bool = false
    @State private var lastFiredMarkID: ID?
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            if showARStage {
                ARStageContainer { s in
                    PerformerARHost.shared.adopt(session: s)
                }
                .environment(store)
                .environment(session)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.02, blue: 0.06)],
                startPoint: .bottom, endPoint: .top
            )
            .ignoresSafeArea()
            .opacity(showARStage ? 0.45 : 1)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                if !started {
                    beginCard
                } else {
                    currentCueDisplay
                }
                Spacer()
                progressBar
                bottomBar
            }
            .padding()

            FlashOverlay(flash: fx.currentFlash)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.localPerformer?.currentMarkID ?? ID("")) { _, newID in
            // Audience cues fire on mark entry like a performer — the walk
            // recording informs positioning but cues fire from live marks.
            if started, newID != lastFiredMarkID {
                lastFiredMarkID = newID
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet().environment(store).environment(session)
        }
    }

    // MARK: - UI

    private var topBar: some View {
        HStack {
            Image(systemName: "ear.and.waveform")
                .font(.title3)
                .padding(10)
                .background(.white.opacity(0.08), in: Circle())
                .foregroundStyle(.white)
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(store.blocking.title)
                        .font(.headline)
                    Text("AUDIENCE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }
                Text(AppVersion.formatted)
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
                    .foregroundStyle(.white)
            }
        }
    }

    private var beginCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
            Text(store.blocking.title)
                .font(.title.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Find \(store.blocking.marks.first?.name ?? "the first mark").\nWhen you're ready, begin.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button {
                started = true
            } label: {
                Label("Begin", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.85), in: Capsule())
                    .foregroundStyle(.white)
            }
            .disabled(store.blocking.marks.isEmpty)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var currentCueDisplay: some View {
        Group {
            if let mark = currentMark {
                VStack(spacing: 16) {
                    Text("\(mark.sequenceIndex + 1). \(mark.name)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.6))
                    ForEach(mark.cues, id: \.id) { cue in
                        AudienceCueRow(cue: cue)
                    }
                    if mark.cues.isEmpty {
                        Text("Take in the space.")
                            .font(.title3).italic()
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.red.opacity(0.25), lineWidth: 1)
                )
            } else if let next = nextMark {
                VStack(spacing: 10) {
                    Text("Walk to \(next.name)")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(String(format: "%.1f m away",
                                store.localPerformer?.pose.distance(to: next.pose) ?? 0))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
            } else {
                VStack(spacing: 8) {
                    Text("End of journey.")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Thank you for walking \(store.blocking.title).")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(22)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var progressBar: some View {
        let ordered = store.blocking.marks
            .filter { $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        let currentIdx = ordered.firstIndex(where: { $0.id == store.localPerformer?.currentMarkID }) ?? -1
        let fraction: Double = ordered.isEmpty
            ? 0
            : Double(currentIdx + 1) / Double(ordered.count)
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: max(6, geo.size.width * fraction))
                        .animation(.easeInOut, value: fraction)
                }
            }
            .frame(height: 6)
            Text("\(max(0, currentIdx + 1)) of \(ordered.count) marks")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var bottomBar: some View {
        HStack {
            let quality = store.localPerformer?.trackingQuality ?? 0
            Label(quality > 0.6 ? "Tracking good" : "Walk slowly",
                  systemImage: quality > 0.6 ? "location.fill" : "location.slash")
                .foregroundStyle(quality > 0.6 ? .green : .orange)
                .font(.caption)
            Spacer()
            if started {
                Button {
                    started = false
                    lastFiredMarkID = nil
                } label: {
                    Image(systemName: "stop.circle")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Derived state

    private var currentMark: Mark? {
        guard let id = store.localPerformer?.currentMarkID else { return nil }
        return store.blocking.marks.first { $0.id == id }
    }

    private var nextMark: Mark? {
        store.nextMark(after: store.localPerformer?.currentMarkID)
    }
}

private struct AudienceCueRow: View {
    let cue: Cue
    var body: some View {
        switch cue {
        case .line(_, let text, let character):
            VStack(alignment: .leading, spacing: 6) {
                if let character {
                    Text(character.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.red.opacity(0.85))
                }
                Text(text)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .sfx(_, let name):
            Label(name, systemImage: "music.note")
                .foregroundStyle(.yellow)
                .font(.title3)
        case .light(_, let color, _):
            Label("A \(color.rawValue) light washes the space.", systemImage: "lightbulb.fill")
                .foregroundStyle(.orange)
                .font(.body.italic())
        case .note:
            // Director notes are hidden from audiences.
            EmptyView()
        case .wait(_, let s):
            Text("— pause, \(String(format: "%.0f", s))s —")
                .font(.caption.italic())
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
#endif
