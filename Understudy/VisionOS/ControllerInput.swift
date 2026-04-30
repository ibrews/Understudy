//
//  ControllerInput.swift
//  Understudy (visionOS)
//
//  Sony PSVR2 Sense controllers + any other extended-gamepad-profile
//  controller (Xbox, PlayStation 4/5, MFi) via Apple's GameController
//  framework. Hand-tracking gestures continue to work in parallel — this
//  is purely additive.
//
//  Mapping (PSVR2 Sense — both hands; identical mirrored mapping):
//
//    • Trigger          →  Drop mark at the gaze cursor / fire next cue if
//                          inside an existing mark
//    • Grip             →  Open Stage / Close Stage toggle
//    • Thumbstick       →  Walk the GO cursor (push forward = next mark,
//                          pull back = previous mark). Click = open
//                          teleprompter
//    • Cross / X        →  Run Demo (theater showcase)
//    • Circle / O       →  Toggle Tabletop view
//    • Triangle         →  Toggle stage grid overlay
//    • Square           →  Open mark editor for the nearest mark
//    • Options / Menu   →  Toggle Director Panel visibility (system gesture)
//
//  visionOS 2.0+ exposes the PSVR2 Sense via `GCController.controllers()`
//  with the standard `extendedGamepad` profile; no Sony-specific SDK
//  needed. visionOS handles pairing in System Settings → Bluetooth.
//

#if os(visionOS)
import Foundation
import GameController
import SwiftUI
import Observation

@MainActor
@Observable
public final class ControllerInput {
    public private(set) var controllers: [GCController] = []
    public var hasController: Bool { !controllers.isEmpty }

    /// Controller actions — set by the host (DirectorImmersiveView /
    /// DirectorControlPanel) to handle the input.
    public var onTrigger: (() -> Void)?
    public var onGrip: (() -> Void)?
    public var onStickForward: (() -> Void)?  // GO next
    public var onStickBack: (() -> Void)?     // GO back
    public var onStickClick: (() -> Void)?    // open teleprompter
    public var onCross: (() -> Void)?         // run demo
    public var onCircle: (() -> Void)?        // tabletop toggle
    public var onTriangle: (() -> Void)?      // grid toggle
    public var onSquare: (() -> Void)?        // open mark editor
    public var onMenu: (() -> Void)?          // panel visibility

    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    /// Throttle stick events so a held stick doesn't fire 60 events/sec.
    private var lastStickFireDate: Date = .distantPast

    public init() {}

    public func start() {
        // Pick up controllers already paired before we started observing.
        for c in GCController.controllers() { register(c) }

        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let c = note.object as? GCController else { return }
            Task { @MainActor in self?.register(c) }
        }
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let c = note.object as? GCController else { return }
            Task { @MainActor in self?.unregister(c) }
        }
        // Start system-wide controller discovery (BLE pairing flow happens
        // in System Settings; this just tells GCController to be ready).
        GCController.startWirelessControllerDiscovery {}
    }

    public func stop() {
        if let o = connectObserver { NotificationCenter.default.removeObserver(o) }
        if let o = disconnectObserver { NotificationCenter.default.removeObserver(o) }
        connectObserver = nil
        disconnectObserver = nil
        controllers = []
    }
    // Intentionally no deinit — main-actor properties can't be touched from
    // a nonisolated context. Callers are expected to call stop() in their
    // host view's onDisappear (DirectorControlPanel does).

    // MARK: - Wiring

    private func register(_ controller: GCController) {
        guard !controllers.contains(where: { $0 === controller }) else { return }
        controllers.append(controller)
        bindGamepad(controller)
    }

    private func unregister(_ controller: GCController) {
        controllers.removeAll { $0 === controller }
    }

    private func bindGamepad(_ controller: GCController) {
        guard let gp = controller.extendedGamepad else { return }

        // Trigger — primary action.
        gp.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onTrigger?() }
        }
        gp.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onTrigger?() }
        }

        // Grip / shoulder — Open / Close Stage.
        gp.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onGrip?() }
        }
        gp.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onGrip?() }
        }

        // Right thumbstick — GO forward / back. Throttled to 4 Hz.
        gp.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            guard let self else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastStickFireDate) > 0.25 else { return }
            if y > 0.6 {
                self.lastStickFireDate = now
                Task { @MainActor in self.onStickForward?() }
            } else if y < -0.6 {
                self.lastStickFireDate = now
                Task { @MainActor in self.onStickBack?() }
            }
        }
        gp.rightThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onStickClick?() }
        }

        // Face buttons — A=Cross, B=Circle, X=Square, Y=Triangle (Apple-side).
        gp.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onCross?() }
        }
        gp.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onCircle?() }
        }
        gp.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onSquare?() }
        }
        gp.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onTriangle?() }
        }

        // Menu / Options.
        gp.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onMenu?() }
        }
    }
}

// MARK: - Help / discovery view

/// A small floating panel that explains the controller mapping and shows
/// connection status. Surfaced from the Director Panel so a director using
/// PSVR2 controllers for the first time has a discoverable cheat sheet.
public struct ControllerHelpView: View {
    @Environment(ControllerInput.self) private var input
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: input.hasController
                              ? "gamecontroller.fill"
                              : "gamecontroller")
                            .font(.title)
                            .foregroundStyle(input.hasController ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(input.hasController ? "Controller connected" : "No controller paired")
                                .font(.headline)
                            Text(input.controllers.count == 0
                                 ? "Pair a PSVR2 Sense (or any extended-gamepad MFi controller) in System Settings → Bluetooth."
                                 : input.controllers.compactMap { $0.vendorName }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } footer: {
                    Text("Hand tracking continues to work in parallel — controllers are additive, not exclusive.")
                        .font(.caption)
                }

                Section("Mapping") {
                    mapping("Trigger", "Drop mark / fire next cue", "circle.dashed")
                    mapping("Grip / Shoulder", "Open / Close Stage", "rectangle.expand.vertical")
                    mapping("Stick Up", "GO next mark", "arrow.up")
                    mapping("Stick Down", "GO back one mark", "arrow.down")
                    mapping("Stick Click", "Open Teleprompter", "text.quote")
                    mapping("X / Cross", "Run a demo showcase", "sparkles.tv")
                    mapping("O / Circle", "Toggle Tabletop view", "rectangle.inset.filled")
                    mapping("Triangle", "Toggle stage grid", "grid")
                    mapping("Square", "Edit nearest mark", "square.and.pencil")
                    mapping("Menu / Options", "Toggle panel visibility", "list.bullet.rectangle")
                }

                Section {
                    Text("Mapping is identical on the left and right Sense controllers. Pinch / tap gestures still work the same way they always did.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Controllers")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func mapping(_ button: String, _ action: String, _ symbol: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(button).font(.body.bold())
                Text(action).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
#endif
