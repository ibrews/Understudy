//
//  DirectorImmersiveView.swift
//  Understudy (visionOS)
//
//  The "stage." The director stands in the real room with Vision Pro and sees:
//    - tappable floor area where they drop marks (or props in prop-placement mode),
//    - glowing numbered pucks at each mark,
//    - ghost avatars for every connected performer,
//    - a ribbon between marks showing sequence,
//    - a 9-zone stage grid overlay (toggleable),
//    - set-construction prop objects (cubes/spheres/cylinders).
//
//  Tabletop mode scales the entire stage container to ~12% so the director
//  can inspect the whole layout from above without walking the floor.
//

#if os(visionOS)
import SwiftUI
import RealityKit

struct DirectorImmersiveView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(CueFXEngine.self) private var fx

    /// Outer scalable wrapper — scales down in tabletop mode.
    @State private var stageContainer = Entity()
    /// Inner root that all stage content hangs off.
    @State private var stageRoot = Entity()
    @State private var markEntities: [ID: Entity] = [:]
    @State private var performerEntities: [ID: Entity] = [:]
    @State private var sequenceRibbon: Entity = Entity()
    @State private var stageLight: ModelEntity = ModelEntity()
    @State private var ghostEntity: Entity = Entity()
    @State private var lastRenderedFlashID: UUID?
    @State private var roomScanEntity: ModelEntity?
    @State private var renderedScanHash: Int?
    @State private var roomScanBounds: SIMD3<Float> = .zero
    @State private var scanDragStartOffset: Pose?
    @State private var markCardEntities: [ID: Entity] = [:]

    // Stage grid (9 zones).
    @State private var zoneEntities: [StageArea: Entity] = [:]

    // Prop objects (set-construction placeholders).
    @State private var propEntities: [ID: Entity] = [:]

    // Scan rotation gesture state.
    @State private var scanRotateStartYaw: Float?

    var body: some View {
        RealityView { content, _ in
            // stageContainer wraps stageRoot so we can scale the whole stage
            // in tabletop mode without disturbing individual entity positions.
            content.add(stageContainer)
            stageContainer.addChild(stageRoot)

            stageRoot.position = [0, -1.0, -0.5]
            stageRoot.addChild(sequenceRibbon)

            let plane = ModelEntity(
                mesh: .generatePlane(width: 20, depth: 20),
                materials: [UnlitMaterial(color: .white.withAlphaComponent(0.0001))]
            )
            plane.generateCollisionShapes(recursive: false)
            plane.components.set(InputTargetComponent())
            plane.name = "stageFloor"
            stageRoot.addChild(plane)

            let light = ModelEntity(
                mesh: .generateSphere(radius: 0.6),
                materials: [UnlitMaterial(color: .white.withAlphaComponent(0.0))]
            )
            light.position = [0, 2.4, 0]
            light.name = "stageLight"
            stageRoot.addChild(light)
            stageLight = light

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
                syncTabletop()
                syncStageGrid()
                syncMarks()
                syncProps()
                syncPerformers()
                syncRibbon()
                syncGhost()
                syncFlash()
                syncMarkCards(attachments: attachments)
                syncRoomScan()
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
                    // Disable tap placement while inspecting in tabletop mode.
                    guard !store.isTabletopMode else { return }
                    guard value.entity.name == "stageFloor" else { return }
                    let world = value.convert(value.location3D, from: .local, to: stageRoot)
                    var pose = Pose(x: Float(world.x), y: 0, z: Float(world.z))

                    if store.isPropPlacementMode {
                        let idx = store.blocking.props.count + 1
                        let prop = PropObject(
                            name: "Prop \(idx)",
                            pose: pose,
                            shape: store.selectedPropShape
                        )
                        store.addProp(prop)
                    } else {
                        pose = store.snappedToGrid(pose)
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
                }
        )
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .simultaneously(with: RotateGesture3D(constrainedToAxis: .y).targetedToAnyEntity())
                .onChanged { value in
                    let drag = value.first
                    let rotate = value.second
                    guard (drag?.entity.name == "roomScan" || rotate?.entity.name == "roomScan"),
                          !store.scanAlignmentLocked,
                          let entity = roomScanEntity else { return }

                    let baseOffset = store.blocking.roomScan?.overlayOffset ?? Pose()

                    // Translation
                    if let drag, drag.entity.name == "roomScan" {
                        if scanDragStartOffset == nil { scanDragStartOffset = baseOffset }
                        guard let start = scanDragStartOffset else { return }
                        let t = drag.convert(drag.translation3D, from: .local, to: stageRoot)
                        var updated = Pose(x: start.x + Float(t.x), y: start.y,
                                          z: start.z + Float(t.z), yaw: start.yaw)
                        // Merge rotation if happening simultaneously
                        if let r = rotate {
                            if scanRotateStartYaw == nil { scanRotateStartYaw = baseOffset.yaw }
                            let delta = Float(r.rotation.eulerAngles(order: .xyz).angles.y)
                            updated.yaw = (scanRotateStartYaw ?? start.yaw) + delta
                        }
                        applyScanOffset(entity, offset: updated)
                    } else if let rotate {
                        if scanRotateStartYaw == nil { scanRotateStartYaw = baseOffset.yaw }
                        let delta = Float(rotate.rotation.eulerAngles(order: .xyz).angles.y)
                        var updated = baseOffset
                        updated.yaw = (scanRotateStartYaw ?? baseOffset.yaw) + delta
                        applyScanOffset(entity, offset: updated)
                    }
                }
                .onEnded { value in
                    let drag = value.first
                    let rotate = value.second
                    guard !store.scanAlignmentLocked,
                          drag?.entity.name == "roomScan" || rotate?.entity.name == "roomScan" else {
                        scanDragStartOffset = nil; scanRotateStartYaw = nil; return
                    }
                    let baseOffset = store.blocking.roomScan?.overlayOffset ?? Pose()
                    var committed = scanDragStartOffset ?? baseOffset
                    if let drag, drag.entity.name == "roomScan" {
                        let t = drag.convert(drag.translation3D, from: .local, to: stageRoot)
                        committed.x += Float(t.x); committed.z += Float(t.z)
                    }
                    if let rotate {
                        let delta = Float(rotate.rotation.eulerAngles(order: .xyz).angles.y)
                        committed.yaw = (scanRotateStartYaw ?? committed.yaw) + delta
                    }
                    commitScanOffset(committed)
                    scanDragStartOffset = nil; scanRotateStartYaw = nil
                }
        )
    }

    // MARK: - Tabletop mode

    private func syncTabletop() {
        if store.isTabletopMode {
            stageContainer.scale = [0.12, 0.12, 0.12]
            // Position the miniature stage in front of the viewer at table height.
            stageContainer.position = [0, -0.5, -0.8]
        } else {
            stageContainer.scale = [1, 1, 1]
            stageContainer.position = .zero
        }
    }

    // MARK: - Stage grid overlay

    private func syncStageGrid() {
        if store.showStageGrid {
            if zoneEntities.isEmpty { buildZoneEntities() }
            zoneEntities.values.forEach { $0.isEnabled = true }
        } else {
            zoneEntities.values.forEach { $0.isEnabled = false }
        }
    }

    private func buildZoneEntities() {
        let halfW: Float = 2.5
        let halfD: Float = 3.5
        let cellW = halfW * 2 / 3   // ≈ 1.67 m
        let cellD = halfD * 2 / 3   // ≈ 2.33 m
        let gap: Float = 0.04

        let zoneColors: [StageArea: UIColor] = [
            .downstageLeft:   UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.14),
            .downstageCenter: UIColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 0.14),
            .downstageRight:  UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.14),
            .centerLeft:      UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 0.14),
            .centerStage:     UIColor(red: 0.95, green: 0.9, blue: 0.3, alpha: 0.18),
            .centerRight:     UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 0.14),
            .upstageLeft:     UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 0.14),
            .upstageCenter:   UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.14),
            .upstageRight:    UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 0.14),
        ]

        for area in StageArea.allCases {
            let center = area.worldCenter(halfWidth: halfW, halfDepth: halfD)
            let color = zoneColors[area] ?? UIColor(white: 0.5, alpha: 0.1)

            let root = Entity()
            root.position = [center.x, 0.003, center.z]
            root.name = "zone-\(area.rawValue)"

            let tile = ModelEntity(
                mesh: .generatePlane(width: cellW - gap, depth: cellD - gap),
                materials: [UnlitMaterial(color: color)]
            )
            root.addChild(tile)

            let label = ModelEntity(
                mesh: .generateText(
                    area.rawValue,
                    extrusionDepth: 0.001,
                    font: .systemFont(ofSize: 0.13),
                    alignment: .center
                ),
                materials: [UnlitMaterial(color: UIColor.white.withAlphaComponent(0.45))]
            )
            label.position = [-0.12, 0.002, 0]
            root.addChild(label)

            stageRoot.addChild(root)
            zoneEntities[area] = root
        }
    }

    // MARK: - Props

    private func syncProps() {
        let current = Set(store.blocking.props.map(\.id))
        for (id, entity) in propEntities where !current.contains(id) {
            entity.removeFromParent()
            propEntities.removeValue(forKey: id)
        }
        for prop in store.blocking.props {
            if let e = propEntities[prop.id] {
                e.position = [prop.pose.x, prop.height / 2, prop.pose.z]
            } else {
                let e = buildPropEntity(prop)
                stageRoot.addChild(e)
                propEntities[prop.id] = e
            }
        }
    }

    private func buildPropEntity(_ prop: PropObject) -> Entity {
        let root = Entity()
        root.name = "prop-\(prop.id.raw)"
        root.position = [prop.pose.x, prop.height / 2, prop.pose.z]

        let color = UIColor(red: CGFloat(prop.r), green: CGFloat(prop.g),
                            blue: CGFloat(prop.b), alpha: 0.82)
        let mat = UnlitMaterial(color: color)

        let body: ModelEntity
        switch prop.shape {
        case .cube:
            body = ModelEntity(
                mesh: .generateBox(size: [prop.width, prop.height, prop.depth], cornerRadius: 0.025),
                materials: [mat]
            )
        case .sphere:
            body = ModelEntity(mesh: .generateSphere(radius: prop.width / 2), materials: [mat])
        case .cylinder:
            body = ModelEntity(
                mesh: .generateCylinder(height: prop.height, radius: prop.width / 2),
                materials: [mat]
            )
        }
        body.name = "propBody"
        root.addChild(body)

        let label = ModelEntity(
            mesh: .generateText(prop.name, extrusionDepth: 0.001,
                                font: .systemFont(ofSize: 0.08), alignment: .center),
            materials: [UnlitMaterial(color: .white)]
        )
        label.position = [-0.15, prop.height / 2 + 0.15, 0]
        root.addChild(label)

        return root
    }

    // MARK: - Room scan ghost

    private func syncRoomScan() {
        guard let scan = store.blocking.roomScan else {
            roomScanEntity?.removeFromParent()
            roomScanEntity = nil
            renderedScanHash = nil
            return
        }

        let hash = scan.vertexCount &+ scan.triangleCount &* 31 &+ scan.name.hashValue
        if let entity = roomScanEntity, hash == renderedScanHash {
            applyScanOffset(entity, offset: scan.overlayOffset)
            return
        }

        guard let mesh = RoomScanMesh.make(from: scan) else { return }
        roomScanEntity?.removeFromParent()
        let entity = ModelEntity(mesh: mesh, materials: [RoomScanMesh.ghostMaterial()])
        entity.name = "roomScan"

        let positions = scan.decodePositions()
        var lo = SIMD3<Float>(.infinity, .infinity, .infinity)
        var hi = SIMD3<Float>(-.infinity, -.infinity, -.infinity)
        for i in stride(from: 0, to: positions.count, by: 3) {
            let p = SIMD3<Float>(positions[i], positions[i + 1], positions[i + 2])
            lo = min(lo, p); hi = max(hi, p)
        }
        if lo.x.isFinite && hi.x.isFinite {
            let size = max(hi - lo, SIMD3<Float>(0.2, 0.2, 0.2))
            let center = (hi + lo) * 0.5
            entity.components.set(CollisionComponent(
                shapes: [ShapeResource.generateBox(size: size).offsetBy(translation: center)]
            ))
            entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
            roomScanBounds = size
        }

        stageRoot.addChild(entity)
        applyScanOffset(entity, offset: scan.overlayOffset)
        roomScanEntity = entity
        renderedScanHash = hash
    }

    // MARK: - Scan alignment

    private func commitScanOffset(_ offset: Pose) {
        guard var scan = store.blocking.roomScan else { return }
        scan.overlayOffset = offset
        store.blocking.roomScan = scan
        store.blocking.modifiedAt = Date()
        BlockingAutosave.save(store.blocking)
        session.broadcastScanOverlay(offset)
    }

    private func applyScanOffset(_ entity: Entity, offset: Pose) {
        entity.position = [offset.x, offset.y, offset.z]
        entity.orientation = simd_quatf(angle: offset.yaw, axis: [0, 1, 0])
    }

    // MARK: - Floating script cards

    private func syncMarkCards(attachments: RealityViewAttachments) {
        let liveIDs = Set(store.blocking.marks.map(\.id))
        for (id, entity) in markCardEntities where !liveIDs.contains(id) {
            entity.removeFromParent()
            markCardEntities.removeValue(forKey: id)
        }
        for mark in store.blocking.marks {
            guard let attach = attachments.entity(for: mark.id.raw) else { continue }
            attach.position = [mark.pose.x + 0.6, 0.9, mark.pose.z]
            let toCenter = SIMD3<Float>(-mark.pose.x - 0.6, 0, -mark.pose.z)
            let yaw = atan2f(toCenter.x, -toCenter.z)
            attach.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            if attach.parent !== stageRoot { stageRoot.addChild(attach) }
            markCardEntities[mark.id] = attach
        }
    }

    // MARK: - Scene diffing

    private func syncMarks() {
        let current = Set(store.blocking.marks.map(\.id))
        for (id, entity) in markEntities where !current.contains(id) {
            entity.removeFromParent()
            markEntities.removeValue(forKey: id)
        }
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
        if mark.kind == .camera { return buildCameraMarkEntity(mark) }
        let root = Entity()
        root.name = "mark-\(mark.id.raw)"
        root.position = [mark.pose.x, 0.005, mark.pose.z]

        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: mark.radius),
            materials: [UnlitMaterial(color: .cyan.withAlphaComponent(0.35))]
        )
        disc.name = "disc"
        root.addChild(disc)

        let rim = ModelEntity(
            mesh: .generateCylinder(height: 0.012, radius: mark.radius * 0.98),
            materials: [UnlitMaterial(color: .cyan)]
        )
        rim.scale = [1, 0.1, 1]
        rim.position.y = 0.005
        root.addChild(rim)

        let label = ModelEntity(
            mesh: .generateText(mark.name, extrusionDepth: 0.001,
                                font: .systemFont(ofSize: 0.12), alignment: .center),
            materials: [UnlitMaterial(color: .white)]
        )
        label.name = "label"
        label.position = [-0.2, 0.4, 0]
        root.addChild(label)

        return root
    }

    private func buildCameraMarkEntity(_ mark: Mark) -> Entity {
        let root = Entity()
        root.name = "mark-\(mark.id.raw)"
        root.position = [mark.pose.x, 0.005, mark.pose.z]

        let spec = mark.camera ?? CameraSpec()
        let amber = UIColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1.0)

        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.008, radius: 0.22),
            materials: [UnlitMaterial(color: amber.withAlphaComponent(0.5))]
        )
        disc.name = "disc"
        root.addChild(disc)

        let tripod = ModelEntity(
            mesh: .generateCylinder(height: spec.heightM, radius: 0.015),
            materials: [UnlitMaterial(color: amber)]
        )
        tripod.position.y = spec.heightM / 2
        root.addChild(tripod)

        let body = ModelEntity(
            mesh: .generateBox(size: [0.22, 0.12, 0.26], cornerRadius: 0.02),
            materials: [UnlitMaterial(color: amber)]
        )
        body.position = [0, spec.heightM + 0.02, 0]
        body.orientation = simd_quatf(angle: spec.tiltRadians, axis: [1, 0, 0])
        root.addChild(body)

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

        let labelText = "\(mark.name)  \(Int(spec.focalLengthMM))mm · \(Int(Double(spec.horizontalFOV) * 180 / .pi))°"
        let label = ModelEntity(
            mesh: .generateText(labelText, extrusionDepth: 0.001,
                                font: .systemFont(ofSize: 0.09), alignment: .center),
            materials: [UnlitMaterial(color: .white)]
        )
        label.name = "label"
        label.position = [-0.3, spec.heightM + 0.35, 0]
        root.addChild(label)

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

        let nose = ModelEntity(
            mesh: .generateCone(height: 0.3, radius: 0.05),
            materials: [UnlitMaterial(color: .magenta)]
        )
        nose.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        nose.position = [0, 0, -0.25]
        root.addChild(nose)

        let tag = ModelEntity(
            mesh: .generateText(perf.displayName, extrusionDepth: 0.001,
                                font: .systemFont(ofSize: 0.08), alignment: .center),
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

@MainActor
fileprivate func UIColorFromSwiftUIColor(_ c: Color) -> UIColor {
    #if canImport(UIKit)
    return UIColor(c)
    #else
    return .white
    #endif
}

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
