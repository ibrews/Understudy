//
//  DirectorImmersiveView.swift
//  Understudy (visionOS)
//
//  The "stage." The director stands in the real room with Vision Pro and sees:
//    - tappable floor area where they drop marks,
//    - glowing numbered pucks at each mark,
//    - ghost avatars for every connected performer,
//    - a ribbon between marks showing sequence.
//

#if os(visionOS)
import SwiftUI
import RealityKit

struct DirectorImmersiveView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(CueFXEngine.self) private var fx

    // The root anchor that carries all mark/performer entities.
    @State private var stageRoot = Entity()
    // Mark id -> entity, so we can diff updates without rebuilding the scene.
    @State private var markEntities: [ID: Entity] = [:]
    @State private var performerEntities: [ID: Entity] = [:]
    @State private var sequenceRibbon: Entity = Entity()
    @State private var stageLight: ModelEntity = ModelEntity()
    @State private var ghostEntity: Entity = Entity()
    @State private var lastRenderedFlashID: UUID?

    /// Entities that host a floating SwiftUI script card for each mark.
    /// Parented under the mark entity so they move with the mark.
    @State private var markCardEntities: [ID: Entity] = [:]

    var body: some View {
        RealityView { content, _ in
            // Root — positioned 1m in front of the viewer, slightly below eye.
            stageRoot.position = [0, -1.0, -0.5]
            content.add(stageRoot)
            stageRoot.addChild(sequenceRibbon)

            // A large, invisible tap plane so collaborators can place marks anywhere.
            let plane = ModelEntity(
                mesh: .generatePlane(width: 20, depth: 20),
                materials: [UnlitMaterial(color: .white.withAlphaComponent(0.0001))]
            )
            plane.generateCollisionShapes(recursive: false)
            plane.components.set(InputTargetComponent())
            plane.name = "stageFloor"
            stageRoot.addChild(plane)

            // Stage "light" — on visionOS 1.0 we don't have PointLightComponent
            // (2.0+), so we fake a theatrical wash with a large tinted glowing
            // sphere hanging above the stage. When a .light cue fires we bump
            // its opacity + color, then fade back.
            let light = ModelEntity(
                mesh: .generateSphere(radius: 0.6),
                materials: [UnlitMaterial(color: .white.withAlphaComponent(0.0))]
            )
            light.position = [0, 2.4, 0]
            light.name = "stageLight"
            stageRoot.addChild(light)
            stageLight = light

            // Playback ghost — a translucent magenta sphere. Disabled until needed.
            let ghost = Entity()
            ghost.name = "ghost"
            let body = ModelEntity(
                mesh: .generateSphere(radius: 0.25),
                materials: [UnlitMaterial(color: .magenta.withAlphaComponent(0.55))]
            )
            ghost.addChild(body)
            let halo = ModelEntity(
                mesh: .generateSphere(radius: 0.38),
                materials: [UnlitMaterial(color: .magenta.withAlphaComponent(0.18))]
            )
            ghost.addChild(halo)
            ghost.isEnabled = false
            stageRoot.addChild(ghost)
            ghostEntity = ghost
        } update: { _, attachments in
            Task { @MainActor in
                syncMarks()
                syncPerformers()
                syncRibbon()
                syncGhost()
                syncFlash()
                syncMarkCards(attachments: attachments)
            }
        } attachments: {
            ForEach(store.blocking.marks, id: \.id) { mark in
                Attachment(id: mark.id.raw) {
                    MarkScriptCard(
                        mark: mark,
                        isNext: mark.id == store.nextMark(after: store.localPerformer?.currentMarkID)?.id
                    )
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard value.entity.name == "stageFloor" else { return }
                    // `value.location3D` is in the local coord system of stageRoot's parent scene.
                    // Convert to stageRoot-local.
                    let world = value.convert(value.location3D, from: .local, to: stageRoot)
                    let pose = Pose(x: Float(world.x), y: 0, z: Float(world.z))
                    let idx = store.blocking.marks.count + 1
                    let mark = Mark(
                        name: "Mark \(idx)",
                        pose: pose,
                        radius: 0.6,
                        cues: [],
                        sequenceIndex: idx - 1
                    )
                    store.addMark(mark)
                    session.broadcastMarkAdded(mark)
                }
        )
    }

    // MARK: - Floating script cards

    /// Attach a SwiftUI MarkScriptCard next to each mark. The attachment's
    /// entity is positioned slightly up and to the side of the mark so the
    /// card hovers at readable height without blocking the floor disc.
    private func syncMarkCards(attachments: RealityViewAttachments) {
        let liveIDs = Set(store.blocking.marks.map(\.id))
        // Remove cards for deleted marks.
        for (id, entity) in markCardEntities where !liveIDs.contains(id) {
            entity.removeFromParent()
            markCardEntities.removeValue(forKey: id)
        }
        // Add / update cards.
        for mark in store.blocking.marks {
            guard let attach = attachments.entity(for: mark.id.raw) else { continue }
            // Position: 0.4m up from the floor, 0.6m offset toward +X (stage right).
            // Attachment entity sits in world space of stageRoot.
            attach.position = [mark.pose.x + 0.6, 0.9, mark.pose.z]
            // Billboard — face the viewer. Simple yaw-only face: rotate around Y.
            // Real billboard behavior needs per-frame update via a subscription;
            // for now we pick a fixed yaw so cards face roughly toward stage center.
            let toCenter = SIMD3<Float>(-mark.pose.x - 0.6, 0, -mark.pose.z)
            let yaw = atan2f(toCenter.x, -toCenter.z)
            attach.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            if attach.parent !== stageRoot {
                stageRoot.addChild(attach)
            }
            markCardEntities[mark.id] = attach
        }
    }

    // MARK: - Scene diffing

    private func syncMarks() {
        let current = Set(store.blocking.marks.map(\.id))
        // Remove deleted
        for (id, entity) in markEntities where !current.contains(id) {
            entity.removeFromParent()
            markEntities.removeValue(forKey: id)
        }
        // Add / update
        for mark in store.blocking.marks {
            if let e = markEntities[mark.id] {
                e.position = [mark.pose.x, 0.005, mark.pose.z]
                (e.findEntity(named: "label") as? ModelEntity)?.model?.mesh =
                    .generateText(
                        mark.name + (mark.cues.isEmpty ? "" : " • \(mark.cues.count)"),
                        extrusionDepth: 0.001,
                        font: .systemFont(ofSize: 0.12),
                        alignment: .center
                    )
            } else {
                let e = buildMarkEntity(mark)
                stageRoot.addChild(e)
                markEntities[mark.id] = e
            }
        }
    }

    private func buildMarkEntity(_ mark: Mark) -> Entity {
        if mark.kind == .camera {
            return buildCameraMarkEntity(mark)
        }
        let root = Entity()
        root.name = "mark-\(mark.id.raw)"
        root.position = [mark.pose.x, 0.005, mark.pose.z]

        // Disc
        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: mark.radius),
            materials: [UnlitMaterial(color: .cyan.withAlphaComponent(0.35))]
        )
        disc.name = "disc"
        root.addChild(disc)

        // Rim
        let rim = ModelEntity(
            mesh: .generateCylinder(height: 0.012, radius: mark.radius * 0.98),
            materials: [UnlitMaterial(color: .cyan)]
        )
        rim.scale = [1, 0.1, 1]
        rim.position.y = 0.005
        root.addChild(rim)

        // Floating label
        let label = ModelEntity(
            mesh: .generateText(
                mark.name,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.12),
                alignment: .center
            ),
            materials: [UnlitMaterial(color: .white)]
        )
        label.name = "label"
        label.position = [-0.2, 0.4, 0]
        root.addChild(label)

        return root
    }

    /// Camera mark — tripod + camera body + amber FOV wedge showing what
    /// the lens would frame. Architect-grade pre-viz in mid-air.
    private func buildCameraMarkEntity(_ mark: Mark) -> Entity {
        let root = Entity()
        root.name = "mark-\(mark.id.raw)"
        root.position = [mark.pose.x, 0.005, mark.pose.z]

        let spec = mark.camera ?? CameraSpec()
        let amber = UIColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1.0)

        // Floor disc.
        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.008, radius: 0.22),
            materials: [UnlitMaterial(color: amber.withAlphaComponent(0.5))]
        )
        disc.name = "disc"
        root.addChild(disc)

        // Tripod.
        let tripod = ModelEntity(
            mesh: .generateCylinder(height: spec.heightM, radius: 0.015),
            materials: [UnlitMaterial(color: amber)]
        )
        tripod.position.y = spec.heightM / 2
        root.addChild(tripod)

        // Camera body — a slightly oversized box so it reads from a few meters away.
        let body = ModelEntity(
            mesh: .generateBox(size: [0.22, 0.12, 0.26], cornerRadius: 0.02),
            materials: [UnlitMaterial(color: amber)]
        )
        body.position = [0, spec.heightM + 0.02, 0]
        body.orientation = simd_quatf(angle: spec.tiltRadians, axis: [1, 0, 0])
        root.addChild(body)

        // FOV wedge — three-vertex translucent triangle spreading with HFOV.
        let fovLen: Float = 3.0
        let halfW = tanf(spec.horizontalFOV / 2) * fovLen
        var desc = MeshDescriptor(name: "fovWedge-\(mark.id.raw)")
        desc.positions = MeshBuffers.Positions([
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(halfW, 0, -fovLen),
            SIMD3<Float>(-halfW, 0, -fovLen),
        ])
        desc.primitives = .triangles([0, 1, 2])
        if let mesh = try? MeshResource.generate(from: [desc]) {
            let wedge = ModelEntity(
                mesh: mesh,
                materials: [UnlitMaterial(color: amber.withAlphaComponent(0.18))]
            )
            wedge.position = [0, 0.015, 0]
            root.addChild(wedge)
        }

        // Label: name + mm + HFOV.
        let labelText = "\(mark.name)  \(Int(spec.focalLengthMM))mm · \(Int(Double(spec.horizontalFOV) * 180 / .pi))°"
        let label = ModelEntity(
            mesh: .generateText(
                labelText,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.09),
                alignment: .center
            ),
            materials: [UnlitMaterial(color: .white)]
        )
        label.name = "label"
        label.position = [-0.3, spec.heightM + 0.35, 0]
        root.addChild(label)

        // Rotate the entire rig by the mark's yaw so the FOV wedge points
        // in the correct real-world direction.
        root.orientation = simd_quatf(angle: mark.pose.yaw, axis: [0, 1, 0])

        return root
    }

    private func syncPerformers() {
        guard let me = store.localPerformer else { return }
        let others = store.performers.filter { $0.id != me.id }
        let currentIDs = Set(others.map(\.id))

        for (id, entity) in performerEntities where !currentIDs.contains(id) {
            entity.removeFromParent()
            performerEntities.removeValue(forKey: id)
        }
        for perf in others {
            if let e = performerEntities[perf.id] {
                e.position = [perf.pose.x, 0.9, perf.pose.z]
                // Spin ghost toward performer yaw.
                e.orientation = simd_quatf(angle: perf.pose.yaw, axis: [0, 1, 0])
            } else {
                let e = buildPerformerEntity(perf)
                stageRoot.addChild(e)
                performerEntities[perf.id] = e
            }
        }
    }

    private func buildPerformerEntity(_ perf: Performer) -> Entity {
        let root = Entity()
        root.name = "perf-\(perf.id.raw)"
        root.position = [perf.pose.x, 0.9, perf.pose.z]

        let body = ModelEntity(
            mesh: .generateSphere(radius: 0.25),
            materials: [UnlitMaterial(color: .magenta.withAlphaComponent(0.5))]
        )
        root.addChild(body)

        // Forward-facing cone so the director can read where the performer is facing.
        let nose = ModelEntity(
            mesh: .generateCone(height: 0.3, radius: 0.05),
            materials: [UnlitMaterial(color: .magenta)]
        )
        nose.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        nose.position = [0, 0, -0.25]
        root.addChild(nose)

        let tag = ModelEntity(
            mesh: .generateText(
                perf.displayName,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.08),
                alignment: .center
            ),
            materials: [UnlitMaterial(color: .white)]
        )
        tag.position = [-0.15, 0.4, 0]
        root.addChild(tag)

        return root
    }

    private func syncRibbon() {
        sequenceRibbon.children.removeAll()
        let ordered = store.blocking.marks
            .filter { $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        guard ordered.count >= 2 else { return }
        for i in 0..<(ordered.count - 1) {
            let a = ordered[i].pose
            let b = ordered[i + 1].pose
            let mid = SIMD3<Float>((a.x + b.x) / 2, 0.02, (a.z + b.z) / 2)
            let dx = b.x - a.x
            let dz = b.z - a.z
            let len = max(0.01, sqrtf(dx * dx + dz * dz))
            let seg = ModelEntity(
                mesh: .generateBox(size: [len, 0.01, 0.06]),
                materials: [UnlitMaterial(color: .cyan.withAlphaComponent(0.35))]
            )
            seg.position = mid
            seg.orientation = simd_quatf(angle: atan2f(dz, dx), axis: [0, -1, 0])
            sequenceRibbon.addChild(seg)
        }
    }

    private func syncGhost() {
        guard let t = store.playbackT, let pose = store.ghostPose(at: t) else {
            ghostEntity.isEnabled = false
            return
        }
        ghostEntity.isEnabled = true
        ghostEntity.position = [pose.x, 0.9, pose.z]
        ghostEntity.orientation = simd_quatf(angle: pose.yaw, axis: [0, 1, 0])
    }

    private func syncFlash() {
        guard let flash = fx.currentFlash else {
            if lastRenderedFlashID != nil {
                setStageLight(color: .white, alpha: 0)
                lastRenderedFlashID = nil
            }
            return
        }
        guard flash.cueID != lastRenderedFlashID else { return }
        lastRenderedFlashID = flash.cueID
        let uiColor = UIColorFromSwiftUIColor(flash.color)
        setStageLight(color: uiColor, alpha: CGFloat(flash.alpha))
        Task { @MainActor in
            let steps = 12
            let total = flash.holdDuration + flash.fadeDuration
            let tick = total / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
                let progress = Double(i) / Double(steps)
                let remaining = max(0, 1 - progress)
                setStageLight(color: uiColor, alpha: CGFloat(flash.alpha * remaining))
            }
        }
    }

    private func setStageLight(color: UIColor, alpha: CGFloat) {
        var m = UnlitMaterial()
        let a = min(0.55, max(0, alpha))
        m.color = .init(tint: color.withAlphaComponent(a))
        m.blending = .transparent(opacity: .init(floatLiteral: Float(a)))
        stageLight.model?.materials = [m]
    }
}

/// Convert a SwiftUI Color to a UIColor for RealityKit materials/lights.
@MainActor
fileprivate func UIColorFromSwiftUIColor(_ c: Color) -> UIColor {
    #if canImport(UIKit)
    return UIColor(c)
    #else
    return .white
    #endif
}

// Color helpers that compile on all platforms (UIKit on vision/iOS).
#if canImport(UIKit)
import UIKit
fileprivate extension UnlitMaterial {
    init(color: UIColor) {
        self.init()
        self.color = .init(tint: color)
    }
}
#endif
#endif
