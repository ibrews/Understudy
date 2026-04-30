//
//  StageMapView.swift
//  Understudy
//
//  Top-down 2D blocking diagram. The kind of paper a stage manager pins
//  to the rehearsal-room wall — auto-generated from the live blocking,
//  exportable as PDF or PNG for the cast.
//
//  What renders:
//    • a soft proscenium frame (4 × 6 m default playing area)
//    • the 9-zone stage grid (DSL, DSC, DSR, CSL, CS, CSR, USL, USC, USR)
//      labelled in their conventional positions
//    • every actor mark as a numbered cyan disc
//    • every camera mark as an amber triangle pointing in the shoot direction,
//      with a translucent FOV wedge
//    • props (cubes/spheres/cylinders) as their footprint shape
//    • a subtle dotted line connecting actor marks in sequence (the path)
//    • performer ghosts as small magenta dots with names
//    • a north-arrow style "DOWNSTAGE → audience" indicator
//
//  Cross-platform: same view works on iPhone and visionOS. The export uses
//  ImageRenderer (iOS 17+ and visionOS), bypassing the need for a separate
//  PDF / PNG pipeline.
//

import SwiftUI
import UniformTypeIdentifiers

public struct StageMapView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The half-extent of the rendered playing area, in meters.
    /// 3 m halfWidth × 4 m halfDepth → a 6 × 8 m frame which covers most
    /// real rehearsal rooms.
    private let halfWidth: Float = 3.0
    private let halfDepth: Float = 4.0

    @State private var showSequence: Bool = true
    @State private var showGrid: Bool = true
    @State private var showFOV: Bool = true
    @State private var showProps: Bool = true
    @State private var showPerformers: Bool = true
    @State private var renderedPNG: PNGTransferable?
    @State private var sharingPNG: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                toolbar
                Divider()
                map
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                legend
            }
            .navigationTitle(store.blocking.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        renderAndShare()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $sharingPNG) {
            if let png = renderedPNG {
                ShareSheet(item: png)
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder private var toolbar: some View {
        HStack(spacing: 16) {
            Toggle(isOn: $showSequence) {
                Label("Path", systemImage: "arrow.triangle.turn.up.right.diamond")
            }.toggleStyle(.button)
            Toggle(isOn: $showGrid) {
                Label("Grid", systemImage: "grid")
            }.toggleStyle(.button)
            Toggle(isOn: $showFOV) {
                Label("FOV", systemImage: "video")
            }.toggleStyle(.button)
            Toggle(isOn: $showProps) {
                Label("Props", systemImage: "cube")
            }.toggleStyle(.button)
            Toggle(isOn: $showPerformers) {
                Label("Cast", systemImage: "person.2")
            }.toggleStyle(.button)
            Spacer()
            Text("\(store.blocking.marks.count) marks")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Map canvas

    @ViewBuilder private var map: some View {
        GeometryReader { geo in
            mapCanvas(in: geo.size)
        }
    }

    private func mapCanvas(in size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            drawMap(ctx: &ctx, canvasSize: canvasSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Centralised drawing — used both for live render and for export.
    private func drawMap(ctx: inout GraphicsContext, canvasSize: CGSize) {
        let pad: CGFloat = 32
        let usableW = canvasSize.width - 2 * pad
        let usableH = canvasSize.height - 2 * pad
        // Aspect-fit a halfWidth × halfDepth box into the canvas.
        let frameW = CGFloat(halfWidth) * 2
        let frameH = CGFloat(halfDepth) * 2
        let scale = min(usableW / frameW, usableH / frameH)
        let originX = canvasSize.width / 2
        // Keep the audience at the bottom — +Z points up.
        let originY = canvasSize.height / 2

        func proj(_ x: Float, _ z: Float) -> CGPoint {
            // World +X = screen right, world +Z = screen UP (so audience is at the bottom).
            CGPoint(
                x: originX + CGFloat(x) * scale,
                y: originY - CGFloat(z) * scale
            )
        }

        // 1. Frame — the 4 × 6 m playing area.
        let frame = CGRect(
            x: originX - CGFloat(halfWidth) * scale,
            y: originY - CGFloat(halfDepth) * scale,
            width: frameW * scale,
            height: frameH * scale
        )
        let framePath = Path(roundedRect: frame, cornerRadius: 14)
        ctx.fill(framePath, with: .color(.white.opacity(0.04)))
        ctx.stroke(framePath, with: .color(.white.opacity(0.35)), lineWidth: 1.5)

        // 2. Audience indicator — a thin trapezoid at the bottom.
        let audienceY = frame.maxY + 6
        var audiencePath = Path()
        audiencePath.move(to: CGPoint(x: frame.minX + 24, y: audienceY))
        audiencePath.addLine(to: CGPoint(x: frame.maxX - 24, y: audienceY))
        audiencePath.addLine(to: CGPoint(x: frame.maxX - 60, y: audienceY + 12))
        audiencePath.addLine(to: CGPoint(x: frame.minX + 60, y: audienceY + 12))
        audiencePath.closeSubpath()
        ctx.fill(audiencePath, with: .color(.red.opacity(0.18)))
        ctx.stroke(audiencePath, with: .color(.red.opacity(0.5)), lineWidth: 1)
        ctx.draw(
            Text("AUDIENCE").font(.caption2.bold().monospaced()).foregroundColor(.white.opacity(0.6)),
            at: CGPoint(x: originX, y: audienceY + 22)
        )
        ctx.draw(
            Text("UPSTAGE").font(.caption2.monospaced()).foregroundColor(.white.opacity(0.4)),
            at: CGPoint(x: originX, y: frame.minY - 12)
        )
        ctx.draw(
            Text("STAGE LEFT").font(.caption2.monospaced()).foregroundColor(.white.opacity(0.35)),
            at: CGPoint(x: frame.minX - 14, y: originY)
        )
        ctx.draw(
            Text("STAGE RIGHT").font(.caption2.monospaced()).foregroundColor(.white.opacity(0.35)),
            at: CGPoint(x: frame.maxX + 14, y: originY)
        )

        // 3. 9-zone grid — only if enabled.
        if showGrid {
            let cellW = frame.width / 3
            let cellH = frame.height / 3
            for col in 0...3 {
                let x = frame.minX + CGFloat(col) * cellW
                ctx.stroke(
                    Path { p in p.move(to: CGPoint(x: x, y: frame.minY)); p.addLine(to: CGPoint(x: x, y: frame.maxY)) },
                    with: .color(.white.opacity(0.08)),
                    lineWidth: 0.75
                )
            }
            for row in 0...3 {
                let y = frame.minY + CGFloat(row) * cellH
                ctx.stroke(
                    Path { p in p.move(to: CGPoint(x: frame.minX, y: y)); p.addLine(to: CGPoint(x: frame.maxX, y: y)) },
                    with: .color(.white.opacity(0.08)),
                    lineWidth: 0.75
                )
            }
            // Zone labels — 3×3 = 9 cells.
            let labels = [
                ["US-L", "US-C", "US-R"],
                ["CS-L", "CS",   "CS-R"],
                ["DS-L", "DS-C", "DS-R"],
            ]
            for r in 0..<3 {
                for c in 0..<3 {
                    let cx = frame.minX + CGFloat(c) * cellW + cellW / 2
                    let cy = frame.minY + CGFloat(r) * cellH + cellH / 2
                    ctx.draw(
                        Text(labels[r][c])
                            .font(.caption2.monospaced())
                            .foregroundColor(.white.opacity(0.18)),
                        at: CGPoint(x: cx, y: cy)
                    )
                }
            }
        }

        // 4. Props (drawn under marks so marks stay readable).
        if showProps {
            for prop in store.blocking.props {
                let p = proj(prop.pose.x, prop.pose.z)
                let halfW = max(4, CGFloat(prop.width) * scale / 2)
                let halfD = max(4, CGFloat(prop.depth) * scale / 2)
                let color = Color(red: Double(prop.r), green: Double(prop.g), blue: Double(prop.b))
                switch prop.shape {
                case .cube:
                    let r = CGRect(x: p.x - halfW, y: p.y - halfD, width: halfW * 2, height: halfD * 2)
                    ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(color.opacity(0.55)))
                    ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(color), lineWidth: 1)
                case .sphere:
                    let r = max(halfW, halfD)
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.55)))
                    ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1)
                case .cylinder:
                    let r = max(halfW, halfD)
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.55)))
                    ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.5)
                }
                ctx.draw(
                    Text(prop.name).font(.caption2).foregroundColor(.white.opacity(0.6)),
                    at: CGPoint(x: p.x, y: p.y + halfD + 10)
                )
            }
        }

        // 5. Sequence path connecting actor marks in order.
        let sortedActorMarks = store.blocking.marks
            .filter { $0.kind == .actor && $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        if showSequence && sortedActorMarks.count >= 2 {
            var path = Path()
            for (i, m) in sortedActorMarks.enumerated() {
                let p = proj(m.pose.x, m.pose.z)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            ctx.stroke(
                path,
                with: .color(.cyan.opacity(0.55)),
                style: StrokeStyle(lineWidth: 2, dash: [6, 6])
            )
        }

        // 6. Camera marks first (so actor marks render on top).
        let cameraMarks = store.blocking.marks.filter { $0.kind == .camera }
        for mark in cameraMarks {
            let p = proj(mark.pose.x, mark.pose.z)
            let amber = Color(red: 1.0, green: 0.78, blue: 0.3)

            // FOV wedge.
            if showFOV, let spec = mark.camera {
                let fovLen: CGFloat = CGFloat(3.0) * scale
                let halfFov = CGFloat(spec.horizontalFOV / 2)
                // mark.pose.yaw rotates the rig; yaw=0 points along -Z (upstage).
                // Camera "looks" along -Z when yaw=0, so screen-up direction.
                let yaw = CGFloat(mark.pose.yaw)
                // Wedge tip at the camera; spreads forward along -Z (rotated).
                let leftAngle = -CGFloat.pi / 2 - halfFov + yaw    // -π/2 = up in screen
                let rightAngle = -CGFloat.pi / 2 + halfFov + yaw
                var wedge = Path()
                wedge.move(to: p)
                wedge.addLine(to: CGPoint(x: p.x + cos(leftAngle) * fovLen, y: p.y + sin(leftAngle) * fovLen))
                wedge.addLine(to: CGPoint(x: p.x + cos(rightAngle) * fovLen, y: p.y + sin(rightAngle) * fovLen))
                wedge.closeSubpath()
                ctx.fill(wedge, with: .color(amber.opacity(0.18)))
                ctx.stroke(wedge, with: .color(amber.opacity(0.6)), lineWidth: 0.75)
            }

            // Camera tripod indicator — a small triangle pointing along -Z.
            let yaw = CGFloat(mark.pose.yaw)
            let triSize: CGFloat = 7
            let forwardAngle = -CGFloat.pi / 2 + yaw
            let tipX = p.x + cos(forwardAngle) * triSize * 1.4
            let tipY = p.y + sin(forwardAngle) * triSize * 1.4
            let leftAngle = forwardAngle + 2 * .pi / 3
            let rightAngle = forwardAngle - 2 * .pi / 3
            var tri = Path()
            tri.move(to: CGPoint(x: tipX, y: tipY))
            tri.addLine(to: CGPoint(x: p.x + cos(leftAngle) * triSize, y: p.y + sin(leftAngle) * triSize))
            tri.addLine(to: CGPoint(x: p.x + cos(rightAngle) * triSize, y: p.y + sin(rightAngle) * triSize))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(amber))

            ctx.draw(
                Text(mark.name).font(.caption2.monospaced()).foregroundColor(amber),
                at: CGPoint(x: p.x, y: p.y + 22)
            )
        }

        // 7. Actor marks — numbered discs.
        for mark in sortedActorMarks {
            let p = proj(mark.pose.x, mark.pose.z)
            let r = max(8, CGFloat(mark.radius) * scale)
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.25)))
            ctx.stroke(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.85)), lineWidth: 1.5)
            // Sequence number in center.
            ctx.draw(
                Text("\(mark.sequenceIndex + 1)").font(.headline.bold()).foregroundColor(.white),
                at: p
            )
            ctx.draw(
                Text(mark.name).font(.caption2).foregroundColor(.white.opacity(0.85)),
                at: CGPoint(x: p.x, y: p.y + r + 12)
            )
        }

        // Freeform marks (no sequence, but still .actor).
        for mark in store.blocking.marks where mark.kind == .actor && mark.sequenceIndex < 0 {
            let p = proj(mark.pose.x, mark.pose.z)
            let r = max(6, CGFloat(mark.radius) * scale)
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(0.4)),
                style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
            )
            ctx.draw(
                Text(mark.name).font(.caption2).foregroundColor(.white.opacity(0.55)),
                at: CGPoint(x: p.x, y: p.y + r + 10)
            )
        }

        // 8. Performers — magenta dots.
        if showPerformers {
            for perf in store.performers {
                guard perf.id != store.localPerformerID else { continue }
                let p = proj(perf.pose.x, perf.pose.z)
                let dot = CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)
                ctx.fill(Path(ellipseIn: dot), with: .color(.pink.opacity(0.85)))
                ctx.draw(
                    Text(perf.displayName).font(.caption2).foregroundColor(.pink),
                    at: CGPoint(x: p.x, y: p.y - 14)
                )
            }
        }
    }

    // MARK: - Legend

    @ViewBuilder private var legend: some View {
        HStack(spacing: 18) {
            legendChip(color: .cyan, label: "Actor mark")
            legendChip(color: Color(red: 1.0, green: 0.78, blue: 0.3), label: "Camera (FOV wedge)")
            legendChip(color: .pink, label: "Performer")
            legendChip(color: .white.opacity(0.4), label: "Freeform mark", dashed: true)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.black)
    }

    @ViewBuilder private func legendChip(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 3] : []))
                .background(Circle().fill(color.opacity(0.25)))
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Export

    @MainActor
    private func renderAndShare() {
        let renderer = ImageRenderer(content:
            ZStack {
                Color.black
                StageMapCanvasContent(
                    store: store,
                    halfWidth: halfWidth, halfDepth: halfDepth,
                    showSequence: showSequence, showGrid: showGrid,
                    showFOV: showFOV, showProps: showProps,
                    showPerformers: showPerformers
                )
            }
            .frame(width: 1600, height: 1200)
        )
        renderer.scale = 2

        #if canImport(UIKit)
        if let img = renderer.uiImage, let data = img.pngData() {
            renderedPNG = PNGTransferable(data: data, suggestedName: "\(store.blocking.title) — Stage Map")
            sharingPNG = true
        }
        #endif
    }
}

