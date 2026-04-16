//
//  RoomScanMesh.swift
//  Understudy
//
//  Turns a `RoomScan` (base64-encoded positions + indices) into a RealityKit
//  `MeshResource` ready to render. Shared between iPhone ARStageContainer
//  and visionOS DirectorImmersiveView so both platforms display the same
//  ghost of the scouted room.
//

#if canImport(RealityKit)
import RealityKit
import Foundation
import simd
#if canImport(UIKit)
import UIKit
#endif

nonisolated public enum RoomScanMesh {

    /// Build a RealityKit MeshResource out of a scan. Returns nil if the
    /// scan decodes to zero triangles (corrupt data or not yet captured).
    public static func make(from scan: RoomScan) -> MeshResource? {
        let positions = scan.decodePositions()
        let indices = scan.decodeIndices()
        guard positions.count >= 9, indices.count >= 3 else { return nil }

        // Group the flat [Float] into SIMD3<Float> vertices.
        let vertexCount = positions.count / 3
        var simdPositions = [SIMD3<Float>]()
        simdPositions.reserveCapacity(vertexCount)
        for i in 0..<vertexCount {
            simdPositions.append(SIMD3<Float>(
                positions[i * 3 + 0],
                positions[i * 3 + 1],
                positions[i * 3 + 2]
            ))
        }

        var descriptor = MeshDescriptor(name: "roomScan")
        descriptor.positions = MeshBuffers.Positions(simdPositions)
        descriptor.primitives = .triangles(indices)

        return try? MeshResource.generate(from: [descriptor])
    }

    /// A semi-transparent "architectural drawing" material for the scan —
    /// cool cyan, low opacity so it reads as a ghost of the real room.
    public static func ghostMaterial() -> RealityKit.Material {
        var m = UnlitMaterial()
        #if canImport(UIKit)
        let cyan = UIColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 0.22)
        m.color = .init(tint: cyan)
        m.blending = .transparent(opacity: .init(floatLiteral: 0.22))
        #endif
        return m
    }
}
#endif
