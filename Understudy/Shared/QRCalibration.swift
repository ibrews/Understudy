//
//  QRCalibration.swift
//  Understudy
//
//  Precise shared-origin calibration via a QR code. The director prints (or
//  displays on a screen) a known-size QR whose payload encodes the room.
//  Performer phones point their cameras at it; ARKit's image-tracking
//  recognizes the tag and reports its world-frame pose. That pose becomes
//  the shared origin for every device that scans the same QR.
//
//  This upgrades v0.7's "stand at stage center, face upstage, tap compass
//  at the same time" ceremony. v0.7 still works as a fallback on devices
//  where image tracking isn't desired.
//
//  Payload format (intentionally tiny so the QR stays low-density):
//
//      understudy://room/<roomCode>?size=<mm>
//
//  where `mm` is the printed side-length of the QR in millimeters. The QR
//  encoder defaults to 210 mm (A4 landscape-ish). Performers don't need
//  to know the size — ARKit uses the declared physical size to set the
//  camera's scale; a wrong declaration just shifts depth but keeps the
//  frame orientation correct.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif
#if canImport(ARKit) && os(iOS)
import ARKit
#endif
import simd

nonisolated public enum QRCalibration {

    public static let defaultPhysicalSizeM: Float = 0.210  // 21 cm — typical printed sheet

    /// Encode a room code + physical size into a QR payload URL.
    public static func payload(roomCode: String, physicalSizeM: Float) -> String {
        let mm = Int(round(physicalSizeM * 1000))
        return "understudy://room/\(roomCode)?size=\(mm)"
    }

    /// Parse back. Returns (roomCode, physicalSizeM) or nil if unrecognized.
    public static func parse(_ payload: String) -> (room: String, sizeM: Float)? {
        guard let url = URL(string: payload),
              url.scheme == "understudy",
              url.host == "room" else { return nil }
        let room = url.lastPathComponent
        let mm: Float = {
            guard let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "size" })?
                .value,
                  let v = Float(q) else { return defaultPhysicalSizeM * 1000 }
            return v
        }()
        return (room, mm / 1000)
    }

    #if canImport(UIKit)
    /// Generate a printable QR image for a given payload. 512 × 512 by default.
    public static func generateQR(payload: String, pixelSize: CGFloat = 512) -> UIImage? {
        let data = Data(payload.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = pixelSize / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif

    #if canImport(ARKit) && os(iOS)
    /// Build an ARKit reference-image set containing the fixed calibration
    /// target. Returns nil if ARKit / CIImage plumbing fails — the caller
    /// should fall back to the manual "stand here, tap compass" ceremony.
    ///
    /// One target image for the whole app. The payload encoded into the
    /// QR is `understudy://calibrate` — plain, no per-room state — which
    /// lets any performer anywhere use the same printed target.
    @MainActor
    public static func buildDetectionImageSet() -> Set<ARReferenceImage>? {
        guard let ui = generateQR(payload: "understudy://calibrate", pixelSize: 1024),
              let cg = ui.cgImage else { return nil }
        let ref = ARReferenceImage(cg, orientation: .up, physicalWidth: CGFloat(defaultPhysicalSizeM))
        ref.name = "understudy://calibrate"
        return [ref]
    }
    #endif

    /// Convert a detected-image world transform into a `DeviceCalibration`.
    ///
    /// ARKit reports the image's transform in the device's RAW ARKit world
    /// frame. Its position is the image center; its orientation has +Y as
    /// the image surface normal. For an upright QR on a wall, we extract
    /// floor-plane projection (x, z) and yaw from the image's local X axis.
    public static func calibration(from imageTransform: simd_float4x4) -> DeviceCalibration {
        let pos = SIMD3<Float>(
            imageTransform.columns.3.x,
            imageTransform.columns.3.y,
            imageTransform.columns.3.z
        )
        // The image's +X axis in world space — this is the left-to-right
        // direction across the printed sheet. We treat that as the
        // upstage direction (yaw=0 looking along +Z).
        let imageRight = SIMD3<Float>(
            imageTransform.columns.0.x,
            imageTransform.columns.0.y,
            imageTransform.columns.0.z
        )
        // Project onto the floor plane and convert to a yaw angle.
        let yaw = atan2f(imageRight.x, imageRight.z)
        return DeviceCalibration(
            anchor: Pose(x: pos.x, y: 0, z: pos.z, yaw: yaw)
        )
    }
}
