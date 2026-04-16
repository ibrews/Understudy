//
//  MeshCapture.swift
//  Understudy (iOS)
//
//  Consumes ARKit's ARSceneReconstruction ("scene mesh") anchors on a
//  LiDAR-capable iPhone and turns the current accumulated mesh into a
//  `RoomScan` — base64-encoded binary vertex + index arrays ready for
//  the wire.
//
//  Scanning is OPT-IN. The user presses "Scan Room" in Author mode; the
//  capture class enables `ARWorldTrackingConfiguration.sceneReconstruction =
//  .mesh` on the shared ARSession (if the device supports it) and polls
//  `currentFrame.anchors` each second, accumulating geometry. On "Finish
//  Scan", the accumulated anchors are flattened into a single mesh and
//  handed back as a RoomScan.
//
//  Device support: iPhone 12 Pro / Pro Max / 13 Pro / 14 Pro / 15 Pro,
//  and iPad Pro with LiDAR. On non-LiDAR devices, `isSupported` returns
//  false and the scan UI should be hidden.
//

#if os(iOS)
import ARKit
import simd

@MainActor
final class MeshCapture {
    /// Whether this device supports scene-reconstruction meshes at all.
    public static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    public enum State: Equatable { case idle, scanning, done }

    public private(set) var state: State = .idle
    /// Reported during scanning — triangle count seen so far (across all
    /// anchors, may double-count shared vertices until we flatten at finish).
    public private(set) var triangleCountSoFar: Int = 0
    /// Wall-clock when scanning started.
    public private(set) var startedAt: Date?

    /// The ARSession this capture class rides on. Owned by PerformerARHost
    /// so we don't race two world-tracking configs.
    private weak var session: ARSession?

    public init(session: ARSession) {
        self.session = session
    }

    /// Turn scene mesh reconstruction ON (if supported). Returns false if
    /// the device has no LiDAR.
    public func start() -> Bool {
        guard Self.isSupported, let session else { return false }
        let config = (session.configuration as? ARWorldTrackingConfiguration)
            ?? ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .none
        session.run(config) // no reset — keep existing world frame
        state = .scanning
        startedAt = Date()
        triangleCountSoFar = 0
        return true
    }

    /// Count the triangles currently known to ARKit — useful for a
    /// "scanning… X triangles" progress label.
    public func refreshProgress() {
        guard state == .scanning, let session, let frame = session.currentFrame else { return }
        var total = 0
        for anchor in frame.anchors {
            guard let m = anchor as? ARMeshAnchor else { continue }
            total += m.geometry.faces.count
        }
        triangleCountSoFar = total
    }

    /// Walk every ARMeshAnchor in the session, concatenate their vertex+face
    /// data into a single mesh in WORLD coordinates, and return a RoomScan.
    /// Scene-reconstruction anchors each carry their own transform; we
    /// apply it to emit positions in a single shared frame.
    public func finish(nameForScan: String = "Room scan") -> RoomScan? {
        guard let session, let frame = session.currentFrame else { return nil }

        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var runningBase: UInt32 = 0

        for anchor in frame.anchors {
            guard let m = anchor as? ARMeshAnchor else { continue }
            let transform = m.transform
            let geom = m.geometry

            let vCount = geom.vertices.count
            positions.reserveCapacity(positions.count + vCount)

            let verts = geom.vertices
            let buffer = verts.buffer.contents()
            let stride = verts.stride
            let offset = verts.offset

            for i in 0..<vCount {
                let p = buffer.advanced(by: offset + i * stride).assumingMemoryBound(to: SIMD3<Float>.self).pointee
                // Apply anchor transform to get world-space position.
                let world = transform * SIMD4<Float>(p, 1)
                positions.append(SIMD3<Float>(world.x, world.y, world.z))
            }

            // Faces — ARMeshGeometry.faces has primitiveCount triangles, each
            // indexCountPerPrimitive (3) indices. Index bytes per index can be
            // 2 (UInt16) or 4 (UInt32) depending on vertex count.
            let faces = geom.faces
            let primitiveCount = faces.count
            let indicesPerFace = faces.indexCountPerPrimitive // 3 for triangles
            let bytesPerIndex = faces.bytesPerIndex
            let faceBuf = faces.buffer.contents()

            indices.reserveCapacity(indices.count + primitiveCount * indicesPerFace)
            for i in 0..<(primitiveCount * indicesPerFace) {
                let raw = faceBuf.advanced(by: i * bytesPerIndex)
                let idx: UInt32
                if bytesPerIndex == 2 {
                    idx = UInt32(raw.assumingMemoryBound(to: UInt16.self).pointee)
                } else {
                    idx = raw.assumingMemoryBound(to: UInt32.self).pointee
                }
                indices.append(runningBase + idx)
            }
            runningBase += UInt32(vCount)
        }

        state = .done
        return RoomScan.from(positions: positions, indices: indices, name: nameForScan)
    }

    public func stopAndDiscard() {
        state = .idle
        triangleCountSoFar = 0
        startedAt = nil
    }
}
#endif
