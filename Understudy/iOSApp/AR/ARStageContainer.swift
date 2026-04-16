//
//  ARStageContainer.swift
//  Understudy (iOS)
//
//  SwiftUI wrapper around RealityKit's iOS ARView. Shows the rear camera
//  feed as a live background and decorates the room with:
//    • a glowing disc at every Mark (world-anchored, follows marks as they move)
//    • a subtle trail between sequential marks
//    • a brighter pulse on the *next* mark
//    • a translucent ghost orb when playbackT is active
//
//  The ARSession is created here and shared with ARPoseProvider so we don't
//  run two concurrent world-tracking sessions on the device.
//

#if os(iOS)
import SwiftUI
import ARKit
import RealityKit
import Combine
import simd

/// SwiftUI container. Observes the store and updates the RealityKit scene
/// in `updateUIView`. Place this *behind* the teleprompter UI — it fills
/// the screen but doesn't intercept taps (we turn gestures off in the ARView).
struct ARStageContainer: UIViewRepresentable {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    /// Called back with the ARSession once the view is built, so the host can
    /// create an ARPoseProvider that shares the same session.
    var onSessionReady: (ARSession) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(
            frame: .zero,
            cameraMode: .ar,
            automaticallyConfigureSession: false
        )
        arView.renderOptions.insert(.disablePersonOcclusion)
        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.environment.background = .cameraFeed()

        // Kill all gesture recognizers installed by ARView so touches pass
        // through to the SwiftUI teleprompter below.
        for gr in arView.gestureRecognizers ?? [] {
            arView.removeGestureRecognizer(gr)
        }
        arView.isUserInteractionEnabled = false

        // Start world tracking. The callback hands the session to the host so
        // ARPoseProvider can attach.
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .none
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        // World anchor — everything we add hangs off here at origin.
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
        arView.scene.addAnchor(anchor)
        context.coordinator.worldAnchor = anchor
        context.coordinator.arView = arView

        // Ghost orb (hidden until playbackT set).
        let ghost = Self.makeGhostEntity()
        anchor.addChild(ghost)
        ghost.isEnabled = false
        context.coordinator.ghost = ghost

