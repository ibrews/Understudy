//
//  ImmersiveSceneCoordinatorTests.swift
//  UnderstudyTests
//
//  Unit tests for the app-scoped immersive coordinator that fixed the
//  "stage won't reopen" bug (A1). These cover the SYNCHRONOUS invariants —
//  the open()/close() paths take SwiftUI environment actions
//  (OpenImmersiveSpaceAction) that can't be constructed in a unit test, so
//  those are exercised at runtime in the visionOS simulator. The most
//  important regression guard here is `systemDidDismiss()` resetting the
//  phase: that's the exact desync the coordinator was introduced to fix.
//

#if os(visionOS)
import Testing
import SwiftUI
@testable import Understudy

@MainActor
struct ImmersiveSceneCoordinatorTests {

    @Test func startsClosed() {
        let c = ImmersiveSceneCoordinator()
        #expect(c.phase == .closed)
        #expect(c.isOpen == false)
        #expect(c.isBusy == false)
    }

    @Test func systemPresentDrivesOpen() {
        let c = ImmersiveSceneCoordinator()
        c.systemDidPresent()
        #expect(c.phase == .open)
        #expect(c.isOpen)
    }

    /// The A1 regression guard: a system-driven dismissal (Digital Crown
    /// "close all", backgrounding, headset removal) must reset the phase so
    /// the panel button flips back to "Open Stage" and a single tap reopens.
    @Test func systemDismissResetsPhase() {
        let c = ImmersiveSceneCoordinator()
        c.systemDidPresent()
        c.systemDidDismiss()
        #expect(c.phase == .closed)
        #expect(c.isOpen == false)
    }

    @Test func immersionStyleMirrorsFlag() {
        let c = ImmersiveSceneCoordinator()
        #expect(c.immersionStyle is MixedImmersionStyle)
        c.isFullImmersion = true
        #expect(c.immersionStyle is FullImmersionStyle)
    }

    /// Real-hands and virtual-hands are orthogonal layers with distinct
    /// defaults — real hands visible (passthrough), virtual hands off.
    @Test func handLayerDefaults() {
        let c = ImmersiveSceneCoordinator()
        #expect(c.showRealHands == true)
        #expect(c.showVirtualHands == false)
        // IBL is an opt-in demo/lighting toggle — off by default.
        #expect(c.iblEnabled == false)
    }

    @Test func stageIDIsStable() {
        #expect(ImmersiveSceneCoordinator.stageID == "Stage")
    }
}
#endif
