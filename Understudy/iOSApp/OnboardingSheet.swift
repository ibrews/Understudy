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
                    body: "A guidance ring shows how far you are from your next mark. Walk until the ring shrinks to zero — your phone pulses when you arrive."
                ),
                OnboardingStep(
                    icon: "text.quote",
                    title: "Follow the script",
                    body: "Tap the quote button at the top to open the teleprompter. Lines scroll automatically, or speak them and voice-mode follows your pace."
                ),
                OnboardingStep(
                    icon: "list.bullet",
                    title: "See the whole show",
                    body: "Tap the list button to see every mark in order. Tap any mark to fire its cues right now — perfect for a quick run-through without walking."
                ),
                OnboardingStep(
                    icon: "person.2.wave.2",
                    title: "Joining a director's show?",
                    body: "Tap the room status at the top of the screen and enter the code your director shares. You'll connect to their stage and follow their cues live."
                ),
            ]
        case .author:
            return [
                OnboardingStep(
                    icon: "hand.tap",
                    title: "Tap the floor to drop a mark",
                    body: "Point your phone at the floor and tap anywhere to place a blocking mark there. The mark appears as a glowing disc you can walk back to later."
                ),
                OnboardingStep(
                    icon: "music.note.list",
                    title: "Add cues to each mark",
                    body: "Tap any mark on the floor to open its editor. Add dialogue lines, sound effects, lighting cues — or pick a line straight from one of the ten bundled plays."
                ),
                OnboardingStep(
                    icon: "camera.aperture",
                    title: "Camera marks for film",
                    body: "Switch the Drop toggle from Actor to Camera. A live viewfinder overlay shows what each lens (14–135 mm) would frame from that spot — walk the room as a virtual scout."
                ),
            ]
        case .audience:
            return [
                OnboardingStep(
                    icon: "figure.walk",
                    title: "Walk the show yourself",
                    body: "Audience mode turns a finished blocking into a self-paced AR tour. The phone guides you from mark to mark — your lines, sounds, and lights play as you arrive."
                ),
                OnboardingStep(
                    icon: "hand.tap",
                    title: "Or tap to scrub",
                    body: "Tap any spot on the progress bar to jump to that beat — handy when you want to revisit a moment or experience the show from a different starting point."
                ),
                OnboardingStep(
                    icon: "person.2.wave.2",
                    title: "Joining a live show",
                    body: "Walking a director's live blocking? Open Settings → Room and enter the room code they share. You'll see performers on the same stage in real time."
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