        // Start a pulse ticker driven by RealityKit's scene events — we
        // repaint the "next mark" and any in-flight flash every frame.
        context.coordinator.updateSubscription = arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) { [weak coordinator = context.coordinator] event in
            coordinator?.advance(elapsed: event.deltaTime)
        }

        // Stash the ARView so Author mode can raycast tap points to world coords.
        PerformerARHost.shared.arView = arView

        onSessionReady(arView.session)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.sync(
            marks: store.blocking.marks,
            nextMarkID: store.nextMark(after: store.localPerformer?.currentMarkID)?.id,
            ghostPose: store.playbackT.flatMap { store.ghostPose(at: $0) }
        )
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.updateSubscription?.cancel()
        uiView.session.pause()
    }

    // MARK: - Scene building

    fileprivate static func makeGhostEntity() -> Entity {
        let root = Entity()
        root.name = "ghostOrb"
        let mesh = MeshResource.generateSphere(radius: 0.18)
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor.magenta.withAlphaComponent(0.55))
        mat.blending = .transparent(opacity: .init(floatLiteral: 0.55))
        let body = ModelEntity(mesh: mesh, materials: [mat])
        root.addChild(body)
        let halo = ModelEntity(
            mesh: .generateSphere(radius: 0.28),
            materials: [makeEmissiveMaterial(UIColor(red: 1.0, green: 0.35, blue: 1.0, alpha: 1.0),
                                              alpha: 0.18)]
        )
        root.addChild(halo)
        return root
    }

    fileprivate static func makeEmissiveMaterial(_ color: UIColor, alpha: CGFloat) -> RealityKit.Material {
        var m = UnlitMaterial()
        m.color = .init(tint: color.withAlphaComponent(alpha))
        m.blending = .transparent(opacity: .init(floatLiteral: Float(alpha)))
        return m
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {
        weak var arView: ARView?
        var worldAnchor: Entity?
        var ghost: Entity?
        var updateSubscription: Cancellable?

        /// Entities per mark id so we can diff-update rather than rebuilding.
        private var markEntities: [ID: MarkEntityBundle] = [:]
        /// Trail segments, keyed by "a->b" id pair.
        private var trailEntities: [String: Entity] = [:]
        /// The mark id that the UI considers "next."
        private var nextMarkID: ID?
        /// Time since view creation, used for the pulse.
        private var elapsed: Double = 0

        struct MarkEntityBundle {
            let root: Entity
            let disc: ModelEntity
            let ring: ModelEntity
            let radius: Float
        }

        func sync(marks: [Mark], nextMarkID: ID?, ghostPose: Pose?) {
            self.nextMarkID = nextMarkID
            guard let anchor = worldAnchor else { return }

            // Marks live in the shared blocking frame. To render them in the
            // device's own ARKit scene, convert back to raw via the active
            // calibration (or pass through if uncalibrated — the raw frame
            // IS the blocking frame in single-device mode).
            let calibration = PerformerARHost.shared.calibration

            func rawPosition(_ p: Pose, y: Float) -> SIMD3<Float> {
                let raw = calibration?.toRaw(p) ?? p
                return [raw.x, y, raw.z]
            }

            // Diff marks.
            let liveIDs = Set(marks.map(\.id))
            for (id, bundle) in markEntities where !liveIDs.contains(id) {
                bundle.root.removeFromParent()
                markEntities.removeValue(forKey: id)
            }
            for mark in marks {
                let pos = rawPosition(mark.pose, y: 0.005)
                if let existing = markEntities[mark.id] {
                    existing.root.position = pos
                    // Radius change → rebuild bundle.
                    if abs(existing.radius - mark.radius) > 0.001 {
                        existing.root.removeFromParent()
                        let bundle = buildMarkBundle(mark, atPosition: pos)
                        anchor.addChild(bundle.root)
                        markEntities[mark.id] = bundle
                    }
                } else {
                    let bundle = buildMarkBundle(mark, atPosition: pos)
                    anchor.addChild(bundle.root)
                    markEntities[mark.id] = bundle
                }
            }

            // Rebuild trail whenever the sequence changes. This is cheap at
            // the scales we care about (<50 marks).
            rebuildTrail(marks: marks, anchor: anchor, calibration: calibration)

            // Ghost orb.
            if let ghost, let pose = ghostPose {
                ghost.isEnabled = true
                ghost.position = rawPosition(pose, y: 0.9)
                let rawYaw = (calibration?.toRaw(pose).yaw ?? pose.yaw)
                ghost.orientation = simd_quatf(angle: rawYaw, axis: [0, 1, 0])
            } else {
                ghost?.isEnabled = false
            }
        }

        func advance(elapsed dt: Double) {
            self.elapsed += dt
            // Pulse the "next" mark — sine wave in 0.4…1.0.
            let pulse = 0.7 + 0.3 * sin(self.elapsed * 3.0)
            for (id, bundle) in markEntities {
                let isNext = (id == nextMarkID)
                let alpha: CGFloat = isNext ? CGFloat(pulse) : 0.35
                var discMat = UnlitMaterial()
                let base = isNext
                    ? UIColor(red: 1.0, green: 0.35, blue: 0.45, alpha: 1.0)
                    : UIColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 1.0)
                discMat.color = .init(tint: base.withAlphaComponent(alpha))
                discMat.blending = .transparent(opacity: .init(floatLiteral: Float(alpha)))
                bundle.disc.model?.materials = [discMat]

                let ringAlpha: CGFloat = isNext ? 1.0 : 0.55
                var ringMat = UnlitMaterial()
                ringMat.color = .init(tint: base.withAlphaComponent(ringAlpha))
                ringMat.blending = .transparent(opacity: .init(floatLiteral: Float(ringAlpha)))
                bundle.ring.model?.materials = [ringMat]
            }
        }

        // MARK: - Building

        private func buildMarkBundle(_ mark: Mark, atPosition pos: SIMD3<Float>) -> MarkEntityBundle {
            if mark.kind == .camera {
                return buildCameraMarkBundle(mark, atPosition: pos)
            }
            let root = Entity()
            root.name = "mark-\(mark.id.raw)"
            root.position = pos

            // iOS 17 doesn't have `generateCylinder`. Use a flat thin plane as
            // the disc and a slightly larger one underneath for a subtle rim.
            let d = mark.radius * 2
            let disc = ModelEntity(
                mesh: .generatePlane(width: d, depth: d, cornerRadius: mark.radius),
                materials: [defaultDiscMaterial()]
            )
            disc.position.y = 0.003
            root.addChild(disc)

            let ring = ModelEntity(
                mesh: .generatePlane(width: d * 1.02, depth: d * 1.02,
                                     cornerRadius: mark.radius * 1.02),
                materials: [defaultRingMaterial()]
            )
            ring.position.y = 0.001
            root.addChild(ring)

            return MarkEntityBundle(root: root, disc: disc, ring: ring, radius: mark.radius)
        }

        /// Camera marks render as:
        ///   - a small tripod-height "camera body" (flat rounded rectangle) at `heightM`
        ///   - a translucent wedge in front showing the horizontal FOV, drawn
        ///     as a thin plane that spreads with lens width
        /// The floor disc still lives under it so the mark is pickable /
        /// walkable. We reuse the bundle shape (disc+ring) for that.
        private func buildCameraMarkBundle(_ mark: Mark, atPosition pos: SIMD3<Float>) -> MarkEntityBundle {
            let root = Entity()
            root.name = "mark-\(mark.id.raw)"
            root.position = pos

            let spec = mark.camera ?? CameraSpec()
            let floorRadius = max(0.25, mark.radius * 0.6)

            // Small amber disc to mark the tripod point.
            var floorMat = UnlitMaterial()
            let floorColor = UIColor(red: 1.0, green: 0.75, blue: 0.25, alpha: 0.55)
            floorMat.color = .init(tint: floorColor)
            floorMat.blending = .transparent(opacity: .init(floatLiteral: 0.55))
            let disc = ModelEntity(
                mesh: .generatePlane(width: floorRadius * 2,
                                     depth: floorRadius * 2,
                                     cornerRadius: floorRadius),
                materials: [floorMat]
            )
            disc.position.y = 0.003
            root.addChild(disc)

            // "Ring" marker — we reuse the field for the FOV wedge so the
            // bundle.ring pulsing animation in `advance(elapsed:)` still has
            // a target, without painting a second disc.
            let ring = ModelEntity(
                mesh: .generatePlane(width: 0.12, depth: 0.12, cornerRadius: 0.06),
                materials: [floorMat]
            )
            ring.position = [0, 0.006, 0]
            root.addChild(ring)

            // Camera body — a small box at `heightM` pointing along -Z (yaw=0
            // convention). Yaw of the mark rotates the whole root below.
            var bodyMat = UnlitMaterial()
            bodyMat.color = .init(tint: UIColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 1.0))
            let body = ModelEntity(
                mesh: .generateBox(size: [0.18, 0.1, 0.22], cornerRadius: 0.02),
                materials: [bodyMat]
            )
            body.position = [0, spec.heightM, 0]
            // Tilt about X.
            body.orientation = simd_quatf(angle: spec.tiltRadians, axis: [1, 0, 0])
            root.addChild(body)

            // Tripod — thin vertical bar from disc up to the body.
            let tripod = ModelEntity(
                mesh: .generateBox(size: [0.02, spec.heightM, 0.02]),
                materials: [bodyMat]
            )
            tripod.position = [0, spec.heightM / 2, 0]
            root.addChild(tripod)

            // Field-of-view wedge — a flat quadrilateral on the ground plane
            // in front of the camera, widening with horizontal FOV. Length
            // 3 m so it's visible across a small room.
            let fovLen: Float = 3.0
            let halfW = tanf(spec.horizontalFOV / 2) * fovLen
            let wedgeMesh: MeshResource = {
                var d = MeshDescriptor(name: "fovWedge")
                d.positions = MeshBuffers.Positions([
                    SIMD3<Float>(0, 0, 0),
                    SIMD3<Float>(halfW, 0, -fovLen),
                    SIMD3<Float>(-halfW, 0, -fovLen),
                ])
                d.primitives = .triangles([0, 1, 2])
                return (try? MeshResource.generate(from: [d]))
                    ?? .generatePlane(width: 0.01, depth: 0.01)
            }()
            var wedgeMat = UnlitMaterial()
            let wedgeColor = UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.22)
            wedgeMat.color = .init(tint: wedgeColor)
            wedgeMat.blending = .transparent(opacity: .init(floatLiteral: 0.22))
            let wedge = ModelEntity(mesh: wedgeMesh, materials: [wedgeMat])
            wedge.position.y = 0.008
            root.addChild(wedge)

            // Yaw the entire rig — the +Z-forward convention for marks means
            // yaw=0 faces -Z (like ARKit's camera forward).
            root.orientation = simd_quatf(angle: mark.pose.yaw, axis: [0, 1, 0])

            return MarkEntityBundle(root: root, disc: disc, ring: ring, radius: mark.radius)
        }

        private func defaultDiscMaterial() -> RealityKit.Material {
            var m = UnlitMaterial()
            let c = UIColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 0.35)
            m.color = .init(tint: c)
            m.blending = .transparent(opacity: .init(floatLiteral: 0.35))
            return m
        }

        private func defaultRingMaterial() -> RealityKit.Material {
            var m = UnlitMaterial()
            let c = UIColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 0.8)
            m.color = .init(tint: c)
            m.blending = .transparent(opacity: .init(floatLiteral: 0.8))
            return m
        }

        private func rebuildTrail(marks: [Mark], anchor: Entity, calibration: DeviceCalibration?) {
            for (_, entity) in trailEntities { entity.removeFromParent() }
            trailEntities.removeAll()
            let ordered = marks
                .filter { $0.sequenceIndex >= 0 }
                .sorted { $0.sequenceIndex < $1.sequenceIndex }
            guard ordered.count >= 2 else { return }
            for i in 0..<(ordered.count - 1) {
                // Transform both endpoints through calibration so segments
                // align with the floor-anchored discs they connect.
                let a = calibration?.toRaw(ordered[i].pose) ?? ordered[i].pose
                let b = calibration?.toRaw(ordered[i + 1].pose) ?? ordered[i + 1].pose
                let dx = b.x - a.x
                let dz = b.z - a.z
                let len = max(0.01, sqrtf(dx * dx + dz * dz))
                let mid = SIMD3<Float>((a.x + b.x) / 2, 0.01, (a.z + b.z) / 2)
                var mat = UnlitMaterial()
                let color = UIColor(red: 0.4, green: 0.85, blue: 1.0, alpha: 0.4)
                mat.color = .init(tint: color)
                mat.blending = .transparent(opacity: .init(floatLiteral: 0.35))
                let seg = ModelEntity(
                    mesh: .generateBox(size: [len, 0.005, 0.05]),
                    materials: [mat]
                )
                seg.position = mid
                seg.orientation = simd_quatf(angle: atan2f(dz, dx), axis: [0, -1, 0])
                anchor.addChild(seg)
                trailEntities["\(ordered[i].id.raw)->\(ordered[i + 1].id.raw)"] = seg
            }
        }
    }
}
#endif
