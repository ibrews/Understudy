//
//  AvatarPickerView.swift
//  Understudy
//
//  Pick an avatar style + colours. Cross-platform sheet — surfaced from
//  Settings → Identity on iPhone and from the Director Panel on visionOS.
//
//  Layout: a live preview at top (rendered with Canvas — works without
//  RealityKit in this sheet) + a grid of style cards + colour swatches
//  for primary and secondary.
//
//  On dismiss, persists to @AppStorage so the local performer's avatar
//  is hydrated on next launch (UnderstudyApp.onAppear).
//

import SwiftUI

public struct AvatarPickerView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(\.dismiss) private var dismiss

    @AppStorage("avatarStyle") private var avatarStyleRaw: String = Avatar.Style.performer.rawValue
    @AppStorage("avatarPrimary") private var avatarPrimary: String = Avatar.defaultPick.primaryHex
    @AppStorage("avatarSecondary") private var avatarSecondary: String = Avatar.defaultPick.secondaryHex

    @State private var workingStyle: Avatar.Style = .performer
    @State private var workingPrimary: String = Avatar.defaultPick.primaryHex
    @State private var workingSecondary: String = Avatar.defaultPick.secondaryHex

    public init() {}

    private var workingAvatar: Avatar {
        Avatar(style: workingStyle, primaryHex: workingPrimary, secondaryHex: workingSecondary)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    preview
                    stylePicker
                    colorPicker(label: "Primary", hex: $workingPrimary)
                    colorPicker(label: "Accent", hex: $workingSecondary)
                    blurb
                }
                .padding(20)
            }
            .navigationTitle("Choose Your Avatar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            workingStyle = Avatar.Style(rawValue: avatarStyleRaw) ?? .performer
            workingPrimary = avatarPrimary
            workingSecondary = avatarSecondary
        }
    }

    @ViewBuilder private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(.black)
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.15), lineWidth: 1)
            AvatarPreview(avatar: workingAvatar)
                .frame(maxWidth: .infinity, maxHeight: 220)
                .padding(20)
        }
        .frame(height: 240)
    }

    @ViewBuilder private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Style")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 180), spacing: 10)], spacing: 10) {
                ForEach(Avatar.Style.allCases) { style in
                    Button { workingStyle = style } label: {
                        VStack(spacing: 10) {
                            Image(systemName: style.systemImage)
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                            Text(style.displayName)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(
                            workingStyle == style
                                ? Color.accentColor.opacity(0.4)
                                : Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    workingStyle == style ? Color.accentColor : Color.white.opacity(0.12),
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private func colorPicker(label: String, hex: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 38, maximum: 60), spacing: 10)], spacing: 10) {
                ForEach(Avatar.palette, id: \.self) { swatch in
                    Button {
                        hex.wrappedValue = swatch
                    } label: {
                        Circle()
                            .fill(swiftColor(swatch))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle().stroke(
                                    hex.wrappedValue == swatch ? Color.white : Color.white.opacity(0.2),
                                    lineWidth: hex.wrappedValue == swatch ? 3 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var blurb: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("About this avatar")
            Text(workingStyle.blurb)
                .font(.body)
                .foregroundStyle(.white.opacity(0.78))
            Text("Other peers in the same room see your avatar in real time — visionOS directors see it in 3D, iOS performers see it as a ghost orb on the AR stage.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 6)
        }
        .padding(.top, 8)
    }

    @ViewBuilder private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.bold().monospaced())
            .foregroundStyle(.white.opacity(0.55))
    }

    private func swiftColor(_ hex: String) -> Color {
        let rgba = Avatar.rgba(from: hex)
        return Color(red: Double(rgba.x), green: Double(rgba.y), blue: Double(rgba.z))
    }

    private func save() {
        avatarStyleRaw = workingStyle.rawValue
        avatarPrimary = workingPrimary
        avatarSecondary = workingSecondary
        // Apply to the local performer + broadcast immediately so peers
        // see the new avatar without waiting for the next pose tick.
        if var me = store.localPerformer {
            me.avatar = workingAvatar
            store.upsertPerformer(me)
            session.transport.send(.performerUpdate(me), from: me.id)
        }
        dismiss()
    }
}

// MARK: - Avatar mini-preview (Canvas-based, cross-platform)

/// A 2D stylised preview of the avatar — used in the picker sheet and
/// anywhere we want to show "this is what you / they look like" without
/// instantiating a RealityKit entity. The 3D entity builder lives in the
/// platform-specific render code (visionOS DirectorImmersiveView, iOS
/// ARStageContainer) and uses the same colour palette.
public struct AvatarPreview: View {
    public let avatar: Avatar
    @State private var phase: Double = 0

    public init(avatar: Avatar) { self.avatar = avatar }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            Canvas { gctx, size in
                draw(into: &gctx, size: size, time: ctx.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func draw(into ctx: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let scale = min(size.width, size.height) / 220
        let primary = Color(rgba: avatar.primaryRGBA)
        let accent = Color(rgba: avatar.secondaryRGBA)
        let bob = sin(time * 1.4) * 4 * scale

        switch avatar.style {
        case .performer:
            // Body — tall capsule + round head.
            let bodyRect = CGRect(
                x: centerX - 28 * scale,
                y: centerY - 45 * scale + bob,
                width: 56 * scale,
                height: 90 * scale
            )
            ctx.fill(Path(roundedRect: bodyRect, cornerRadius: 28 * scale), with: .color(primary))
            // Head
            let headR: CGFloat = 22 * scale
            let head = CGRect(x: centerX - headR, y: centerY - 75 * scale + bob, width: headR * 2, height: headR * 2)
            ctx.fill(Path(ellipseIn: head), with: .color(accent))

        case .dancer:
            // Slim body + raised arms in a Y-pose.
            let body = CGRect(
                x: centerX - 12 * scale,
                y: centerY - 30 * scale + bob,
                width: 24 * scale,
                height: 80 * scale
            )
            ctx.fill(Path(roundedRect: body, cornerRadius: 12 * scale), with: .color(primary))
            // Arms
            var armL = Path()
            armL.move(to: CGPoint(x: centerX - 6 * scale, y: centerY - 25 * scale + bob))
            armL.addLine(to: CGPoint(x: centerX - 50 * scale, y: centerY - 70 * scale + bob))
            ctx.stroke(armL, with: .color(primary), style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round))
            var armR = Path()
            armR.move(to: CGPoint(x: centerX + 6 * scale, y: centerY - 25 * scale + bob))
            armR.addLine(to: CGPoint(x: centerX + 50 * scale, y: centerY - 70 * scale + bob))
            ctx.stroke(armR, with: .color(primary), style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round))
            // Head
            let head = CGRect(x: centerX - 16 * scale, y: centerY - 60 * scale + bob, width: 32 * scale, height: 32 * scale)
            ctx.fill(Path(ellipseIn: head), with: .color(accent))

        case .ghost:
            // Translucent floating sphere with a long tail.
            // Outer halo
            let halo = CGRect(x: centerX - 50 * scale, y: centerY - 50 * scale + bob, width: 100 * scale, height: 100 * scale)
            ctx.fill(Path(ellipseIn: halo), with: .color(primary.opacity(0.18)))
            // Trail
            for i in 0..<5 {
                let off = CGFloat(i) * 14 * scale
                let alpha = 0.5 - Double(i) * 0.08
                let dot = CGRect(x: centerX - 14 * scale, y: centerY + off + bob, width: 28 * scale, height: 28 * scale)
                ctx.fill(Path(ellipseIn: dot), with: .color(primary.opacity(alpha)))
            }
            // Body
            let body = CGRect(x: centerX - 28 * scale, y: centerY - 30 * scale + bob, width: 56 * scale, height: 56 * scale)
            ctx.fill(Path(ellipseIn: body), with: .color(primary.opacity(0.65)))
            ctx.stroke(Path(ellipseIn: body), with: .color(accent.opacity(0.85)), lineWidth: 2)

        case .minimal:
            let r = CGRect(x: centerX - 26 * scale, y: centerY - 26 * scale + bob, width: 52 * scale, height: 52 * scale)
            ctx.fill(Path(ellipseIn: r), with: .color(primary))
            // Tiny accent dot
            let dot = CGRect(x: centerX - 4 * scale, y: centerY - 4 * scale + bob, width: 8 * scale, height: 8 * scale)
            ctx.fill(Path(ellipseIn: dot), with: .color(accent))

        case .villain:
            // Wider shoulders, dark cape, taller head with horns.
            let cape = Path { p in
                p.move(to: CGPoint(x: centerX - 50 * scale, y: centerY - 30 * scale + bob))
                p.addLine(to: CGPoint(x: centerX + 50 * scale, y: centerY - 30 * scale + bob))
                p.addLine(to: CGPoint(x: centerX + 30 * scale, y: centerY + 60 * scale + bob))
                p.addLine(to: CGPoint(x: centerX - 30 * scale, y: centerY + 60 * scale + bob))
                p.closeSubpath()
            }
            ctx.fill(cape, with: .color(primary.opacity(0.85)))
            // Head with horns
            let head = CGRect(x: centerX - 22 * scale, y: centerY - 70 * scale + bob, width: 44 * scale, height: 44 * scale)
            ctx.fill(Path(ellipseIn: head), with: .color(accent))
            var hornL = Path()
            hornL.move(to: CGPoint(x: centerX - 18 * scale, y: centerY - 70 * scale + bob))
            hornL.addLine(to: CGPoint(x: centerX - 28 * scale, y: centerY - 92 * scale + bob))
            ctx.stroke(hornL, with: .color(accent), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))
            var hornR = Path()
            hornR.move(to: CGPoint(x: centerX + 18 * scale, y: centerY - 70 * scale + bob))
            hornR.addLine(to: CGPoint(x: centerX + 28 * scale, y: centerY - 92 * scale + bob))
            ctx.stroke(hornR, with: .color(accent), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))

        case .hero:
            // Body
            let body = CGRect(x: centerX - 26 * scale, y: centerY - 20 * scale + bob, width: 52 * scale, height: 80 * scale)
            ctx.fill(Path(roundedRect: body, cornerRadius: 24 * scale), with: .color(primary))
            // Star above the head
            let star = Path { p in
                let starPts = 5
                let outerR: CGFloat = 16 * scale
                let innerR: CGFloat = 7 * scale
                let cx = centerX
                let cy = centerY - 78 * scale + bob
                for i in 0..<(starPts * 2) {
                    let r = (i % 2 == 0) ? outerR : innerR
                    let theta = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(starPts)
                    let x = cx + r * cos(theta)
                    let y = cy + r * sin(theta)
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
                p.closeSubpath()
            }
            ctx.fill(star, with: .color(accent))
            // Head
            let head = CGRect(x: centerX - 18 * scale, y: centerY - 50 * scale + bob, width: 36 * scale, height: 36 * scale)
            ctx.fill(Path(ellipseIn: head), with: .color(accent))
        }
    }
}

private extension Color {
    init(rgba: SIMD4<Float>) {
        self.init(
            .sRGB,
            red: Double(rgba.x),
            green: Double(rgba.y),
            blue: Double(rgba.z),
            opacity: Double(rgba.w)
        )
    }
}
