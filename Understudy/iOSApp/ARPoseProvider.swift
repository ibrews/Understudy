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
    /// When image-based calibration is desired, we detect a Vision request
    /// every ~1 s rather than re-detecting per frame — the QR doesn't move
    /// and per-frame is wasteful. Timestamp-gated.
    private var lastImageScanAt: Date = .distantPast
    /// Detected QR calibrations are written to PerformerARHost.shared
    /// directly (same place the compass button writes). This closure lets
    /// the host know when we've updated.
    var onDetectedCalibration: ((DeviceCalibration, String) -> Void)?

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

    // MARK: - Image-detected calibration

    /// ARKit calls this when a registered reference image is detected.
    /// We keep a single "understudy" reference image; when it's seen, we
    /// derive a DeviceCalibration from its world transform and push it
    /// into PerformerARHost. Performers don't need to tap the compass.
    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let ia = anchor as? ARImageAnchor,
                  let payload = ia.referenceImage.name,
                  let (room, _) = QRCalibration.parse(payload) else { continue }
            let transform = ia.transform
            Task { @MainActor [weak self] in
                let calibration = QRCalibration.calibration(from: transform)
                PerformerARHost.shared.calibration = calibration
                self?.onDetectedCalibration?(calibration, room)
            }
        }
    }

    /// As the image moves / we re-detect (e.g. after tracking loss), we
    /// keep the calibration current. Cheap — it's one struct assignment.
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let ia = anchor as? ARImageAnchor,
                  let payload = ia.referenceImage.name,
                  let _ = QRCalibration.parse(payload),
                  ia.isTracked else { continue }
            let transform = ia.transform
            Task { @MainActor in
                PerformerARHost.shared.calibration = QRCalibration.calibration(from: transform)
            }
        }
    }
}
#endif
