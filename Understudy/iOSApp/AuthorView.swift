//
//  AuthorView.swift
//  Understudy (iOS)
//
//  Author mode. Same AR camera background as PerformerView, but:
//    • A big transparent tap target over the stage: tap the floor to drop a mark.
//    • Tap an existing mark entity to open the inline editor.
//    • Bottom bar has Export / Import / Clear instead of Record / Ghost.
//    • Role over the wire is still "performer" — the author is a live body with
//      a pose, so other devices see them as a ghost avatar.
//

#if os(iOS)
import SwiftUI
import ARKit
import RealityKit
import UniformTypeIdentifiers

struct AuthorView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(CueFXEngine.self) private var fx
    @AppStorage("showARStage") private var showARStage: Bool = true

    @State private var editingMark: Mark?
    @State private var showingSettings = false
    @State private var exportItem: BlockingDocument?
    @State private var showingImporter = false
    @State private var confirmClear = false
    @State private var placementFeedback: Date?
    @State private var dropKind: MarkKind = .actor
    @State private var cameraPreset: CameraSpec = .preset35mm
    @State private var meshCapture: MeshCapture?
    @State private var scanState: MeshCapture.State = .idle
    @State private var scanTriangles: Int = 0
    @State private var scanRefreshTimer: Timer?
    @State private var scanNameDraft: String = "Room scan"
    @State private var showingScanNameSheet: Bool = false
    @State private var showingTeleprompter: Bool = false
    @AppStorage("hasSeenOnboarding_author") private var hasSeenOnboarding: Bool = false
    @State private var showingOnboarding = false

    private var gradientOpacity: Double { showARStage ? 0.30 : 1.0 }

    var body: some View {
        ZStack {
            if showARStage {
                ARStageContainer { arSession in
                    PerformerARHost.shared.adopt(session: arSession)
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
            .opacity(gradientOpacity)
            .allowsHitTesting(false)

            // Viewfinder framing overlay — shows what the selected lens would
            // frame from the phone's current position. Drawn ABOVE the AR view
            // so the dimmed-outside effect works, BELOW the tap layer so taps
            // still land.
            if dropKind == .camera {
                ViewfinderOverlay(spec: cameraPreset)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Tap target — a full-screen clear layer that captures taps to drop marks.
            // Sits BELOW the SwiftUI controls (top bar, buttons) so real UI is not blocked.
            TapToPlaceOverlay(onTap: handleTap)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                dropKindPicker
                Spacer()
                hintCard
                Spacer()
                bottomBar
            }
            .padding()

            // Quick visual feedback after placing a mark.
            if let t = placementFeedback, Date().timeIntervalSince(t) < 0.6 {
                Text("Mark \(store.blocking.marks.count) placed")
                    .font(.caption.bold())
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if !hasSeenOnboarding { showingOnboarding = true } }
        .sheet(item: $editingMark) { mark in
            MarkEditorSheet(mark: mark)
                .environment(store)
                .environment(session)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
                .environment(store)
                .environment(session)
        }
        .fullScreenCover(isPresented: $showingTeleprompter) {
            TeleprompterView()
                .environment(store)
                .environment(session)
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingSheet(mode: .author) {
                hasSeenOnboarding = true
                showingOnboarding = false
            }
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportItem != nil },
                set: { if !$0 { exportItem = nil } }
            ),
            document: exportItem,
            contentType: .understudyBlocking,
            defaultFilename: store.blocking.title
        ) { _ in
            exportItem = nil
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.understudyBlocking, .json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                importBlocking(from: url)
            }
        }
        .alert("Clear all marks?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                for m in store.blocking.marks {
                    session.broadcastMarkRemoved(m.id)
                }
                store.blocking.marks.removeAll()
                store.blocking.modifiedAt = Date()
            }
        } message: {
            Text("This removes every mark in '\(store.blocking.title)'. The reference walk is kept.")
        }
    }

    // MARK: - UI pieces

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(.white)
                .padding(10)
                .background(.white.opacity(0.08), in: Circle())
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(store.blocking.title)
                        .font(.headline)
                    Text("AUTHOR")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }
                Text("\(store.blocking.marks.count) marks  •  \(session.peerCount) peers  •  \(AppVersion.formatted)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            CalibrationButton()
                .environment(store)
            Button { showingTeleprompter = true } label: {
                Image(systemName: "text.quote")
                    .font(.title3)
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Open teleprompter")
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
                    .foregroundStyle(.white)
            }
        }
    }

    private var dropKindPicker: some View {
        VStack(spacing: 8) {
            Picker("Drop", selection: $dropKind) {
                Label("Actor", systemImage: "figure.stand")
                    .tag(MarkKind.actor)
                Label("Camera", systemImage: "video")
                    .tag(MarkKind.camera)
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)

            if dropKind == .camera {
                HStack(spacing: 6) {
                    ForEach(CameraSpec.presets, id: \.focalLengthMM) { spec in
                        Button {
                            cameraPreset = spec
                        } label: {
                            Text("\(Int(spec.focalLengthMM))mm")
                                .font(.caption.monospaced())
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(
                                    cameraPreset.focalLengthMM == spec.focalLengthMM
                                    ? Color.orange.opacity(0.65)
                                    : Color.white.opacity(0.08),
                                    in: Capsule()
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var hintCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.8))
            Text("Tap the floor to drop a mark")
                .font(.title3).bold()
                .foregroundStyle(.white)
            Text("Tap a mark to edit its cues")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .opacity(store.blocking.marks.isEmpty ? 1.0 : 0.0)
        .allowsHitTesting(false)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if MeshCapture.isSupported {
                scanStrip
            }
            HStack(spacing: 14) {
                Button {
                    exportItem = BlockingDocument(blocking: store.blocking)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .padding(12)
                        .background(.white.opacity(0.08), in: Circle())
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Export blocking")

                Button {
                    showingImporter = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .padding(12)
                        .background(.white.opacity(0.08), in: Circle())
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Import blocking")

                Spacer()

                Button {
                    confirmClear = true
                } label: {
                    Label("Clear", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .padding(12)
                        .background(.red.opacity(0.5), in: Circle())
                        .foregroundStyle(.white)
                }
                .disabled(store.blocking.marks.isEmpty)
                .accessibilityLabel("Clear marks")
            }
        }
    }

    /// Appears only on LiDAR-capable devices (iPhone 12 Pro+). Starts a
    /// scene-reconstruction capture, shows live triangle count, and on
    /// finish broadcasts the mesh as a RoomScan.
    @ViewBuilder private var scanStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.transparent")
                .foregroundStyle(.orange)

            switch scanState {
            case .idle:
                Button {
                    beginScan()
                } label: {
                    Text(store.blocking.roomScan == nil ? "Scan room" : "Re-scan room")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.orange.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }
                if let scan = store.blocking.roomScan {
                    Text("\(scan.triangleCount) tris • \(scan.wireKB) KB")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }
            case .scanning:
                ProgressView()
                    .controlSize(.small)
                    .tint(.orange)
                Text("\(scanTriangles) triangles")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button {
                    showingScanNameSheet = true
                } label: {
                    Text("Finish")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(.white.opacity(0.18), in: Capsule())
                        .foregroundStyle(.white)
                }
                Button(role: .destructive) {
                    cancelScan()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                }
            case .done:
                Text("Scan complete")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }

            Spacer()

            if store.blocking.roomScan != nil {
                Button(role: .destructive) {
                    store.blocking.roomScan = nil
                    store.blocking.modifiedAt = Date()
                    BlockingAutosave.save(store.blocking)
                    session.broadcastRoomScan(nil)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Remove scan")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showingScanNameSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("e.g. Brooklyn studio 4F", text: $scanNameDraft)
                    } header: { Text("Name this scan") } footer: {
                        Text("Shown to other peers as the overlay label. Captured at \(Date().formatted(date: .abbreviated, time: .shortened)).")
                    }
                }
                .navigationTitle("Finish scan")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingScanNameSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            finishScan(name: scanNameDraft)
                            showingScanNameSheet = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Scan lifecycle

    private func beginScan() {
        guard let arSession = PerformerARHost.shared.arView?.session else {
            // Need the shared ARKit session to swap in scene-reconstruction.
            return
        }
        let capture = MeshCapture(session: arSession)
        if capture.start() {
            meshCapture = capture
            scanState = .scanning
            scanTriangles = 0
            scanRefreshTimer?.invalidate()
            scanRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in
                    capture.refreshProgress()
                    scanTriangles = capture.triangleCountSoFar
                }
            }
        }
    }

    private func finishScan(name: String) {
        scanRefreshTimer?.invalidate()
        scanRefreshTimer = nil
        guard let capture = meshCapture, let scan = capture.finish(nameForScan: name) else {
            scanState = .idle
            return
        }
        store.blocking.roomScan = scan
        store.blocking.modifiedAt = Date()
        BlockingAutosave.save(store.blocking)
        session.broadcastRoomScan(scan)
        meshCapture = nil
        scanState = .done
        // Flicker back to idle after a beat.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            scanState = .idle
        }
    }

    private func cancelScan() {
        scanRefreshTimer?.invalidate()
        scanRefreshTimer = nil
        meshCapture?.stopAndDiscard()
        meshCapture = nil
        scanState = .idle
    }

    // MARK: - Tap → place / edit

    private func handleTap(at point: CGPoint) {
        guard let arView = PerformerARHost.shared.arView else {
            // AR background is off — drop a mark at the user's current pose.
            dropMarkAtCurrentPose()
            return
        }

        // First, see if the tap hit an existing mark entity.
        let hits = arView.hitTest(point)
        if let hit = hits.first,
           let markID = markID(for: hit.entity) {
            if let mark = store.blocking.marks.first(where: { $0.id == markID }) {
                editingMark = mark
                return
            }
        }

        // Otherwise, raycast to a horizontal plane (existing, then estimated).
        let results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
        let fallback = results.first
            ?? arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first
        guard let result = fallback else {
            dropMarkAtCurrentPose()
            return
        }
        let t = result.worldTransform
        // Raycast result is in the device's raw AR frame — convert to the
        // shared blocking frame before storing.
        let rawPose = Pose(x: t.columns.3.x, y: 0, z: t.columns.3.z, yaw: 0)
        let blockingPose = PerformerARHost.shared.calibration?.toBlocking(rawPose) ?? rawPose
        dropMark(at: blockingPose)
    }

    /// Extract the mark id by walking up the entity tree looking for a name
    /// of the form `mark-<id>`.
    private func markID(for entity: Entity) -> ID? {
        var node: Entity? = entity
        while let n = node {
            if n.name.hasPrefix("mark-") {
                let raw = String(n.name.dropFirst("mark-".count))
                return ID(raw)
            }
            node = n.parent
        }
        return nil
    }

    private func dropMarkAtCurrentPose() {
        guard let me = store.localPerformer else { return }
        dropMark(at: Pose(x: me.pose.x, y: 0, z: me.pose.z, yaw: me.pose.yaw))
    }

    private func dropMark(at pose: Pose) {
        let idx = (store.blocking.marks.map(\.sequenceIndex).max() ?? -1) + 1
        let name: String
        let camera: CameraSpec?
        switch dropKind {
        case .actor:
            name = "Mark \(idx + 1)"
            camera = nil
        case .camera:
            let camIdx = store.blocking.marks.filter { $0.kind == .camera }.count + 1
            name = "Cam \(camIdx) · \(Int(cameraPreset.focalLengthMM))mm"
            camera = cameraPreset
        }
        let mark = Mark(
            name: name,
            pose: pose,
            radius: dropKind == .camera ? 0.4 : 0.6,
            cues: [],
            sequenceIndex: dropKind == .camera ? -1 : idx,  // cameras aren't in the walk sequence
            kind: dropKind,
            camera: camera
        )
        store.addMark(mark)
        session.broadcastMarkAdded(mark)
        withAnimation(.easeOut(duration: 0.2)) {
            placementFeedback = Date()
        }
        // Light haptic on place.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func importBlocking(from url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let loaded = try? WireCoding.decoder.decode(Blocking.self, from: data) else {
            return
        }
        // Broadcast removals of the old blocking, then the new snapshot.
        for m in store.blocking.marks {
            session.broadcastMarkRemoved(m.id)
        }
        store.blocking = loaded
        BlockingAutosave.save(loaded)
        // Tell peers we have a new document.
        if let me = store.localPerformer {
            session.transport.send(.blockingSnapshot(loaded), from: me.id)
        }
    }
}

// MARK: - Tap overlay

/// A UIKit-backed transparent layer that captures single taps and reports
/// their location. We use UIKit because SwiftUI's gestures can conflict with
/// the ARView's touches-through behavior at screen edges.
private struct TapToPlaceOverlay: UIViewRepresentable {
    let onTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> UIView {
        let v = PassthroughTapView()
        v.onTap = context.coordinator.handle
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        (uiView as? PassthroughTapView)?.onTap = context.coordinator.handle
    }

    final class Coordinator {
        var onTap: (CGPoint) -> Void
        init(onTap: @escaping (CGPoint) -> Void) { self.onTap = onTap }
        func handle(_ p: CGPoint) { onTap(p) }
    }
}

/// UIView that captures single taps but lets every other touch pass through
/// to whatever SwiftUI drew above it. Tap recognizer fires on tap-up.
private final class PassthroughTapView: UIView {
    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func didTap(_ g: UITapGestureRecognizer) {
        onTap?(g.location(in: self))
    }

    // Let touches on controls above us pass through. We only care about
    // gesture events, which the recognizer captures anyway.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? self : hit
    }
}