// MARK: - Off-screen render content (mirrors drawMap so the export looks identical)

private struct StageMapCanvasContent: View {
    let store: BlockingStore
    let halfWidth: Float
    let halfDepth: Float
    let showSequence: Bool
    let showGrid: Bool
    let showFOV: Bool
    let showProps: Bool
    let showPerformers: Bool

    var body: some View {
        Canvas { ctx, size in
            // Reuse the drawing logic by instantiating a transient view's drawMap.
            // Since drawMap is a method on StageMapView, we duplicate the entry.
            StageMapDraw.draw(
                ctx: &ctx,
                canvasSize: size,
                store: store,
                halfWidth: halfWidth, halfDepth: halfDepth,
                showSequence: showSequence, showGrid: showGrid,
                showFOV: showFOV, showProps: showProps, showPerformers: showPerformers
            )
        }
    }
}

// MARK: - Drawing primitive shared between live view and exporter

private enum StageMapDraw {
    @MainActor
    static func draw(
        ctx: inout GraphicsContext,
        canvasSize: CGSize,
        store: BlockingStore,
        halfWidth: Float, halfDepth: Float,
        showSequence: Bool, showGrid: Bool,
        showFOV: Bool, showProps: Bool, showPerformers: Bool
    ) {
        // Header for export — title + date.
        let title = store.blocking.title
        ctx.draw(
            Text(title).font(.system(.title2, design: .serif).weight(.bold)).foregroundColor(.white),
            at: CGPoint(x: canvasSize.width / 2, y: 40)
        )
        ctx.draw(
            Text("\(store.blocking.marks.count) marks  •  Generated \(Date().formatted(date: .abbreviated, time: .omitted))")
                .font(.caption.monospaced())
                .foregroundColor(.white.opacity(0.5)),
            at: CGPoint(x: canvasSize.width / 2, y: 66)
        )

        // Layout: leave 100pt at top for header, 80pt at bottom for legend.
        let pad: CGFloat = 60
        let mapTop: CGFloat = 100
        let mapBottom: CGFloat = canvasSize.height - 100
        let usableW = canvasSize.width - 2 * pad
        let usableH = mapBottom - mapTop
        let frameW = CGFloat(halfWidth) * 2
        let frameH = CGFloat(halfDepth) * 2
        let scale = min(usableW / frameW, usableH / frameH)
        let originX = canvasSize.width / 2
        let originY = (mapTop + mapBottom) / 2

        func proj(_ x: Float, _ z: Float) -> CGPoint {
            CGPoint(
                x: originX + CGFloat(x) * scale,
                y: originY - CGFloat(z) * scale
            )
        }

        let frame = CGRect(
            x: originX - CGFloat(halfWidth) * scale,
            y: originY - CGFloat(halfDepth) * scale,
            width: frameW * scale,
            height: frameH * scale
        )
        ctx.fill(Path(roundedRect: frame, cornerRadius: 14), with: .color(.white.opacity(0.04)))
        ctx.stroke(Path(roundedRect: frame, cornerRadius: 14), with: .color(.white.opacity(0.45)), lineWidth: 2)

        // Audience indicator
        let audienceY = frame.maxY + 14
        var audiencePath = Path()
        audiencePath.move(to: CGPoint(x: frame.minX + 40, y: audienceY))
        audiencePath.addLine(to: CGPoint(x: frame.maxX - 40, y: audienceY))
        audiencePath.addLine(to: CGPoint(x: frame.maxX - 100, y: audienceY + 20))
        audiencePath.addLine(to: CGPoint(x: frame.minX + 100, y: audienceY + 20))
        audiencePath.closeSubpath()
        ctx.fill(audiencePath, with: .color(.red.opacity(0.18)))
        ctx.stroke(audiencePath, with: .color(.red.opacity(0.5)), lineWidth: 1)
        ctx.draw(
            Text("AUDIENCE").font(.caption.bold().monospaced()).foregroundColor(.white.opacity(0.6)),
            at: CGPoint(x: originX, y: audienceY + 40)
        )
        ctx.draw(
            Text("UPSTAGE").font(.caption.monospaced()).foregroundColor(.white.opacity(0.4)),
            at: CGPoint(x: originX, y: frame.minY - 18)
        )

        // 9-zone grid (mirrored from live)
        if showGrid {
            let cellW = frame.width / 3
            let cellH = frame.height / 3
            for col in 0...3 {
                let x = frame.minX + CGFloat(col) * cellW
                ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: frame.minY)); p.addLine(to: CGPoint(x: x, y: frame.maxY)) },
                           with: .color(.white.opacity(0.08)), lineWidth: 0.75)
            }
            for row in 0...3 {
                let y = frame.minY + CGFloat(row) * cellH
                ctx.stroke(Path { p in p.move(to: CGPoint(x: frame.minX, y: y)); p.addLine(to: CGPoint(x: frame.maxX, y: y)) },
                           with: .color(.white.opacity(0.08)), lineWidth: 0.75)
            }
        }

        // Sequence path
        let sortedActorMarks = store.blocking.marks
            .filter { $0.kind == .actor && $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        if showSequence && sortedActorMarks.count >= 2 {
            var path = Path()
            for (i, m) in sortedActorMarks.enumerated() {
                let p = proj(m.pose.x, m.pose.z)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            ctx.stroke(path, with: .color(.cyan.opacity(0.55)), style: StrokeStyle(lineWidth: 2.5, dash: [8, 8]))
        }

        // Props
        if showProps {
            for prop in store.blocking.props {
                let p = proj(prop.pose.x, prop.pose.z)
                let halfW = max(8, CGFloat(prop.width) * scale / 2)
                let halfD = max(8, CGFloat(prop.depth) * scale / 2)
                let color = Color(red: Double(prop.r), green: Double(prop.g), blue: Double(prop.b))
                let r = CGRect(x: p.x - halfW, y: p.y - halfD, width: halfW * 2, height: halfD * 2)
                ctx.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(color.opacity(0.55)))
                ctx.draw(Text(prop.name).font(.caption2).foregroundColor(.white.opacity(0.6)),
                         at: CGPoint(x: p.x, y: p.y + halfD + 12))
            }
        }

        // Cameras
        let amber = Color(red: 1.0, green: 0.78, blue: 0.3)
        for mark in store.blocking.marks where mark.kind == .camera {
            let p = proj(mark.pose.x, mark.pose.z)
            if showFOV, let spec = mark.camera {
                let fovLen: CGFloat = CGFloat(3.0) * scale
                let halfFov = CGFloat(spec.horizontalFOV / 2)
                let yaw = CGFloat(mark.pose.yaw)
                let leftAngle = -CGFloat.pi / 2 - halfFov + yaw
                let rightAngle = -CGFloat.pi / 2 + halfFov + yaw
                var wedge = Path()
                wedge.move(to: p)
                wedge.addLine(to: CGPoint(x: p.x + cos(leftAngle) * fovLen, y: p.y + sin(leftAngle) * fovLen))
                wedge.addLine(to: CGPoint(x: p.x + cos(rightAngle) * fovLen, y: p.y + sin(rightAngle) * fovLen))
                wedge.closeSubpath()
                ctx.fill(wedge, with: .color(amber.opacity(0.18)))
                ctx.stroke(wedge, with: .color(amber.opacity(0.6)), lineWidth: 1)
            }
            let yaw = CGFloat(mark.pose.yaw)
            let triSize: CGFloat = 10
            let forwardAngle = -CGFloat.pi / 2 + yaw
            let tipX = p.x + cos(forwardAngle) * triSize * 1.5
            let tipY = p.y + sin(forwardAngle) * triSize * 1.5
            let leftAngle = forwardAngle + 2 * .pi / 3
            let rightAngle = forwardAngle - 2 * .pi / 3
            var tri = Path()
            tri.move(to: CGPoint(x: tipX, y: tipY))
            tri.addLine(to: CGPoint(x: p.x + cos(leftAngle) * triSize, y: p.y + sin(leftAngle) * triSize))
            tri.addLine(to: CGPoint(x: p.x + cos(rightAngle) * triSize, y: p.y + sin(rightAngle) * triSize))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(amber))
            ctx.draw(Text(mark.name).font(.caption.monospaced()).foregroundColor(amber),
                     at: CGPoint(x: p.x, y: p.y + 28))
        }

        // Actor marks
        for mark in sortedActorMarks {
            let p = proj(mark.pose.x, mark.pose.z)
            let r = max(12, CGFloat(mark.radius) * scale)
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.25)))
            ctx.stroke(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.9)), lineWidth: 2)
            ctx.draw(Text("\(mark.sequenceIndex + 1)").font(.title3.bold()).foregroundColor(.white), at: p)
            ctx.draw(Text(mark.name).font(.caption).foregroundColor(.white.opacity(0.85)),
                     at: CGPoint(x: p.x, y: p.y + r + 16))
        }
    }
}

// MARK: - PNG transferable for export sheet

private struct PNGTransferable: Transferable {
    let data: Data
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.data
        }
        .suggestedFileName { $0.suggestedName + ".png" }
    }
}

// MARK: - Cross-platform share sheet

#if os(iOS)
private struct ShareSheet: UIViewControllerRepresentable {
    let item: PNGTransferable

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.suggestedName + ".png")
        try? item.data.write(to: url)
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#elseif os(visionOS)
// On visionOS, surface a simple "Saved to Files" message rather than an
// activity sheet (which has a different presentation model). Tap the
// button again to write a fresh copy.
private struct ShareSheet: View {
    let item: PNGTransferable
    @Environment(\.dismiss) private var dismiss
    @State private var savedURL: URL?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let savedURL {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Saved")
                        .font(.title2.bold())
                    Text(savedURL.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if let saveError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Couldn't save")
                        .font(.title2.bold())
                    Text(saveError).font(.caption).foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Stage Map")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                let url = URL.documentsDirectory.appendingPathComponent(item.suggestedName + ".png")
                do {
                    try item.data.write(to: url)
                    savedURL = url
                } catch {
                    saveError = error.localizedDescription
                }
            }
        }
    }
}
#endif
