//
//  OnboardingSheet.swift
//  Understudy (iOS)
//
//  First-time role onboarding: a quick 3-step card walk that fires once per
//  role. Each step has an icon, headline, and one sentence of guidance.
//  Shown as a sheet on first entry into Perform, Author, or Audience mode.
//

#if os(iOS)
import SwiftUI

struct OnboardingSheet: View {
    let mode: AppMode
    var onDismiss: () -> Void

    @State private var page = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.10, green: 0.05, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Mode badge
                HStack(spacing: 8) {
                    Image(systemName: mode.systemImage)
                        .font(.callout)
                    Text(mode.displayName.uppercased())
                        .font(.caption.bold().monospaced())
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 32)

                Text("Getting started")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
                    .padding(.bottom, 32)

                // Step cards
                TabView(selection: $page) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        StepCard(step: step)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 280)

                Spacer()

                Button {
                    if page < steps.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onDismiss()
                    }
                } label: {
                    Text(page < steps.count - 1 ? "Next" : "Got it, let's go!")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var steps: [OnboardingStep] {
        switch mode {
        case .perform:
            return [
                OnboardingStep(
                    icon: "scope",
                    title: "Find your mark",
                    body: "A guidance ring shows how far you are from your next mark. Walk until the ring shrinks to zero."
                ),
                OnboardingStep(
                    icon: "text.aligncenter",
                    title: "Follow the script",
                    body: "Tap the ≡ button to open the teleprompter. Your lines scroll automatically, or you can drag to follow along."
                ),
                OnboardingStep(
                    icon: "camera.viewfinder",
                    title: "Marks are on the floor",
                    body: "With AR enabled, glowing discs appear on the stage floor — one per blocking position. Walk to each one in order."
                ),
            ]
        case .author:
            return [
                OnboardingStep(
                    icon: "mappin.and.ellipse",
                    title: "Drop marks where you stand",
                    body: "Walk to each blocking position and tap the ⊕ button to drop a mark at your feet."
                ),
                OnboardingStep(
                    icon: "music.note.list",
                    title: "Add cues to each mark",
                    body: "Tap any mark disc on the floor to open it. Add dialogue lines, sound effects, or lighting cues."
                ),
                OnboardingStep(
                    icon: "camera.aperture",
                    title: "Set up camera framing",
                    body: "Switch to Camera mode to choose a focal length and lock in the shot composition for each mark."
                ),
            ]
        case .audience:
            return [
                OnboardingStep(
                    icon: "person.2.wave.2",
                    title: "Join the session",
                    body: "Your director will share a room code. Enter it in Settings → Room to sync with the live blocking."
                ),
                OnboardingStep(
                    icon: "mappin",
                    title: "See where performers are",
                    body: "Mark positions appear on your screen in real time as performers walk their blocking."
                ),
                OnboardingStep(
                    icon: "bell",
                    title: "Receive cue notifications",
                    body: "Sound, lighting, and dialogue cues fire as performers hit their marks — you'll feel the show come alive."
                ),
            ]
        }
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let body: String
}

private struct StepCard: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: step.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text(step.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(step.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

#endif
