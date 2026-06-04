//
//  ImmersiveSceneCoordinator.swift
//  Understudy (visionOS)
//
//  App-scoped source of truth for the immersive "Stage."
//
//  Replaces the per-view `immersiveActive` @State that used to live in
//  DirectorControlPanel. That flag was only ever set true on a successful
//  open and never reset when the system tore the space down (Digital Crown
//  "close all", backgrounding, removing the headset), so the panel button
//  drifted out of sync — it would say "Close Stage" against an already-closed
//  space, turning the next tap into a no-op and stranding the director in a
//  flat window ("the stage won't reopen").
//
//  This coordinator fixes that by:
//    1. Owning immersive presence app-wide (survives window/view rebuilds).
//    2. Taking its authoritative open/closed signal from the ImmersiveSpace's
//       OWN .onAppear/.onDisappear — the only events that actually track the
//       system mounting/tearing-down the scene.
//    3. Serializing opens behind `guard phase == .closed`, which kills the
//       concurrent double-open race (auto-open + a fast tap/controller grip).
//    4. Surfacing .error/.userCancelled as a recoverable banner instead of a
//       silent no-op.
//
//  It also owns the two runtime "feel" toggles that are orthogonal layers and
//  must not be conflated:
//    - immersion mode (Mixed passthrough ↔ Full app-provided environment)
//    - real-hands passthrough visibility (.upperLimbVisibility) vs. drawn
//      virtual-hand meshes (a separate RealityKit layer).
//

#if os(visionOS)
import SwiftUI
import OSLog

@MainActor
@Observable
final class ImmersiveSceneCoordinator {

    /// Lifecycle of the immersive Stage. `.opening`/`.closing` are transient
    /// transition states used to disable the toggle mid-flight.
    enum Phase: Equatable { case closed, opening, open, closing }

    /// The immersive scene id, shared by the app's `ImmersiveSpace(id:)`
    /// declaration and every open/dismiss call site.
    static let stageID = "Stage"

    private(set) var phase: Phase = .closed

    /// Set when an open attempt fails; drives the recoverable banner in the
    /// Director panel. Cleared on the next successful open.
    var lastOpenError: OpenError?

    // MARK: Runtime immersion mode (Mixed ↔ Full)

    /// `false` → `.mixed` (passthrough overlay, real room visible).
    /// `true`  → `.full`  (the app's own environment/skybox replaces the room).
    /// Bound into `.immersionStyle(selection:in:)` via `immersionStyle`.
    var isFullImmersion: Bool = false

    /// The concrete `ImmersionStyle` for the scene's `selection:` binding.
    /// Derived from `isFullImmersion` so we keep a single Bool source of truth
    /// (ImmersionStyle itself isn't Equatable, so we can't store/compare it).
    var immersionStyle: any ImmersionStyle { isFullImmersion ? .full : .mixed }

    // MARK: Hand visibility — two orthogonal layers (don't conflate)

    /// Real-hands passthrough. Drives `.upperLimbVisibility(.visible/.hidden)`
    /// on the immersive scene. Hiding real hands is what you want when you
    /// render virtual hands, or in Full immersion for a clean look.
    var showRealHands: Bool = true

    /// Drawn virtual-hand meshes (a RealityKit layer rendered in the stage,
    /// independent of the passthrough layer above). Off by default.
    var showVirtualHands: Bool = false

    // MARK: Derived

    var isOpen: Bool { phase == .open }
    /// True while a transition is in flight — use to disable the toggle.
    var isBusy: Bool { phase == .opening || phase == .closing }

    struct OpenError: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Understudy",
        category: "Immersive"
    )

    // MARK: - Open / close (the single serialization funnel)

    /// Open the Stage. ALL open paths (launch auto-open, panel button,
    /// controller grip) route here so the `guard phase == .closed` is the one
    /// place that serializes concurrent triggers. (The parameter is named
    /// `action` rather than `open` so it doesn't shadow this method.)
    func open(_ action: OpenImmersiveSpaceAction, id: String = ImmersiveSceneCoordinator.stageID) async {
        guard phase == .closed else {
            log.debug("open ignored — phase is \(String(describing: self.phase))")
            return
        }
        phase = .opening
        lastOpenError = nil
        switch await action(id: id) {
        case .opened:
            // .onAppear → systemDidPresent() is the authoritative mount, but
            // set .open here too so UI is correct even if onAppear is delayed.
            phase = .open
        case .userCancelled:
            log.notice("immersive open userCancelled")
            phase = .closed
        case .error:
            log.error("immersive open returned .error")
            phase = .closed
            lastOpenError = OpenError(message: "The stage couldn't open. Tap Try Again.")
        @unknown default:
            phase = .closed
            lastOpenError = OpenError(message: "The stage couldn't open. Tap Try Again.")
        }
    }

    /// Close the Stage. Tolerates being called while `.opening` (cancel an
    /// in-flight open) as well as while `.open`.
    func close(_ action: DismissImmersiveSpaceAction) async {
        guard phase == .open || phase == .opening else { return }
        phase = .closing
        await action()
        phase = .closed
    }

    /// Convenience for a single toggle button. External labels stay
    /// `open:`/`dismiss:`; internal names avoid shadowing `open`/`close`.
    func toggle(open openAction: OpenImmersiveSpaceAction,
                dismiss dismissAction: DismissImmersiveSpaceAction) async {
        if isOpen {
            await close(dismissAction)
        } else if phase == .closed {
            await open(openAction)
        }
    }

    // MARK: - Authoritative system signals (wired from the ImmersiveSpace)

    /// Called from the ImmersiveSpace content's `.onAppear` — the scene is
    /// actually mounted.
    func systemDidPresent() {
        log.debug("ImmersiveSpace did present")
        phase = .open
    }

    /// Called from the ImmersiveSpace content's `.onDisappear`. This is the
    /// signal the old view-local flag never received: it fires on Digital
    /// Crown "close all", backgrounding, and headset removal, so the panel
    /// button reliably flips back to "Open Stage."
    func systemDidDismiss() {
        log.debug("ImmersiveSpace did dismiss")
        phase = .closed
    }
}
#endif
