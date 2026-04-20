//
//  DirectorControlPanel.swift
//  Understudy (visionOS)
//
//  The floating window where the director runs the show: room code, mark list,
//  cue editor, playback transport.
//

#if os(visionOS)
import SwiftUI
import UniformTypeIdentifiers

struct DirectorControlPanel: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(CueFXEngine.self) private var fx
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @State private var immersiveActive = false
    @State private var editingMark: Mark?
    @State private var editingProp: PropObject?
    @State private var showingCSVImport = false
    @State private var newCueText: String = ""
    @State private var newCueCharacter: String = ""
    @State private var directorIsPlaying: Bool = false
    @State private var directorPlaybackStartedAt: Date?
    @State private var directorPlaybackTimer: Timer?
    @State private var showingOSCSettings = false
    @AppStorage("oscEnabled") private var oscEnabled: Bool = false
    @AppStorage("oscHost") private var oscHost: String = ""
    @AppStorage("oscPort") private var oscPortStr: String = "53000"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                roomRow
                stageToolbar
                rehearsalTimerStrip
                marksList
                propsList
                transportStrip
                scanAlignStrip
                Spacer()
                footer
            }
            .padding(24)
            .navigationTitle("Understudy — Director")
            .sheet(item: $editingMark) { mark in
                MarkEditor(mark: mark)
                    .environment(store)
                    .environment(session)
                    .environment(fx)
                    .frame(minWidth: 420, minHeight: 520)
            }
            .sheet(item: $editingProp) { prop in
                PropEditor(prop: prop)
                    .environment(store)
                    .frame(minWidth: 380, minHeight: 360)
            }
            .fileImporter(
                isPresented: $showingCSVImport,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                guard let url = try? result.get().first else { return }
                importCSVCueSheet(from: url)
            }
            .sheet(isPresented: $showingOSCSettings) {
                OSCSettingsSheet(enabled: $oscEnabled, host: $oscHost, port: $oscPortStr)
                    .environment(fx)
                    .frame(minWidth: 420, minHeight: 360)
            }
            .onAppear { applyOSC() }
            .onDisappear { stopDirectorPlayback() }
        }
    }

    private func nudgeScanRotation(by radians: Float) {
        guard var scan = store.blocking.roomScan else { return }
        scan.overlayOffset.yaw += radians
        store.blocking.roomScan = scan
        store.blocking.modifiedAt = Date()
        BlockingAutosave.save(store.blocking)
        session.broadcastScanOverlay(scan.overlayOffset)
    }

    private func resetScanAlignment() {
        guard var scan = store.blocking.roomScan else { return }
        scan.overlayOffset = Pose()
        store.blocking.roomScan = scan
        store.blocking.modifiedAt = Date()
        BlockingAutosave.save(store.blocking)
        session.broadcastScanOverlay(Pose())
    }

    private func applyOSC() {
        let port = UInt16(oscPortStr) ?? 53000
        fx.osc.configure(
            host: oscHost.trimmingCharacters(in: .whitespaces).isEmpty ? nil : oscHost,
            port: port,
            enabled: oscEnabled
        )
    }

    // MARK: - Stage toolbar (grid, snap, tabletop, prop placement)

    @ViewBuilder private var stageToolbar: some View {
        HStack(spacing: 10) {
            // Grid overlay
            Toggle(isOn: Binding(get: { store.showStageGrid }, set: { store.showStageGrid = $0 })) {
                Label("Grid", systemImage: "grid")
            }
            .toggleStyle(.button)
            .tint(store.showStageGrid ? .cyan : nil)

            // Snap to grid (only meaningful when grid is shown)
            Toggle(isOn: Binding(get: { store.snapToGrid }, set: { store.snapToGrid = $0 })) {
                Label("Snap", systemImage: "scope")
            }
            .toggleStyle(.button)
            .tint(store.snapToGrid ? .cyan : nil)
            .disabled(!store.showStageGrid)

            Divider().frame(height: 20)

            // Tabletop (director review) mode
            Toggle(isOn: Binding(get: { store.isTabletopMode }, set: { store.isTabletopMode = $0 })) {
                Label("Tabletop", systemImage: "rectangle.inset.filled")
            }
            .toggleStyle(.button)
            .tint(store.isTabletopMode ? .orange : nil)

            Divider().frame(height: 20)

            // Prop placement mode
            Toggle(isOn: Binding(get: { store.isPropPlacementMode }, set: { store.isPropPlacementMode = $0 })) {
                Label("Props", systemImage: store.isPropPlacementMode ? "cube.fill" : "cube")
            }
            .toggleStyle(.button)
            .tint(store.isPropPlacementMode ? .yellow : nil)

            if store.isPropPlacementMode {
                Picker("", selection: Binding(
                    get: { store.selectedPropShape },
                    set: { store.selectedPropShape = $0 }
                )) {
                    Label("Cube", systemImage: "cube").tag(PropShape.cube)
                    Label("Sphere", systemImage: "circle").tag(PropShape.sphere)
                    Label("Cylinder", systemImage: "cylinder").tag(PropShape.cylinder)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Rehearsal timer

    @ViewBuilder private var rehearsalTimerStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
            Text(timerLabel)
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(store.rehearsalTimerRunning ? .primary : .secondary)
                .frame(minWidth: 90, alignment: .leading)

            Button {
                if store.rehearsalTimerRunning {
                    store.stopRehearsalTimer()
                } else {
                    store.startRehearsalTimer()
                }
            } label: {
                Image(systemName: store.rehearsalTimerRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.bordered)
            .tint(store.rehearsalTimerRunning ? .orange : .green)

            Button {
                store.resetRehearsalTimer()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .disabled(store.rehearsalElapsed == 0 && !store.rehearsalTimerRunning)

            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var timerLabel: String {
        let t = Int(store.rehearsalElapsed)
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    @ViewBuilder private var scanAlignStrip: some View {
        if let scan = store.blocking.roomScan {
            HStack(spacing: 12) {
                Image(systemName: "cube.transparent.fill")
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scan.name)
                        .font(.subheadline.bold())
                    Text("\(scan.triangleCount) tris · offset \(String(format: "%+.2fm, %+.0f°", scan.overlayOffset.x, Double(scan.overlayOffset.yaw) * 180 / .pi))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Lock toggle — drags are gated by this so the scan
                // doesn't drift mid-rehearsal.
                Toggle(isOn: Binding(
                    get: { !store.scanAlignmentLocked },
                    set: { store.scanAlignmentLocked = !$0 }
                )) {
                    Label("Align", systemImage: store.scanAlignmentLocked ? "lock" : "hand.raised")
                }
                .toggleStyle(.button)

                // Rotate ±15° for fine alignment (drag handles translation).
                // The immersive view observes the store and re-applies the
                // transform on every frame, so mutating store here is enough.
                Button { nudgeScanRotation(by: -Float.pi / 12) }
                label: { Image(systemName: "rotate.left") }
                    .disabled(store.scanAlignmentLocked)

                Button { nudgeScanRotation(by: Float.pi / 12) }
                label: { Image(systemName: "rotate.right") }
                    .disabled(store.scanAlignmentLocked)

                // Reset.
                Button(role: .destructive) { resetScanAlignment() }
                label: { Image(systemName: "arrow.counterclockwise") }
                    .disabled(store.scanAlignmentLocked)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder private var transportStrip: some View {
        if let reference = store.blocking.reference {
            HStack(spacing: 14) {
                Button {
                    toggleDirectorPlayback(duration: reference.duration)
                } label: {
                    Image(systemName: directorIsPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)

                Slider(
                    value: Binding(
                        get: { store.playbackT ?? 0 },
                        set: { newValue in
                            // Manual scrub pauses automatic playback.
                            if directorIsPlaying { stopDirectorPlayback() }
                            store.playbackT = newValue
                            session.broadcastPlayback(t: newValue)
                        }
                    ),
                    in: 0...1
                )

                Text(playbackTimeLabel(duration: reference.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
    }

    private func playbackTimeLabel(duration: TimeInterval) -> String {
        let t = store.playbackT ?? 0
        let cur = t * duration
        return String(format: "%04.1f / %04.1f s", cur, duration)
    }

    private func toggleDirectorPlayback(duration: TimeInterval) {
        if directorIsPlaying {
            stopDirectorPlayback()
        } else {
            startDirectorPlayback(duration: duration)
        }
    }

    private func startDirectorPlayback(duration: TimeInterval) {
        directorIsPlaying = true
        let baseT = store.playbackT ?? 0
        directorPlaybackStartedAt = Date().addingTimeInterval(-baseT * duration)
        session.broadcastPlayback(t: baseT)
        directorPlaybackTimer?.invalidate()
        directorPlaybackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                guard let started = directorPlaybackStartedAt else { return }
                let t = min(1, Date().timeIntervalSince(started) / duration)
                store.playbackT = t
                session.broadcastPlayback(t: t)
                if t >= 1 { stopDirectorPlayback() }
            }
        }
    }

    private func stopDirectorPlayback() {
        directorIsPlaying = false
        directorPlaybackStartedAt = nil
        directorPlaybackTimer?.invalidate()
        directorPlaybackTimer = nil
    }

    @ViewBuilder private var header: some View {
        HStack {
            Image(systemName: "theatermasks.fill")
                .font(.largeTitle)
            VStack(alignment: .leading) {
                Text(store.blocking.title)
                    .font(.title)
                    .fontWeight(.bold)
                Text("\(store.blocking.marks.count) marks  •  \(session.peerCount) connected  •  \(AppVersion.formatted)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var roomRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Room", systemImage: "number")
                TextField("Room code", text: Binding(
                    get: { session.roomCode },
                    set: { session.roomCode = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)

                Toggle(isOn: $immersiveActive) {
                    Label(
                        immersiveActive ? "Mixed Reality On" : "Enter Mixed Reality",
                        systemImage: immersiveActive ? "arkit" : "arkit"
                    )
                }
                .toggleStyle(.button)
                .tint(immersiveActive ? .green : .blue)
                .controlSize(.large)
                .onChange(of: immersiveActive) { _, on in
                    Task {
                        if on { _ = await openImmersiveSpace(id: "Stage") }
                        else { await dismissImmersiveSpace() }
                    }
                }

                Button {
                    openWindow(id: "Teleprompter")
                } label: {
                    Label("Teleprompter", systemImage: "text.quote")
                }
                Button {
                    openWindow(id: "QRTarget")
                } label: {
                    Label("QR Target", systemImage: "qrcode")
                }
            }
            HStack {
                Label("Transport", systemImage: "antenna.radiowaves.left.and.right")
                Picker("", selection: Binding(
                    get: { session.transportKind },
                    set: { session.switchTransport(to: $0) }
                )) {
                    Text("Multipeer (Apple only)").tag(TransportKind.multipeer)
                    Text("WebSocket relay (incl. Android)").tag(TransportKind.websocket)
                }
                .pickerStyle(.menu)
                if session.transportKind == .websocket {
                    TextField("ws://host:8765", text: Binding(
                        get: { session.relayURL },
                        set: { session.relayURL = $0; session.switchTransport(to: .multipeer); session.switchTransport(to: .websocket) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                }
            }
            HStack {
                Label("OSC → QLab", systemImage: "waveform.path")
                Button {
                    showingOSCSettings = true
                } label: {
                    Text(oscEnabled && !oscHost.isEmpty ? "\(oscHost):\(oscPortStr)" : "Configure…")
                }
                if oscEnabled {
                    Circle().fill(.green).frame(width: 8, height: 8)
                        .accessibilityLabel("OSC enabled")
                }
                Spacer()
                // Manual cue-stack GO — same semantics as an inbound
                // /understudy/go OSC message. Useful when a stage manager
                // is running the show straight from the director panel.
                Button(role: .destructive) {
                    fx.goBack()
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                Button {
                    fx.goForward()
                } label: {
                    Label("GO", systemImage: "play.fill")
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }

    @ViewBuilder private var propsList: some View {
        if !store.blocking.props.isEmpty {
            VStack(alignment: .leading) {
                HStack {
                    Text("Props")
                        .font(.headline)
                    Spacer()
                    Button(role: .destructive) {
                        store.blocking.props.removeAll()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.caption)
                    }
                }
                List {
                    ForEach(store.blocking.props) { prop in
                        Button { editingProp = prop } label: {
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(red: Double(prop.r), green: Double(prop.g), blue: Double(prop.b)))
                                    .frame(width: 18, height: 18)
                                Image(systemName: prop.shape == .cube ? "cube" : prop.shape == .sphere ? "circle" : "cylinder")
                                    .foregroundStyle(.secondary)
                                Text(prop.name).font(.headline)
                                Spacer()
                                Text(String(format: "%.1f×%.1fm", prop.width, prop.height))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { idx in
                        var sorted = store.blocking.props
                        for i in idx.reversed() { sorted.remove(at: i) }
                        store.blocking.props = sorted
                        BlockingAutosave.save(store.blocking)
                    }
                }
                .frame(minHeight: 120)
            }
        }
    }

    @ViewBuilder private var marksList: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Marks")
                    .font(.headline)
                Spacer()
                Button {
                    showingCSVImport = true
                } label: {
                    Label("CSV", systemImage: "doc.badge.arrow.up")
                        .font(.caption)
                }
                Button {
                    // Quick-add a mark at the origin — mostly for testing without
                    // entering the immersive space.
                    let i = store.blocking.marks.count + 1
                    let m = Mark(name: "Mark \(i)", pose: Pose(x: 0, y: 0, z: -Float(i) * 0.8),
                                 sequenceIndex: i - 1)
                    store.addMark(m)
                    session.broadcastMarkAdded(m)
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            if store.blocking.marks.isEmpty {
                ContentUnavailableView(
                    "No marks yet",
                    systemImage: "mappin.slash",
                    description: Text("Open the stage and tap to place marks, or use Add.")
                )
            } else {
                List {
                    ForEach(store.blocking.marks.sorted(by: { $0.sequenceIndex < $1.sequenceIndex })) { mark in
                        Button {
                            editingMark = mark
                        } label: {
                            HStack {
                                Text("\(mark.sequenceIndex + 1)")
                                    .frame(width: 28, alignment: .leading)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading) {
                                    Text(mark.name).font(.headline)
                                    if !mark.cues.isEmpty {
                                        Text(mark.cues.map(\.humanLabel).joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(String(format: "%.1f, %.1f m",
                                            mark.pose.x, mark.pose.z))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { idx in
                        let sorted = store.blocking.marks.sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
                        for i in idx {
                            let id = sorted[i].id
                            store.removeMark(id: id)
                            session.broadcastMarkRemoved(id)
                        }
                    }
                }
                .frame(minHeight: 280)
            }
        }
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: 14) {
            if let t = store.playbackT {
                Label("Playback", systemImage: "play.circle")
                ProgressView(value: t)
                    .frame(maxWidth: 240)
            }

            // Last light cue chip.
            if let flash = fx.currentFlash {
                HStack(spacing: 6) {
                    Circle()
                        .fill(flash.color)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                    Text("Last light")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.2), in: Capsule())
                .transition(.opacity)
            } else if let lastLight = lastLoggedLightColor() {
                HStack(spacing: 6) {
                    Circle()
                        .fill(CueFXEngine.color(for: lastLight))
                        .opacity(0.55)
                        .frame(width: 10, height: 10)
                    Text("Last light: \(lastLight.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.12), in: Capsule())
            }

            Spacer()
            Button(role: .destructive) {
                for m in store.blocking.marks {
                    session.broadcastMarkRemoved(m.id)
                }
                store.blocking.marks.removeAll()
                store.blocking.modifiedAt = Date()
                BlockingAutosave.save(store.blocking)
            } label: {
                Label("Clear Stage", systemImage: "trash")
            }
        }
    }

    /// The most recent .light cue color from the FX log, if any.
    private func lastLoggedLightColor() -> LightColor? {
        for entry in fx.recentLog.reversed() {
            if case .light(_, let color, _) = entry.cue {
                return color
            }
        }
        return nil
    }

    /// Import a CSV cue sheet. Expected columns (first row = header, ignored):
    ///   name, note   — creates marks with a .note cue for each row.
    /// Extra columns are ignored. Marks are placed in a column at x=0, spaced
    /// 0.8 m apart so they're immediately visible in the stage space.
    private func importCSVCueSheet(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let rows = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard rows.count > 1 else { return }
        // Skip header row (index 0)
        var idx = store.blocking.marks.count
        for row in rows.dropFirst() {
            let cols = row.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .init(charactersIn: "\" \t"))
            }
            guard cols.count >= 1, !cols[0].isEmpty else { continue }
            let name = cols[0]
            let note = cols.count >= 2 ? cols[1] : ""
            let pose = Pose(x: 0, y: 0, z: -Float(idx) * 0.8)
            var mark = Mark(name: name, pose: pose, sequenceIndex: idx)
            if !note.isEmpty {
                mark.cues = [.note(id: ID(), text: note)]
            }
            store.addMark(mark)
            session.broadcastMarkAdded(mark)
            idx += 1
        }
    }
}

/// Prop editor sheet — edit name, size, shape, and color.
struct PropEditor: View {
    @Environment(BlockingStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var prop: PropObject

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $prop.name)
                    Picker("Shape", selection: $prop.shape) {
                        Label("Cube", systemImage: "cube").tag(PropShape.cube)
                        Label("Sphere", systemImage: "circle").tag(PropShape.sphere)
                        Label("Cylinder", systemImage: "cylinder").tag(PropShape.cylinder)
                    }
                }
                Section("Size (meters)") {
                    LabeledContent("Width") {
                        Stepper(String(format: "%.1f m", prop.width),
                                value: $prop.width, in: 0.1...5.0, step: 0.1)
                    }
                    LabeledContent("Height") {
                        Stepper(String(format: "%.1f m", prop.height),
                                value: $prop.height, in: 0.1...5.0, step: 0.1)
                    }
                    if prop.shape == .cube {
                        LabeledContent("Depth") {
                            Stepper(String(format: "%.1f m", prop.depth),
                                    value: $prop.depth, in: 0.1...5.0, step: 0.1)
                        }
                    }
                }
                Section("Color") {
                    ColorPicker("Prop color", selection: Binding(
                        get: { Color(red: Double(prop.r), green: Double(prop.g), blue: Double(prop.b)) },
                        set: { c in
                            let ui = UIColor(c)
                            var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0
                            ui.getRed(&r, green: &g, blue: &b, alpha: nil)
                            prop.r = Float(r); prop.g = Float(g); prop.b = Float(b)
                        }
                    ))
                }
                Section("Position") {
                    HStack {
                        Text("x"); TextField("x", value: $prop.pose.x, format: .number.precision(.fractionLength(2)))
                        Text("z"); TextField("z", value: $prop.pose.z, format: .number.precision(.fractionLength(2)))
                    }
                    .textFieldStyle(.roundedBorder)
                }
            }
            .navigationTitle(prop.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.updateProp(prop); dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) {
                        store.removeProp(id: prop.id); dismiss()
                    }
                }
            }
        }
    }
}

/// Quick OSC configuration for the director panel.
struct OSCSettingsSheet: View {
    @Environment(CueFXEngine.self) private var fx
    @Environment(\.dismiss) private var dismiss
    @Binding var enabled: Bool
    @Binding var host: String
    @Binding var port: String

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enabled", isOn: $enabled)
                    TextField("Host (192.168.1.50 or qlab.local)", text: $host)
                        .textContentType(.URL)
                    TextField("Port", text: $port)
                } header: {
                    Text("OSC Destination")
                } footer: {
                    Text("When enabled, Understudy sends OSC messages for each cue fired:\n/understudy/cue/line <character> <text>\n/understudy/cue/sfx <name>\n/understudy/cue/light <color> <intensity>\n/understudy/cue/wait <seconds>\n/understudy/mark/enter <name> <index>")
                        .font(.caption.monospaced())
                }

                Section("Test") {
                    Button("Send test message") {
                        applyAndFlush()
                        fx.osc.sendMessage(address: "/understudy/test",
                                           args: [.string("ping from Understudy director")])
                    }
                }
            }
            .navigationTitle("OSC → QLab / Show Control")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyAndFlush()
                        dismiss()
                    }
                }
            }
        }
    }

    private func applyAndFlush() {
        let p = UInt16(port) ?? 53000
        fx.osc.configure(
            host: host.trimmingCharacters(in: .whitespaces).isEmpty ? nil : host,
            port: p,
            enabled: enabled
        )
    }
}

struct MarkEditor: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(CueFXEngine.self) private var fx
    @Environment(\.dismiss) private var dismiss

    @State var mark: Mark
    @State private var newLine: String = ""
    @State private var newCharacter: String = ""
    @State private var newNote: String = ""
    @State private var showingScriptBrowser = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Mark name", text: $mark.name)
                    Stepper("Radius: \(String(format: "%.1f", mark.radius)) m",
                            value: $mark.radius, in: 0.2...3.0, step: 0.1)
                }
                Section("Position") {
                    HStack {
                        Text("x"); TextField("x", value: $mark.pose.x, format: .number.precision(.fractionLength(2)))
                        Text("z"); TextField("z", value: $mark.pose.z, format: .number.precision(.fractionLength(2)))
                    }
                    .textFieldStyle(.roundedBorder)
                }
                Section("Cues") {
                    ForEach(mark.cues, id: \.id) { cue in
                        HStack {
                            Text(cue.humanLabel)
                                .lineLimit(2)
                            Spacer()
                            Button {
                                fx.preview(cue)
                            } label: {
                                Image(systemName: "play.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Preview")
                        }
                    }
                    .onDelete { idx in
                        mark.cues.remove(atOffsets: idx)
                    }
                    Button {
                        showingScriptBrowser = true
                    } label: {
                        Label("Pick from script…", systemImage: "text.book.closed")
                    }
                    VStack(alignment: .leading) {
                        TextField("Character (optional)", text: $newCharacter)
                        TextField("Add a line…", text: $newLine)
                        Button("Add Custom Line") {
                            guard !newLine.isEmpty else { return }
                            mark.cues.append(.line(id: ID(),
                                                   text: newLine,
                                                   character: newCharacter.isEmpty ? nil : newCharacter))
                            newLine = ""
                        }
                        .disabled(newLine.isEmpty)
                    }
                    VStack(alignment: .leading) {
                        TextField("Add a director note…", text: $newNote)
                        Button("Add Note") {
                            guard !newNote.isEmpty else { return }
                            mark.cues.append(.note(id: ID(), text: newNote))
                            newNote = ""
                        }
                        .disabled(newNote.isEmpty)
                    }
                }
            }
            .navigationTitle(mark.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateMark(mark)
                        session.broadcastMarkUpdated(mark)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingScriptBrowser) {
                ScriptBrowser(mark: $mark)
                    .frame(minWidth: 560, minHeight: 640)
            }
        }
    }
}
#endif
