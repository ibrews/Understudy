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
import ARKit
import RealityKit

struct PerformerView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(CueFXEngine.self) private var fx
    @State private var hapticEngine: CHHapticEngine?
    @State private var lastMarkID: ID?
    @State private var showingMarksList = false
    @State private var showingSettings = false
    /// True while this device is advancing playbackT locally.
    @State private var isPlayingGhost: Bool = false
    @State private var playbackStartedAt: Date?
    @State private var playbackTimer: Timer?
    @AppStorage("showARStage") private var showARStage: Bool = true

    /// Opacity for the curtain gradient — dialed back when AR background is visible
    /// so the camera reads through but the theatrical vibe stays.
    private var gradientOpacity: Double { showARStage ? 0.4 : 1.0 }

    var body: some View {
        ZStack {
            // Live AR camera feed (behind everything). Toggle via Display setting.
            if showARStage {
                ARStageContainer { session in
                    // Hand the session to the host so ARPoseProvider can share it.
                    PerformerARHost.shared.adopt(session: session)
                }
                .environment(store)
                .environment(session)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Curtain gradient — either full curtain or a dimmed wash over the camera.
            LinearGradient(
                colors: [Color.black, Color(red: 0.15, green: 0.02, blue: 0.04)],
                startPoint: .bottom, endPoint: .top
            )
            .ignoresSafeArea()
            .opacity(gradientOpacity)
            .allowsHitTesting(false)

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

            // Countdown pill for .wait cues.
            if let hold = fx.currentHold, hold > 0 {
                VStack {
                    HStack {
                        Spacer()
                        Text(String(format: "Hold %.1fs", hold))
                            .font(.caption.monospacedDigit().bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(.top, 60)
                            .padding(.trailing, 18)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Lighting flash overlay — full-screen, fades over 0.75s.
            FlashOverlay(flash: fx.currentFlash)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .onAppear { prepareHaptics() }
        .onDisappear { stopGhostPlayback() }
        .onChange(of: store.localPerformer?.currentMarkID ?? ID("")) { _, newID in
            if newID != lastMarkID {
                lastMarkID = newID
                pulse()
            }
        }
        .sheet(isPresented: $showingMarksList) {
            MarksOverview().environment(store)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
                .environment(store)
                .environment(session)
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
            CalibrationButton()
                .environment(store)
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
                    .foregroundStyle(.white)
            }
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
        HStack(spacing: 14) {
            let quality = store.localPerformer?.trackingQuality ?? 0
            Label(trackingLabel(quality),
                  systemImage: quality > 0.6 ? "location.fill" : "location.slash")
                .foregroundStyle(quality > 0.6 ? .green : .orange)
                .font(.caption)
            Spacer()
            // Ghost playback toggle — only meaningful if we have a reference walk.
            Button {
                toggleGhostPlayback()
            } label: {
                Image(systemName: isPlayingGhost ? "figure.walk.motion" : "figure.walk")
                    .font(.title2)
                    .foregroundStyle(ghostReadyColor)
                    .padding(8)
                    .background(.white.opacity(0.06), in: Circle())
            }
            .disabled(store.blocking.reference == nil)
            .accessibilityLabel(isPlayingGhost ? "Stop ghost playback" : "Play ghost walkthrough")

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

    private var ghostReadyColor: Color {
        if store.blocking.reference == nil { return .white.opacity(0.25) }
        return isPlayingGhost ? Color(red: 1.0, green: 0.4, blue: 0.9) : .white
    }

    // MARK: - Ghost playback

    private func toggleGhostPlayback() {
        guard let walk = store.blocking.reference, walk.duration > 0 else { return }
        if isPlayingGhost {
            stopGhostPlayback()
        } else {
            startGhostPlayback(duration: walk.duration)
        }
    }

    private func startGhostPlayback(duration: TimeInterval) {
        isPlayingGhost = true
        playbackStartedAt = Date()
        store.playbackT = 0
        session.broadcastPlayback(t: 0)
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                guard let started = playbackStartedAt else { return }
                let elapsed = Date().timeIntervalSince(started)
                let t = min(1, elapsed / duration)
                store.playbackT = t
                session.broadcastPlayback(t: t)
                if t >= 1 { stopGhostPlayback() }
            }
        }
    }

    private func stopGhostPlayback() {
        isPlayingGhost = false
        playbackStartedAt = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        store.playbackT = nil
        session.broadcastPlayback(t: nil)
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

struct SettingsSheet: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(CueFXEngine.self) private var fx
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("relayURL") private var relayURL: String = "ws://127.0.0.1:8765"
    @AppStorage("showARStage") private var showARStage: Bool = true
    @AppStorage("appMode") private var appModeRaw: String = AppMode.perform.rawValue
    @AppStorage("oscEnabled") private var oscEnabled: Bool = false
    @AppStorage("oscHost") private var oscHost: String = ""
    @AppStorage("oscPort") private var oscPortStr: String = "53000"

    private var appMode: AppMode {
        get { AppMode(rawValue: appModeRaw) ?? .perform }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("I want to", selection: $appModeRaw) {
                        ForEach(AppMode.allCases, id: \.self) { m in
                            Label(m.displayName, systemImage: m.systemImage).tag(m.rawValue)
                        }
                    }
                    if let m = AppMode(rawValue: appModeRaw) {
                        Text(m.tagline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Identity") {
                    TextField("Display name", text: $displayName)
                        .onSubmit { applyName() }
                }
                Section("Display") {
                    Toggle("AR Stage background", isOn: $showARStage)
                    Text(showARStage
                         ? "Live camera feed with glowing marks."
                         : "Solid curtain gradient (no camera).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Room") {
                    TextField("Room code", text: Binding(
                        get: { session.roomCode },
                        set: { session.roomCode = $0 }
                    ))
                }
                Section("Transport") {
                    Picker("Mode", selection: Binding(
                        get: { session.transportKind },
                        set: { session.switchTransport(to: $0) }
                    )) {
                        Text("Multipeer (Apple only)").tag(TransportKind.multipeer)
                        Text("WebSocket relay").tag(TransportKind.websocket)
                    }
                    if session.transportKind == .websocket {
                        TextField("Relay URL", text: $relayURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                session.relayURL = relayURL
                                session.switchTransport(to: .multipeer)
                                session.switchTransport(to: .websocket)
                            }
                        Text("Runs at /relay/server.py. Enter the host's LAN IP, e.g. ws://192.168.1.42:8765")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle("Send OSC to QLab / show control", isOn: $oscEnabled)
                        .onChange(of: oscEnabled) { _, _ in applyOSC() }
                    if oscEnabled {
                        TextField("Host (e.g. 192.168.1.50)", text: $oscHost)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .onSubmit { applyOSC() }
                        TextField("Port", text: $oscPortStr)
                            .keyboardType(.numberPad)
                            .onSubmit { applyOSC() }
                        Text("Sends /understudy/cue/... messages when cues fire. Works with QLab, TouchDesigner, Max/MSP, etc.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Send test message") {
                            fx.osc.sendMessage(address: "/understudy/test",
                                               args: [.string("ping from \(UIDevice.current.name)")])
                        }
                    }
                } header: { Text("OSC Bridge") }

                Section("About") {
                    LabeledContent("Version", value: AppVersion.formatted)
                    Text(store.blocking.title).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyName()
                        applyOSC()
                        dismiss()
                    }
                }
            }
        }
    }

    private func applyOSC() {
        let port = UInt16(oscPortStr) ?? 53000
        fx.osc.configure(
            host: oscHost.trimmingCharacters(in: .whitespaces).isEmpty ? nil : oscHost,
            port: port,
            enabled: oscEnabled
        )
    }

    private func applyName() {
        guard !displayName.isEmpty, var me = store.localPerformer else { return }
        me.displayName = displayName
        store.upsertPerformer(me)
    }
}

/// Full-screen color wash that fades when a light cue fires.
/// Reads the CueFXEngine's currentFlash, and animates its own local opacity
/// so the wash hits instantly then fades out.
struct FlashOverlay: View {
    let flash: CueFXEngine.FlashState?
    @State private var renderedID: UUID?
    @State private var opacity: Double = 0

    var body: some View {
        Rectangle()
            .fill(flash?.color ?? .clear)
            .opacity(opacity)
            .animation(.easeOut(duration: 0.75), value: opacity)
            .onChange(of: flash?.cueID) { _, newID in
                guard let newID, let f = flash, newID != renderedID else {
                    if flash == nil { opacity = 0 }
                    return
                }
                renderedID = newID
                // Snap to the flash amplitude, then the animation above fades it.
                opacity = f.alpha
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(f.holdDuration * 1_000_000_000))
                    opacity = 0
                }
            }
    }
}

/// Tiny singleton that bridges the ARStageContainer's ARSession into a shared
/// ARPoseProvider. The container creates its session, then calls
/// `PerformerARHost.shared.adopt(session:)`. The host builds (or rebuilds) the
/// provider so a single session feeds both pose tracking AND the AR background.
@MainActor
final class PerformerARHost {
    static let shared = PerformerARHost()
    private(set) var provider: ARPoseProvider?
    private weak var store: BlockingStore?
    private weak var session: SessionController?
    /// Held weakly so Author mode can raycast tap locations to world coords.
    /// Set by `ARStageContainer.makeUIView`; nil when AR background is disabled.
    weak var arView: ARView?

    /// Per-session calibration. Nil = uncalibrated, device uses its raw AR
    /// world frame as the blocking frame. Everyone in a rehearsal should
    /// stand at the same spot + face the same direction + tap "Set Origin
    /// Here" at the same time.
    public var calibration: DeviceCalibration?

    /// Snapshot the current raw ARKit pose and use it as the shared origin.
    /// Returns true if a pose was available (ARKit has started and produced
    /// at least one frame), false otherwise.
    @discardableResult
    public func calibrateAtCurrentPose() -> Bool {
        guard let provider else { return false }
        calibration = DeviceCalibration(anchor: provider.latestRawPose)
        // Force an immediate pose update so the store reflects the new frame
        // without waiting for the next ARKit frame.
        let raw = provider.latestRawPose
        if let calibration, let store = self.store {
            store.updateLocalPose(calibration.toBlocking(raw), quality: store.localPerformer?.trackingQuality ?? 1)
        }
        return true
    }

    public func clearCalibration() {
        calibration = nil
    }

    func configure(store: BlockingStore, session: SessionController) {
        self.store = store
        self.session = session
    }

    func adopt(session arSession: ARSession) {
        guard let store, let sc = self.session else { return }
        provider = ARPoseProvider(session: arSession, store: store, sessionController: sc)
    }

    /// Fallback when AR background is disabled: run a provider that owns its own session.
    func startStandalone() {
        guard provider == nil || provider?.session.delegate == nil else { return }
        guard let store, let sc = session else { return }
        let p = ARPoseProvider(store: store, sessionController: sc)
        p.start()
        provider = p
    }

    func stop() {
        provider?.stop()
        provider = nil
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
