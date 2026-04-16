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
        let sc = SessionController(transport: t, store: s, roomCode: "rehearsal")
        _store = State(wrappedValue: s)
        _sessionController = State(wrappedValue: sc)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(sessionController)
                .onAppear {
                    if !hasOnboarded {
                        // Seed default display name from device name if user hasn't set one.
                        if displayName.isEmpty {
                            displayName = store.localPerformer?.displayName ?? "Performer"
                        }
                        sessionController.roomCode = roomCode
                        sessionController.start()
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
    @State private var ar: ARPoseProvider?

    var body: some View {
        PerformerView()
            .onAppear {
                let provider = ARPoseProvider(store: store, sessionController: session)
                provider.start()
                ar = provider
            }
            .onDisappear {
                ar?.stop()
                ar = nil
            }
    }
}
#endif
