//
//  GuidedTourView.swift
//  Understudy (iOS)
//
//  The "hand it to a stranger" experience. A six-stage on-rails interactive
//  demo with very light interaction at each step. Designed to:
//
//    1. Welcome — fade-in title, tap to begin
//    2. Drop — tap a dark area to "place a mark" with a satisfying thud
//    3. Pick — tap one of three sample lines from Hamlet
//    4. Light — pick a colour wash; the screen flashes it
//    5. Hear — tap to "fire the show" — every chosen cue plays in sequence
//    6. Reveal — close with options: keep exploring (Author / Performer mode)
//
//  Each stage is a single SwiftUI screen. The runner state machine knows
//  which stage we're in, what the user has chosen, and advances on tap.
//  All audio + light cues fire through CueFXEngine — same path the real
//  app uses, so the demo's wow moments are the real wow moments.
//
//  Total runtime, generous: 60–75 seconds.
//

#if os(iOS)
import SwiftUI

public struct GuidedTourView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(CueFXEngine.self) private var fx
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appMode") private var appModeRaw: String = AppMode.perform.rawValue
    @AppStorage("hasPickedMode") private var hasPickedMode: Bool = false

    @State private var stage: Stage = .welcome
    @State private var pickedLine: SampleLine? = nil
    @State private var pickedColor: SampleColor? = nil
    @State private var dropPoint: CGPoint? = nil
    @State private var flashOpacity: Double = 0
    @State private var flashColor: Color = .clear
    @State private var titleVisible: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            background

            // Stage-specific content.
            switch stage {
            case .welcome:    welcomeStage
            case .drop:       dropStage
            case .pick:       pickStage
            case .light:      lightStage
            case .hear:       hearStage
            case .reveal:     revealStage
            }

            // Color flash overlay — fires on light pick + during the
            // final play-through.
            Rectangle()
                .fill(flashColor)
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Top-right exit.
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.easeIn(duration: 0.8)) { titleVisible = true } }
    }

    // MARK: - Stages

    enum Stage { case welcome, drop, pick, light, hear, reveal }

    private var background: some View {
        LinearGradient(
            colors: [Color.black, Color(red: 0.10, green: 0.04, blue: 0.18)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    @ViewBuilder private var welcomeStage: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 84))
                .foregroundStyle(.white.opacity(0.85))
                .opacity(titleVisible ? 1 : 0)
                .scaleEffect(titleVisible ? 1 : 0.7)
            Text("Understudy")
                .font(.system(size: 48, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .opacity(titleVisible ? 1 : 0)
            Text("A spatial theatre piece, made in 60 seconds.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(titleVisible ? 1 : 0)
            Spacer()
            Button {
                advance(to: .drop)
            } label: {
                HStack {
                    Text("Begin")
                        .font(.title3.bold())
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.red.opacity(0.85), in: Capsule())
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder private var dropStage: some View {
        ZStack {
            // Big tap target — the "stage floor."
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { p in
                    dropPoint = p
                    fx.preview(.sfx(id: ID(), name: "knock"))
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        advance(to: .pick)
                    }
                }

            // Headline.
            VStack {
                stageBadge(1, of: 6, label: "Drop a mark")
                Spacer()
            }

            VStack(spacing: 16) {
                Spacer()
                Text("Tap anywhere on the stage")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .opacity(dropPoint == nil ? 1 : 0)
                Text("This is how directors place blocking marks in a real room.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(dropPoint == nil ? 1 : 0)
                Spacer()
            }

            // The dropped mark — animates in.
            if let p = dropPoint {
                MarkBurst()
                    .position(p)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: dropPoint)
    }

    @ViewBuilder private var pickStage: some View {
        VStack(spacing: 18) {
            stageBadge(2, of: 6, label: "Pick a line")
            Spacer()
            Text("What does the mark say?")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Three lines from Hamlet's first scene.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                ForEach(SampleLine.allCases) { line in
                    Button {
                        pickedLine = line
                        fx.preview(.line(id: ID(), text: line.text, character: line.character))
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            advance(to: .light)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.character.uppercased())
                                .font(.caption.monospaced())
                                .foregroundStyle(.red.opacity(0.8))
                            Text(line.text)
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            (pickedLine == line ? Color.green : .white.opacity(0.06)),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            Spacer()
        }
    }

    @ViewBuilder private var lightStage: some View {
        VStack(spacing: 18) {
            stageBadge(3, of: 6, label: "Add a light cue")
            Spacer()
            Text("Pick a colour")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Lighting tells the audience how to feel.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)
            Spacer()
            HStack(spacing: 16) {
                ForEach(SampleColor.allCases) { c in
                    Button {
                        pickedColor = c
                        // Flash the screen with the chosen colour.
                        flashColor = c.color
                        withAnimation(.easeOut(duration: 0.1)) { flashOpacity = 0.65 }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            withAnimation(.easeOut(duration: 1.0)) { flashOpacity = 0 }
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            advance(to: .hear)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(c.color)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Circle().stroke(.white.opacity(0.3), lineWidth: 2)
                                )
                                .scaleEffect(pickedColor == c ? 1.15 : 1.0)
                            Text(c.label)
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            Spacer()
        }
    }

    @ViewBuilder private var hearStage: some View {
        VStack(spacing: 18) {
            stageBadge(4, of: 6, label: "Fire the cue")
            Spacer()
            Text("Tap to play your beat")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Light. Sound. Line. The exact same chain that fires when a real performer hits a real mark.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            Button {
                playFinaleChain()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 96))
                    Text("FIRE")
                        .font(.title3.bold().monospaced())
                }
                .foregroundStyle(.white)
                .padding(28)
                .background(Color.red.opacity(0.6), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 2))
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    @ViewBuilder private var revealStage: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            Text("That was one beat.")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("A real show is twenty of those, in your real room, with your cast on iPhones — and a director in Vision Pro watching ghost avatars walk the path.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            VStack(spacing: 12) {
                pathButton(label: "Build your own — tap to drop marks", systemImage: "mappin.and.ellipse", mode: .author)
                pathButton(label: "Walk a finished show", systemImage: "figure.walk", mode: .perform)
                pathButton(label: "Take the audience tour", systemImage: "ear.and.waveform", mode: .audience)
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.body.bold())
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func stageBadge(_ n: Int, of total: Int, label: String) -> some View {
        HStack {
            Text("\(n) / \(total) · \(label)")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func pathButton(label: String, systemImage: String, mode: AppMode) -> some View {
        Button {
            appModeRaw = mode.rawValue
            hasPickedMode = true
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 40)
                Text(label)
                    .font(.body.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.4))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func advance(to next: Stage) {
        withAnimation(.easeInOut(duration: 0.45)) { stage = next }
    }

    /// Plays the user's chosen line + light + sound effect in a tight
    /// chain. This is the "wow" moment of the tour.
    private func playFinaleChain() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // 1. Flash the chosen colour immediately.
        if let c = pickedColor {
            flashColor = c.color
            withAnimation(.easeOut(duration: 0.1)) { flashOpacity = 0.7 }
        }

        // 2. SFX — orchestral hit.
        fx.preview(.sfx(id: ID(), name: "orchestral-hit"))

        // 3. The chosen line.
        if let line = pickedLine {
            fx.preview(.line(id: ID(), text: line.text, character: line.character))
        }

        // 4. Fade the wash, then advance.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation(.easeOut(duration: 1.5)) { flashOpacity = 0 }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            advance(to: .reveal)
        }
    }
}

// MARK: - Sample picks

private enum SampleLine: String, CaseIterable, Identifiable, Equatable {
    case whosThere
    case beShakespeare
    case lookGhost

    var id: String { rawValue }
    var character: String {
        switch self {
        case .whosThere:     return "BERNARDO"
        case .beShakespeare: return "HAMLET"
        case .lookGhost:     return "BERNARDO"
        }
    }
    var text: String {
        switch self {
        case .whosThere:     return "Who's there?"
        case .beShakespeare: return "To be, or not to be — that is the question."
        case .lookGhost:     return "Look, where it comes again."
        }
    }
}

private enum SampleColor: String, CaseIterable, Identifiable, Equatable {
    case warm, cool, amber, blue
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .warm:  return Color(red: 1.0, green: 0.85, blue: 0.55)
        case .cool:  return Color(red: 0.55, green: 0.85, blue: 1.0)
        case .amber: return Color(red: 1.0, green: 0.75, blue: 0.2)
        case .blue:  return .blue
        }
    }
}

// MARK: - Mark drop animation

private struct MarkBurst: View {
    @State private var burstScale: CGFloat = 0
    @State private var burstOpacity: Double = 1
    @State private var coreScale: CGFloat = 0

    var body: some View {
        ZStack {
            // Outer ring expansion
            Circle()
                .stroke(Color.cyan.opacity(0.85), lineWidth: 3)
                .frame(width: 60, height: 60)
                .scaleEffect(burstScale)
                .opacity(burstOpacity)
            // Inner solid disc
            Circle()
                .fill(Color.cyan.opacity(0.55))
                .frame(width: 52, height: 52)
                .scaleEffect(coreScale)
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .scaleEffect(coreScale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                coreScale = 1.0
            }
            withAnimation(.easeOut(duration: 1.2)) {
                burstScale = 4.0
                burstOpacity = 0
            }
        }
    }
}
#endif
