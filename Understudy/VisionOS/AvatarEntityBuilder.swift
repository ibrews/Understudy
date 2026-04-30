//
//  AvatarEntityBuilder.swift
//  Understudy (visionOS)
//
//  Builds RealityKit Entity hierarchies for each Avatar.Style. Mirrors
//  the silhouettes drawn by AvatarPreview's Canvas so the in-sheet
//  preview matches what the director actually sees in the immersive
//  stage.
//
//  Each style targets ~1.7 m tall — human-scale on the floor — with the
//  origin (parent entity's position) at floor level.
//

#if os(visionOS)
import Foundation
import RealityKit
import UIKit

@MainActor
public enum AvatarEntityBuilder {
    /// Attach the avatar's geometry as children of `parent`. The parent's
    /// origin should be at the performer's floor position.
    public static func attach(avatar: Avatar, to parent: Entity) {
        let primaryColor = uiColor(rgba: avatar.primaryRGBA)
        let accentColor = uiColor(rgba: avatar.secondaryRGBA)

        switch avatar.style {
        case .performer:
            attachPerformer(parent: parent, primary: primaryColor, accent: accentColor)
        case .dancer:
            attachDancer(parent: parent, primary: primaryColor, accent: accentColor)
        case .ghost:
            attachGhost(parent: parent, primary: primaryColor, accent: accentColor)
        case .minimal:
            attachMinimal(parent: parent, primary: primaryColor, accent: accentColor)
        case .villain:
            attachVillain(parent: parent, primary: primaryColor, accent: accentColor)
        case .hero:
            attachHero(parent: parent, primary: primaryColor, accent: accentColor)
        }
    }

    // MARK: - Style implementations

