//
//  DemoLauncherView.swift
//  Understudy
//
//  Sheet/window UI for launching one of the curated showcase demos.
//  Cross-platform: same view works on iPhone (presented as a sheet) and
//  visionOS (presented as a sheet from the Director Panel).
//
//  Three cards, each with title + blurb + estimated runtime + a Run button.
//  Replaces the current blocking with the showcase one for the duration of
//  the demo, restored on stop().
//

import SwiftUI

public struct DemoLauncherView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(CueFXEngine.self) private var fx
    @Environment(SessionController.self) private var session
    @Environment(DemoRunner.self) private var runner
    @Environment(\.dismiss) private var dismiss

    @State private var showingGuidedTour = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    #if os(iOS)
                    GuidedTourCard {
                        showingGuidedTour = true
                    }
                    #endif

                    ForEach(DemoBlockings.allShowcases) { entry in
                        ShowcaseCard(entry: entry) {
                            launch(entry)
                        }
                    }

                    if runner.isActive {
                        runnerStatus
                    }

                    Spacer(minLength: 24)
                    footer
                }
                .padding(24)
            }
            .navigationTitle("Run Demo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                if runner.isActive {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Stop") { runner.stop() }
                            .tint(.red)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick a showcase. Walks through every cue with theatrical timing — works as your demo at FMX, in a London pub, or on a producer's iPad.")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Your current blocking is restored when you tap Stop.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var runnerStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Now playing")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            switch runner.phase {
            case .openingTitle(let t, _):
                Text("Opening: \(t)")
                    .font(.headline)
            case .running(let i, let n):
                if let name = runner.currentMarkName {
                    Text("Beat \(i + 1) of \(n) · \(name)")
                        .font(.headline)
                }
                if let cb = runner.currentMarkBlurb {
                    Text(cb).font(.body).foregroundStyle(.primary)
                }
                if let cl = runner.calloutText {
                    Label(cl, systemImage: "info.circle")
                        .font(.caption.monospaced())
                        .foregroundStyle(.cyan)
                }
            case .closingTitle:
                Text("Wrapping up…").font(.headline)
            case .finished:
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .idle:
                EmptyView()
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Tip: tap Open Stage in the Director Panel before launching the visionOS theater demo so the immersive lights + ghost flashes register.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func launch(_ entry: DemoBlockings.ShowcaseEntry) {
        runner.start(showcase: entry, store: store, fx: fx, sessionController: session)
    }
}

#if os(iOS)
extension DemoLauncherView {
    var guidedTourSheet: some View {
        EmptyView()
    }
}

/// Highlighted card on top of the demo launcher — kicks off the on-rails
/// 60-second interactive tour. The tour replaces tap-the-floor with an
/// SwiftUI tap and is designed to be handed to a stranger.
struct GuidedTourCard: View {
    let onTap: () -> Void
    @State private var showingTour = false

    var body: some View {
        Button {
            showingTour = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("60-second Guided Tour")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Hand it to a stranger.")
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.4))
                }
                Text("On-rails interactive walkthrough — drop a mark, pick a line, fire the cue. Six steps, ~60 seconds, ends with one tap to enter Author or Performer mode.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.purple.opacity(0.7), Color.red.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingTour) {
            GuidedTourView()
        }
    }
}
#endif

// MARK: - Card

private struct ShowcaseCard: View {
    let entry: DemoBlockings.ShowcaseEntry
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: entry.systemImage)
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("≈ \(entry.estimatedSeconds)s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            Text(entry.blurb)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
            HStack {
                Spacer()
                Button {
                    onRun()
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Demo overlay (visible whenever the runner is active)

/// A floating banner with title card / current-beat / callout that should
/// be overlaid on top of every screen while a demo is running. Visually
/// distinct so a presenter can keep it on while showing other UI.
public struct DemoRunnerOverlay: View {
    @Environment(DemoRunner.self) private var runner

    public init() {}

    public var body: some View {
        Group {
            switch runner.phase {
            case .openingTitle(let t, let s):
                titleCard(big: t, small: s, accent: .green)
            case .closingTitle(let t, let s):
                titleCard(big: t, small: s, accent: .blue)
            case .running:
                runningBanner
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.5), value: runner.phase)
        .allowsHitTesting(false)
    }

    @ViewBuilder private func titleCard(big: String, small: String, accent: Color) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Text(big)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(small)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(accent.opacity(0.5), lineWidth: 2)
            )
            .padding(.horizontal, 24)
            Spacer()
        }
        .background(.black.opacity(0.45))
        .transition(.opacity)
    }

    @ViewBuilder private var runningBanner: some View {
        VStack {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("DEMO")
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(.white)
                if case .running(let i, let n) = runner.phase {
                    Text("· beat \(i + 1)/\(n)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                }
                if let name = runner.currentMarkName {
                    Text("·  \(name)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let callout = runner.calloutText {
                    Text("·  \(callout)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.black.opacity(0.6), in: Capsule())
            .padding(.top, 8)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
