//
//  ViewfinderOverlay.swift
//  Understudy (iOS)
//
//  When Author mode is in "camera" drop kind, overlay a framing rectangle
//  on the AR camera feed that shows what the selected lens would actually
//  capture from the phone's current position. Lets the DP see a 35mm
//  against a 24mm against an 85mm, then drop the mark on the one they like.
//
//  Math is deliberately simple — the phone's rear wide lens has a known
//  approximate horizontal FOV (~65° on iPhone 13 Pro+ main camera, ~63°
//  on 15 Pro). The target lens's FOV is computed from its CameraSpec.
//  Framing ratio = spec.horizontalFOV / phoneHFOV. Vertical dimension
//  follows the spec's sensor aspect ratio (not the phone's, because we're
//  simulating a different camera's frame).
//

#if os(iOS)
import SwiftUI

struct ViewfinderOverlay: View {
    let spec: CameraSpec

    /// Approximate horizontal field of view of the iPhone's rear wide lens,
    /// which is what ARKit's `cameraFeed()` environment uses by default.
    /// This is a ballpark — iPhone 13 Pro+ is ~65°, some older models
    /// narrower. Could be read from ARCamera.projectionMatrix for precision
    /// later but this is visually close enough.
    static let phoneHorizontalFOV: Float = 65 * .pi / 180

    var body: some View {
        GeometryReader { geo in
            let hfovRatio = spec.horizontalFOV / Self.phoneHorizontalFOV
            let frameW = max(40, CGFloat(hfovRatio) * geo.size.width)
            let aspect = spec.sensorHeightMM > 0
                ? spec.sensorWidthMM / spec.sensorHeightMM
                : 1.5
            let frameH = frameW / CGFloat(aspect)
            let frame = CGRect(
                x: (geo.size.width - frameW) / 2,
                y: (geo.size.height - frameH) / 2,
                width: frameW,
                height: frameH
            )

            ZStack {
                // Dim everything outside the frame via a cut-out mask.
                Color.black.opacity(0.35)
                    .mask {
                        Rectangle()
                            .overlay {
                                Rectangle()
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }

                // Framing rectangle + corner ticks.
                Rectangle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)

                cornerTicks(in: frame)

                // Rule of thirds.
                Path { p in
                    p.move(to: CGPoint(x: frame.minX + frame.width / 3, y: frame.minY))
                    p.addLine(to: CGPoint(x: frame.minX + frame.width / 3, y: frame.maxY))
                    p.move(to: CGPoint(x: frame.minX + 2 * frame.width / 3, y: frame.minY))
                    p.addLine(to: CGPoint(x: frame.minX + 2 * frame.width / 3, y: frame.maxY))
                    p.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height / 3))
                    p.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + frame.height / 3))
                    p.move(to: CGPoint(x: frame.minX, y: frame.minY + 2 * frame.height / 3))
                    p.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + 2 * frame.height / 3))
                }
                .stroke(.white.opacity(0.25), lineWidth: 1)

                // Lens label chip.
                lensChip
                    .position(x: frame.midX, y: frame.minY - 18)
            }
        }
        .allowsHitTesting(false)
    }

    private func cornerTicks(in frame: CGRect) -> some View {
        let tick: CGFloat = 18
        return Path { p in
            let corners: [(CGPoint, CGPoint, CGPoint)] = [
                (CGPoint(x: frame.minX + tick, y: frame.minY), CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.minX, y: frame.minY + tick)),
                (CGPoint(x: frame.maxX - tick, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY + tick)),
                (CGPoint(x: frame.minX + tick, y: frame.maxY), CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.minX, y: frame.maxY - tick)),
                (CGPoint(x: frame.maxX - tick, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY - tick)),
            ]
            for c in corners {
                p.move(to: c.0); p.addLine(to: c.1); p.addLine(to: c.2)
            }
        }
        .stroke(.white, lineWidth: 3)
    }

    private var lensChip: some View {
        HStack(spacing: 4) {
            Text("\(Int(spec.focalLengthMM))mm")
                .font(.caption.monospaced().bold())
            Text("·")
                .foregroundStyle(.white.opacity(0.5))
            Text(String(format: "%.0f°", Double(spec.horizontalFOV) * 180 / .pi))
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.black.opacity(0.75), in: Capsule())
        .foregroundStyle(.white)
    }
}
#endif
