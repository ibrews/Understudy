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
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("roomCode") private var roomCode: String = "rehearsal"
    @AppStorage("seededDemo") private var seededDemo: Bool = false
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
        _store = State(wrappedValue: s)
        _sessionController = State(wrappedValue: sc)
        _fx = State(wrappedValue: engine)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(sessionController)
                .environment(fx)
                .onAppear {
                    if !hasOnboarded {
                        // Seed default display name from device name if user hasn't set one.
                        if displayName.isEmpty {
                            displayName = store.localPerformer?.displayName ?? "Performer"
                        }
                        sessionController.roomCode = roomCode
                        sessionController.start()
                        fx.attach(store: store)
                        // Restore OSC config from defaults.
                        let ud = UserDefaults.standard
                        let host = ud.string(forKey: "oscHost") ?? ""
                        let port = UInt16(ud.string(forKey: "oscPort") ?? "53000") ?? 53000
                        let enabled = ud.bool(forKey: "oscEnabled")
                        fx.osc.configure(host: host.isEmpty ? nil : host, port: port, enabled: enabled)
                        hasOnboarded = true
                    }
                }
        }
        #if os(visionOS)
        .defaultSize(width: 520, height: 720)
        #endif

        #if os(visionOS)
        ImmersiveSpace(id: "Stage") {
            DirectorImmersiveView()
                .environment(store)
                .environment(sessionController)
                .environment(fx)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        #endif
    }
}

/// A reasonable default name on first launch.
private func UnderstudyApp_DummyFunc() {}

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
