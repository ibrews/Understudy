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
    @State private var hasOnboarded = false

    init() {
        let initialName = UIDeviceOrFallbackName()
        #if os(visionOS)
        let role: Performer.Role = .director
        #else
        let role: Performer.Role = .performer
        #endif
        let me = Performer(displayName: initialName, role: role)
        let s = BlockingStore(
            blocking: Blocking(title: "Untitled Piece", authorName: initialName),
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
        PerformerContainer()
        #else
        Text("Unsupported platform")
        #endif
    }
}

#if os(iOS)
struct PerformerContainer: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @AppStorage("showARStage") private var showARStage: Bool = true

    var body: some View {
        PerformerView()
            .onAppear {
                // Tell the host which store/session to use. Session ownership
                // depends on the AR background toggle: if AR is on, the
                // ARStageContainer will hand over the session via adopt(). If
                // not, we run a standalone provider here.
                PerformerARHost.shared.configure(store: store, session: session)
                if !showARStage {
                    PerformerARHost.shared.startStandalone()
                }
            }
            .onDisappear {
                PerformerARHost.shared.stop()
            }
            .onChange(of: showARStage) { _, nowOn in
                if nowOn {
                    // When the user flips AR back on, the ARStageContainer
                    // will appear and adopt its own session. Stop any
                    // standalone provider so we don't run two sessions.
                    PerformerARHost.shared.stop()
                } else {
                    PerformerARHost.shared.stop()
                    PerformerARHost.shared.startStandalone()
                }
            }
    }
}
#endif
