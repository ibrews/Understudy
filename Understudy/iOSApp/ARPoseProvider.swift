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

    init(store: BlockingStore, sessionController: SessionController) {
        self.session = ARSession()
        self.store = store
        self.sessionController = sessionController
        super.init()
        session.delegate = self
    }

    func start() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .none
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
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
            let pose = Pose(x: px, y: py, z: pz, yaw: yaw)
            self.store?.updateLocalPose(pose, quality: q)
            self.sessionController?.broadcastLocalPose()
        }
    }
}
#endif
