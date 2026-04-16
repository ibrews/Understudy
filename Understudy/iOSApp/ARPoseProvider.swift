//
//  ARPoseProvider.swift
//  Understudy (iOS)
//
//  Pipes ARKit world tracking into the BlockingStore. The device's camera
//  transform becomes the performer's Pose, at ~30Hz.
//

#if os(iOS)
import ARKit
import simd

@MainActor
final class ARPoseProvider: NSObject, ARSessionDelegate {
    let session: ARSession
    private weak var store: BlockingStore?
    private weak var sessionController: SessionController?
    /// When true, `start()` / `stop()` are no-ops because another component
    /// (e.g. ARView) owns this session's lifecycle.
    private let ownsSession: Bool
    /// Latest raw-frame pose from ARKit, kept so the UI can calibrate
    /// (snapshot this as `DeviceCalibration.anchor` when the user taps
    /// "Set Origin Here").
    private(set) var latestRawPose: Pose = Pose()

    /// Original init — provider creates and runs its own ARSession.
    init(store: BlockingStore, sessionController: SessionController) {
        self.session = ARSession()
        self.store = store
        self.sessionController = sessionController
        self.ownsSession = true
        super.init()
        session.delegate = self
    }

    /// Overload for when an `ARView` (or other host) already owns an `ARSession`.
    /// The provider attaches as delegate to read pose updates but does NOT
    /// start or stop the session itself.
    init(session: ARSession, store: BlockingStore, sessionController: SessionController) {
        self.session = session
        self.store = store
        self.sessionController = sessionController
        self.ownsSession = false
        super.init()
        // Be polite: if the host set its own delegate, chain is the caller's
        // responsibility. For Understudy the ARView doesn't install a delegate,
        // so we just claim it.
        session.delegate = self
    }

    func start() {
        guard ownsSession else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .none
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        guard ownsSession else { return }
        session.pause()
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let t = frame.camera.transform
        // Camera -Z is forward; we want yaw around world Y.
        let forward = -SIMD3<Float>(t.columns.2.x, 0, t.columns.2.z)
        let yaw = atan2f(forward.x, forward.z)
        let px = t.columns.3.x
        let py = t.columns.3.y
        let pz = t.columns.3.z
        // Tracking state → quality 0…1
        let q: Float = {
            switch frame.camera.trackingState {
            case .normal: return 1.0
            case .limited: return 0.4
            case .notAvailable: return 0.0
            }
        }()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let raw = Pose(x: px, y: py, z: pz, yaw: yaw)
            self.latestRawPose = raw
            // Convert raw → blocking frame if calibrated. Otherwise the raw pose
            // is used directly (single-device operation).
            let reported: Pose
            if let calibration = PerformerARHost.shared.calibration {
                reported = calibration.toBlocking(raw)
            } else {
                reported = raw
            }
            self.store?.updateLocalPose(reported, quality: q)
            self.sessionController?.broadcastLocalPose()
        }
    }
}
#endif