    private static func attachPerformer(parent: Entity, primary: UIColor, accent: UIColor) {
        // Body: capsule-ish (a capsule + cylinder + sphere head at top).
        let bodyHeight: Float = 1.0
        let body = ModelEntity(
            mesh: .generateBox(size: [0.45, bodyHeight, 0.30], cornerRadius: 0.15),
            materials: [UnlitMaterial(color: primary.withAlphaComponent(0.9))]
        )
        body.position = [0, 0.55, 0]
        parent.addChild(body)

        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.18),
            materials: [UnlitMaterial(color: accent)]
        )
        head.position = [0, 1.32, 0]
        parent.addChild(head)

        // Legs as a stand-in plinth so the body doesn't float.
        let legs = ModelEntity(
            mesh: .generateBox(size: [0.45, 0.12, 0.30], cornerRadius: 0.04),
            materials: [UnlitMaterial(color: primary.withAlphaComponent(0.7))]
        )
        legs.position = [0, 0.06, 0]
        parent.addChild(legs)
    }

    private static func attachDancer(parent: Entity, primary: UIColor, accent: UIColor) {
        // Tall slim body + raised arms.
        let body = ModelEntity(
            mesh: .generateBox(size: [0.18, 1.0, 0.18], cornerRadius: 0.09),
            materials: [UnlitMaterial(color: primary)]
        )
        body.position = [0, 0.6, 0]
        parent.addChild(body)

        // Arms — two cylinders rotated outward at +60° / -60°.
        let armLen: Float = 0.55
        let armR = ModelEntity(
            mesh: .generateBox(size: [0.06, armLen, 0.06], cornerRadius: 0.03),
            materials: [UnlitMaterial(color: primary)]
        )
        armR.position = [0.30, 1.18, 0]
        armR.orientation = simd_quatf(angle: .pi / 4, axis: [0, 0, 1])
        parent.addChild(armR)
        let armL = ModelEntity(
            mesh: .generateBox(size: [0.06, armLen, 0.06], cornerRadius: 0.03),
            materials: [UnlitMaterial(color: primary)]
        )
        armL.position = [-0.30, 1.18, 0]
        armL.orientation = simd_quatf(angle: -.pi / 4, axis: [0, 0, 1])
        parent.addChild(armL)

        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.16),
            materials: [UnlitMaterial(color: accent)]
        )
        head.position = [0, 1.30, 0]
        parent.addChild(head)
    }

    private static func attachGhost(parent: Entity, primary: UIColor, accent: UIColor) {
        // Translucent body + halo.
        let body = ModelEntity(
            mesh: .generateSphere(radius: 0.30),
            materials: [translucentMaterial(color: primary, alpha: 0.55)]
        )
        body.position = [0, 1.10, 0]
        parent.addChild(body)

        let halo = ModelEntity(
            mesh: .generateSphere(radius: 0.50),
            materials: [translucentMaterial(color: primary, alpha: 0.18)]
        )
        halo.position = [0, 1.10, 0]
        parent.addChild(halo)

        // Trailing wisps (small spheres at decreasing height + opacity).
        for i in 0..<4 {
            let y: Float = 0.85 - Float(i) * 0.18
            let alpha = 0.42 - Float(i) * 0.08
            let r: Float = 0.20 - Float(i) * 0.03
            let wisp = ModelEntity(
                mesh: .generateSphere(radius: r),
                materials: [translucentMaterial(color: primary, alpha: CGFloat(alpha))]
            )
            wisp.position = [0, y, 0]
            parent.addChild(wisp)
        }

        // Accent eye-dots so it reads as a face.
        let eyeR = ModelEntity(
            mesh: .generateSphere(radius: 0.04),
            materials: [UnlitMaterial(color: accent)]
        )
        eyeR.position = [0.10, 1.18, -0.26]
        parent.addChild(eyeR)
        let eyeL = ModelEntity(
            mesh: .generateSphere(radius: 0.04),
            materials: [UnlitMaterial(color: accent)]
        )
        eyeL.position = [-0.10, 1.18, -0.26]
        parent.addChild(eyeL)
    }

    private static func attachMinimal(parent: Entity, primary: UIColor, accent: UIColor) {
        // Single sphere at chest height with a small accent dot.
        let body = ModelEntity(
            mesh: .generateSphere(radius: 0.28),
            materials: [UnlitMaterial(color: primary)]
        )
        body.position = [0, 1.10, 0]
        parent.addChild(body)

        let dot = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [UnlitMaterial(color: accent)]
        )
        dot.position = [0, 1.10, -0.28]
        parent.addChild(dot)
    }

    private static func attachVillain(parent: Entity, primary: UIColor, accent: UIColor) {
        // Wider shoulders + cape + horned head.
        let shoulders = ModelEntity(
            mesh: .generateBox(size: [0.65, 0.20, 0.35], cornerRadius: 0.06),
            materials: [UnlitMaterial(color: primary)]
        )
        shoulders.position = [0, 1.05, 0]
        parent.addChild(shoulders)

        let body = ModelEntity(
            mesh: .generateBox(size: [0.45, 0.95, 0.30], cornerRadius: 0.10),
            materials: [UnlitMaterial(color: primary.withAlphaComponent(0.9))]
        )
        body.position = [0, 0.55, 0]
        parent.addChild(body)

        // Cape behind: flat, slightly wider than body.
        let cape = ModelEntity(
            mesh: .generateBox(size: [0.7, 1.2, 0.04], cornerRadius: 0.05),
            materials: [translucentMaterial(color: primary, alpha: 0.85)]
        )
        cape.position = [0, 0.7, 0.18]
        parent.addChild(cape)

        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.18),
            materials: [UnlitMaterial(color: accent)]
        )
        head.position = [0, 1.40, 0]
        parent.addChild(head)

        // Horns
        for sx in [-1, 1] as [Float] {
            let horn = ModelEntity(
                mesh: .generateCone(height: 0.18, radius: 0.04),
                materials: [UnlitMaterial(color: accent)]
            )
            horn.position = [sx * 0.10, 1.65, 0]
            parent.addChild(horn)
        }
    }

    private static func attachHero(parent: Entity, primary: UIColor, accent: UIColor) {
        let body = ModelEntity(
            mesh: .generateBox(size: [0.50, 1.0, 0.32], cornerRadius: 0.18),
            materials: [UnlitMaterial(color: primary)]
        )
        body.position = [0, 0.55, 0]
        parent.addChild(body)

        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.18),
            materials: [UnlitMaterial(color: accent)]
        )
        head.position = [0, 1.32, 0]
        parent.addChild(head)

        // Crown — a torus-like ring would need MeshDescriptor; a
        // flattened cylinder at the top of the head reads as a halo /
        // crown without that complexity.
        let crown = ModelEntity(
            mesh: .generateCylinder(height: 0.06, radius: 0.20),
            materials: [UnlitMaterial(color: accent)]
        )
        crown.position = [0, 1.52, 0]
        parent.addChild(crown)

        // Star above the crown — a tetrahedron approximated as a small
        // box rotated 45°.
        let star = ModelEntity(
            mesh: .generateBox(size: [0.10, 0.10, 0.10], cornerRadius: 0.01),
            materials: [UnlitMaterial(color: accent)]
        )
        star.position = [0, 1.72, 0]
        star.orientation = simd_quatf(angle: .pi / 4, axis: [0, 0, 1])
            * simd_quatf(angle: .pi / 4, axis: [1, 0, 0])
        parent.addChild(star)
    }

    // MARK: - Helpers

    private static func uiColor(rgba: SIMD4<Float>) -> UIColor {
        UIColor(
            red: CGFloat(rgba.x),
            green: CGFloat(rgba.y),
            blue: CGFloat(rgba.z),
            alpha: CGFloat(rgba.w)
        )
    }

    private static func translucentMaterial(color: UIColor, alpha: CGFloat) -> RealityKit.Material {
        var m = UnlitMaterial()
        m.color = .init(tint: color.withAlphaComponent(alpha))
        m.blending = .transparent(opacity: .init(floatLiteral: Float(alpha)))
        return m
    }
}

private extension UnlitMaterial {
    init(color: UIColor) {
        self.init()
        self.color = .init(tint: color)
    }
}
#endif
