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

    var body: some View {
        RealityView { content in
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
        } update: { _ in
            Task { @MainActor in
                syncMarks()
                syncPerformers()
                syncRibbon()
                syncGhost()
                syncFlash()
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
