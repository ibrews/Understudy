//
//  UnderstudyApp.swift
//  Understudy
//
//  Cross-target entry point. iOS → Performer, visionOS → Director window + Stage.
//

import SwiftUI

@main
struct UnderstudyApp: App {
    @State private var store: BlockingStore
    @State private var sessionController: SessionController
    @State private var fx: CueFXEngine
    @State private var demoRunner: DemoRunner
    #if os(visionOS)
    @State private var controllerInput: ControllerInput
    /// App-scoped immersive-stage state. Replaces the old per-view
    /// `immersiveActive` flag so the panel button stays in sync with the
    /// system across Crown/background dismissals and view rebuilds.
    @State private var immersiveCoordinator: ImmersiveSceneCoordinator
    #endif
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("roomCode") private var roomCode: String = "rehearsal"
    /// When true, the immersive stage opens automatically on launch (visionOS).
    /// Director can disable this from the control panel if they want the
    /// floating window to stay solo.
    @AppStorage("autoOpenStage") private var autoOpenStage: Bool = true
    /// Avatar persistence — restored on launch + applied to the local
    /// performer so they show up to peers with their chosen look.
    @AppStorage("avatarStyle") private var avatarStyleRaw: String = Avatar.Style.performer.rawValue
    @AppStorage("avatarPrimary") private var avatarPrimary: String = Avatar.defaultPick.primaryHex
    @AppStorage("avatarSecondary") private var avatarSecondary: String = Avatar.defaultPick.secondaryHex
    @State private var hasOnboarded = false

    init() {
        let initialName = UIDeviceOrFallbackName()
        #if os(visionOS)
        let role: Performer.Role = .director
        #else
        let role: Performer.Role = .performer
        #endif
        let me = Performer(displayName: initialName, role: role)
        // Restore user's last-saved blocking, or seed the Hamlet demo on first launch.
        let initialBlocking = BlockingAutosave.load() ?? DemoBlockings.hamletOpening
        let s = BlockingStore(
            blocking: initialBlocking,
            localPerformer: me
        )
        let t = MultipeerTransport()
        let sc = SessionController(transport: t, kind: .multipeer, store: s, roomCode: "rehearsal")
        let engine = CueFXEngine()
        let runner = DemoRunner()
        _store = State(wrappedValue: s)
        _sessionController = State(wrappedValue: sc)
        _fx = State(wrappedValue: engine)
        _demoRunner = State(wrappedValue: runner)
        #if os(visionOS)
        let ci = ControllerInput()
        _controllerInput = State(wrappedValue: ci)
        _immersiveCoordinator = State(wrappedValue: ImmersiveSceneCoordinator())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(sessionController)
                .environment(fx)
                .environment(demoRunner)
                #if os(visionOS)
                .environment(controllerInput)
                .environment(immersiveCoordinator)
                #endif
                .overlay(DemoRunnerOverlay().environment(demoRunner))
                .onAppear {
                    if !hasOnboarded {
                        // Seed default display name from device name if user hasn't set one.
                        if displayName.isEmpty {
                            displayName = store.localPerformer?.displayName ?? "Performer"
                        }
                        // Hydrate the local performer's avatar from saved
                        // preferences so the chosen look survives relaunches.
                        if var me = store.localPerformer {
                            let style = Avatar.Style(rawValue: avatarStyleRaw) ?? .performer
                            me.avatar = Avatar(
                                style: style,
                                primaryHex: avatarPrimary,
                                secondaryHex: avatarSecondary
                            )
                            store.upsertPerformer(me)
                        }
                        sessionController.roomCode = roomCode
                        sessionController.start()
                        fx.attach(store: store)
                        // Restore OSC config from defaults (outbound + inbound).
                        let ud = UserDefaults.standard
                        let host = ud.string(forKey: "oscHost") ?? ""
                        let port = UInt16(ud.string(forKey: "oscPort") ?? "53000") ?? 53000
                        let enabled = ud.bool(forKey: "oscEnabled")
                        fx.osc.configure(host: host.isEmpty ? nil : host, port: port, enabled: enabled)
                        let rxPort = UInt16(ud.string(forKey: "oscReceivePort") ?? "53001") ?? 53001
                        let rxEnabled = ud.bool(forKey: "oscReceiveEnabled")
                        fx.configureOSCReceive(port: rxPort, enabled: rxEnabled)
                        // Restore DMX config (universe + multicast/unicast destination).
                        let dmxEnabled = ud.bool(forKey: "dmxEnabled")
                        let dmxUniverse = Int(ud.string(forKey: "dmxUniverse") ?? "1") ?? 1
                        let dmxKind = ud.string(forKey: "dmxDestinationKind") ?? "multicast"
                        let dmxIp = ud.string(forKey: "dmxDestinationIp") ?? ""
                        fx.configureDMX(
                            enabled: dmxEnabled,
                            universe: dmxUniverse,
                            destinationKind: dmxKind,
                            destinationIp: dmxIp
                        )
                        hasOnboarded = true
                    }
                }
        }
        #if os(visionOS)
        .defaultSize(width: 520, height: 720)
        #endif