// MARK: - Mark editor sheet

struct MarkEditorSheet: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(CueFXEngine.self) private var fx
    @Environment(\.dismiss) private var dismiss

    @State var mark: Mark
    @State private var newLine: String = ""
    @State private var newCharacter: String = ""
    @State private var newNote: String = ""
    @State private var selectedSFX: String = "bell"
    @State private var selectedLight: LightColor = .warm
    @State private var lightIntensity: Double = 0.8
    @State private var waitSeconds: Double = 1.0
    @State private var confirmDelete = false
    @State private var showingScriptBrowser = false

    private let sfxNames = ["bell", "thunder", "chime", "knock", "applause"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Mark") {
                    TextField("Name", text: $mark.name)
                    LabeledContent("Kind") {
                        Text(mark.kind.rawValue.capitalized)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Radius")
                        Slider(value: $mark.radius, in: 0.2...3.0, step: 0.1)
                        Text(String(format: "%.1f m", mark.radius))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                    HStack {
                        Text("Position")
                        Spacer()
                        Text(String(format: "x %.2f  z %.2f", mark.pose.x, mark.pose.z))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if mark.kind == .camera {
                    Section("Lens") {
                        let binding = Binding<CameraSpec>(
                            get: { mark.camera ?? CameraSpec() },
                            set: { mark.camera = $0 }
                        )
                        LabeledContent {
                            HStack(spacing: 4) {
                                ForEach(CameraSpec.presets, id: \.focalLengthMM) { preset in
                                    Button("\(Int(preset.focalLengthMM))") {
                                        var updated = binding.wrappedValue
                                        updated.focalLengthMM = preset.focalLengthMM
                                        updated.sensorWidthMM = preset.sensorWidthMM
                                        updated.sensorHeightMM = preset.sensorHeightMM
                                        binding.wrappedValue = updated
                                        mark.name = "\(mark.name.split(separator: "·").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? mark.name) · \(Int(preset.focalLengthMM))mm"
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(abs(binding.wrappedValue.focalLengthMM - preset.focalLengthMM) < 0.1 ? .orange : .gray)
                                    .font(.caption.monospaced())
                                }
                            }
                        } label: { Text("Focal") }
                        HStack {
                            Text("Height")
                            Slider(value: Binding(
                                get: { binding.wrappedValue.heightM },
                                set: { var u = binding.wrappedValue; u.heightM = $0; binding.wrappedValue = u }
                            ), in: 0.3...2.5, step: 0.05)
                            Text(String(format: "%.2f m", binding.wrappedValue.heightM))
                                .font(.caption.monospacedDigit())
                                .frame(width: 60, alignment: .trailing)
                        }
                        HStack {
                            Text("Tilt")
                            Slider(value: Binding(
                                get: { Double(binding.wrappedValue.tiltRadians) * 180 / .pi },
                                set: { var u = binding.wrappedValue; u.tiltRadians = Float($0 * .pi / 180); binding.wrappedValue = u }
                            ), in: -45...45, step: 1)
                            Text(String(format: "%.0f°", Double(binding.wrappedValue.tiltRadians) * 180 / .pi))
                                .font(.caption.monospacedDigit())
                                .frame(width: 50, alignment: .trailing)
                        }
                        HStack {
                            Text("HFOV")
                            Spacer()
                            Text(String(format: "%.0f°", Double(binding.wrappedValue.horizontalFOV) * 180 / .pi))
                                .font(.caption.monospaced())
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Lines") {
                    ForEach(mark.cues.indices, id: \.self) { i in
                        if case .line(_, let text, let character) = mark.cues[i] {
                            VStack(alignment: .leading) {
                                if let c = character {
                                    Text(c.uppercased())
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.red)
                                }
                                Text(text).font(.body)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let lineIndices = mark.cues.enumerated().compactMap {
                            if case .line = $0.element { return $0.offset } else { return nil }
                        }
                        let drop = offsets.map { lineIndices[$0] }
                        mark.cues.remove(atOffsets: IndexSet(drop))
                    }
                    Button {
                        showingScriptBrowser = true
                    } label: {
                        Label("Pick from Hamlet…", systemImage: "text.book.closed")
                    }
                    .tint(.purple)
                    TextField("Character (optional)", text: $newCharacter)
                    TextField("Add a line…", text: $newLine, axis: .vertical)
                        .lineLimit(1...4)
                    Button("Add Custom Line") {
                        mark.cues.append(.line(
                            id: ID(),
                            text: newLine.trimmingCharacters(in: .whitespacesAndNewlines),
                            character: newCharacter.isEmpty ? nil : newCharacter
                        ))
                        newLine = ""
                    }
                    .disabled(newLine.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Sound") {
                    Picker("Effect", selection: $selectedSFX) {
                        ForEach(sfxNames, id: \.self) { Text($0.capitalized) }
                    }
                    Button("Add Sound Cue") {
                        mark.cues.append(.sfx(id: ID(), name: selectedSFX))
                    }
                }

                Section("Light") {
                    Picker("Color", selection: $selectedLight) {
                        ForEach(LightColor.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    HStack {
                        Text("Intensity")
                        Slider(value: $lightIntensity, in: 0.1...1.0)
                        Text(String(format: "%.1f", lightIntensity))
                            .font(.caption.monospacedDigit())
                            .frame(width: 40)
                    }
                    Button("Add Light Cue") {
                        mark.cues.append(.light(
                            id: ID(),
                            color: selectedLight,
                            intensity: Float(lightIntensity)
                        ))
                    }
                }

                Section("Beat") {
                    HStack {
                        Text("Hold")
                        Slider(value: $waitSeconds, in: 0.5...10.0, step: 0.5)
                        Text(String(format: "%.1fs", waitSeconds))
                            .font(.caption.monospacedDigit())
                            .frame(width: 50)
                    }
                    Button("Add Wait Cue") {
                        mark.cues.append(.wait(id: ID(), seconds: waitSeconds))
                    }
                }

                Section("Note (director only)") {
                    TextField("Add a director note…", text: $newNote)
                    Button("Add Note") {
                        mark.cues.append(.note(id: ID(), text: newNote))
                        newNote = ""
                    }
                    .disabled(newNote.isEmpty)
                }

                Section {
                    ForEach(mark.cues.indices, id: \.self) { i in
                        HStack {
                            Text(mark.cues[i].humanLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Spacer()
                            Button {
                                fx.preview(mark.cues[i])
                            } label: {
                                Image(systemName: "play.circle")
                                    .foregroundStyle(.purple)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Preview this cue")
                        }
                    }
                    .onDelete { mark.cues.remove(atOffsets: $0) }
                } header: {
                    Text("All Cues (\(mark.cues.count))")
                } footer: {
                    Text("Cues fire in order when a performer enters this mark. Tap ▷ to preview.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete Mark", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(mark.name)
            .navigationBarTitleDisplayMode(.inline)
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
            .alert("Delete \(mark.name)?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    store.removeMark(id: mark.id)
                    session.broadcastMarkRemoved(mark.id)
                    dismiss()
                }
            }
            .sheet(isPresented: $showingScriptBrowser) {
                ScriptBrowser(mark: $mark)
            }
        }
    }
}
#endif