        #if os(visionOS)
        ImmersiveSpace(id: ImmersiveSceneCoordinator.stageID) {
            DirectorImmersiveView()
                .environment(store)
                .environment(sessionController)
                .environment(fx)
                .environment(demoRunner)
                .environment(controllerInput)
                .environment(immersiveCoordinator)
                // Real-hands passthrough is a layer independent of any virtual
                // hand mesh — drive it straight off the coordinator toggle.
                .upperLimbVisibility(immersiveCoordinator.showRealHands ? .visible : .hidden)
                // The ImmersiveSpace's OWN appear/disappear is the only
                // authoritative present/dismiss signal. .onDisappear fires on
                // Digital Crown "close all", backgrounding, and headset removal
                // — exactly the events the old view-local flag missed, which is
                // why the stage "wouldn't reopen."
                .onAppear { immersiveCoordinator.systemDidPresent() }
                .onDisappear { immersiveCoordinator.systemDidDismiss() }
        }
        // Allow a runtime Mixed↔Full toggle. Default (isFullImmersion=false)
        // resolves to .mixed — identical to the previous .constant(.mixed).
        .immersionStyle(
            selection: Binding(
                get: { immersiveCoordinator.immersionStyle },
                set: { immersiveCoordinator.isFullImmersion = ($0 is FullImmersionStyle) }
            ),
            in: .mixed, .full
        )

        // Teleprompter floats as its own window the director can position
        // anywhere in their space.
        WindowGroup(id: "Teleprompter") {
            TeleprompterView()
                .environment(store)
                .environment(sessionController)
                .environment(fx)
        }
        .defaultSize(width: 720, height: 900)

        // QR calibration target — a floating sheet the director can pin to
        // a wall (or hand out a printed version). Performers scan it with
        // iPhones to auto-calibrate to a shared origin.
        WindowGroup(id: "QRTarget") {
            QRCalibrationView()
        }
        .defaultSize(width: 540, height: 720)
        #endif
    }
}

@MainActor
fileprivate func UIDeviceOrFallbackName() -> String {
    #if os(iOS)
    return UIDevice.current.name
    #elseif os(visionOS)
    return "Director"
    #else
    return "Performer"
    #endif
}

#if canImport(UIKit)
import UIKit
#endif

struct RootView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    var body: some View {
        #if os(visionOS)
        DirectorControlPanel()
        #elseif os(iOS)
        ModeRouter()
        #else
        Text("Unsupported platform")
        #endif
    }
}

#if os(iOS)
/// Routes the iPhone to the right top-level view based on `appMode`.
/// On first launch (no mode picked yet) shows the ModeSelector; after the
/// user picks, settles on whichever view matches.
struct ModeRouter: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @AppStorage("appMode") private var appModeRaw: String = AppMode.perform.rawValue
    @AppStorage("hasPickedMode") private var hasPickedMode: Bool = false

    var body: some View {
        Group {
            if !hasPickedMode {
                ModeSelector { _ in
                    // Nothing to do — the picker already wrote appMode & hasPickedMode.
                }
            } else {
                let mode = AppMode(rawValue: appModeRaw) ?? .perform
                switch mode {
                case .perform:  PerformerContainer()
                case .author:   AuthorContainer()
                case .audience: AudienceContainer()
                }
            }
        }
        .onChange(of: appModeRaw) { _, new in
            // Changing modes updates the wire-level role so directors see
            // authors and audiences correctly.
            guard var me = store.localPerformer,
                  let newMode = AppMode(rawValue: new) else { return }
            me.role = newMode.role
            store.upsertPerformer(me)
            if let senderID = store.localPerformer?.id {
                session.transport.send(.performerUpdate(me), from: senderID)
            }
        }
    }
}

struct PerformerContainer: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @AppStorage("showARStage") private var showARStage: Bool = true

    var body: some View {
        PerformerView()
            .modifier(ARHostLifecycle(showARStage: showARStage))
    }
}

struct AuthorContainer: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @AppStorage("showARStage") private var showARStage: Bool = true

    var body: some View {
        AuthorView()
            .modifier(ARHostLifecycle(showARStage: showARStage))
    }
}

struct AudienceContainer: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @AppStorage("showARStage") private var showARStage: Bool = true

    var body: some View {
        AudienceView()
            .modifier(ARHostLifecycle(showARStage: showARStage))
    }
}

/// Shared lifecycle management for the AR host — every iPhone mode needs
/// to configure the session and start/stop the pose provider the same way.
private struct ARHostLifecycle: ViewModifier {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    let showARStage: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                PerformerARHost.shared.configure(store: store, session: session)
                if !showARStage {
                    PerformerARHost.shared.startStandalone()
                }
            }
            .onDisappear {
                PerformerARHost.shared.stop()
            }
            .onChange(of: showARStage) { _, nowOn in
                PerformerARHost.shared.stop()
                if !nowOn {
                    PerformerARHost.shared.startStandalone()
                }
            }
    }
}
#endif
