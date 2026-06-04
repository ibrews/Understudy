//
//  DirectorOnboardingView.swift
//  Understudy (visionOS)
//
//  First-run flow for the Vision Pro director. The #1 product gap was that a
//  brand-new director is dropped into a dense panel + an immersive space with
//  no explanation of the spatial model. This teaches the whole loop — open the
//  stage, place marks, fire cues, bring in the cast — and is re-reachable from
//  the panel's "Tutorial" button (critical when the headset is handed to a
//  second person).
//
//  Manual paging (not TabView/.page) so there's no PageTabViewStyle
//  availability dependency.
//

#if os(visionOS)
import SwiftUI

struct DirectorOnboardingView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenDirectorIntro") private var hasSeenDirectorIntro = false

    @State private var page = 0

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let steps: [Step] = [
        Step(icon: "theatermasks.fill",
             title: "Welcome to Understudy",
             body: "You're the director. Your stage appears right here in your room — performers join from their iPhones and follow the marks and cues you set."),
        Step(icon: "cube.transparent",
             title: "Your stage is open",
             body: "A glowing disc marks the stage center, with a soft outline for the playing area. Toggle the stage with Open / Close, and switch Mixed ↔ Full space from the panel anytime."),
        Step(icon: "hand.tap.fill",
             title: "Drop blocking marks",
             body: "Look at the floor and pinch to place a mark — each one is a position your actors hit. Turn on Snap to align them to the stage grid."),
        Step(icon: "play.circle.fill",
             title: "Add cues, then GO",
             body: "Pinch a mark to attach a line, a light, or a sound. Press GO (or your controller trigger) to fire the next cue — performers' phones respond instantly."),
        Step(icon: "person.2.wave.2.fill",
             title: "Bring in your cast",
             body: "Share your room code so iPhones can join, then point performers at the QR Target so everyone shares the same stage origin."),
    ]

    private var isLastPage: Bool { page == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            stepPage(steps[page])
                .id(page) // re-identify so the transition fires per page
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            pageDots
                .padding(.bottom, 8)

            footerBar
        }
        .frame(minWidth: 520, minHeight: 600)
        .interactiveDismissDisabled(false)
    }

    @ViewBuilder private func stepPage(_ step: Step) -> some View {
        VStack(spacing: 20) {
            Image(systemName: step.icon)
                .font(.system(size: 68))
                .foregroundStyle(.tint)
                .padding(.top, 48)
                .accessibilityHidden(true)

            Text(step.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(step.body)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
                .fixedSize(horizontal: false, vertical: true)

            if isLastPage {
                Label("Room code: \(session.roomCode)", systemImage: "number")
                    .font(.title3.monospaced().weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title). \(step.body)")
    }

    @ViewBuilder private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { i in
                Circle()
                    .fill(i == page ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("Step \(page + 1) of \(steps.count)")
    }

    @ViewBuilder private var footerBar: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button { withAnimation { page -= 1 } } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            } else {
                Button("Skip") { finish() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLastPage {
                Button { clearMarks(); finish() } label: {
                    Label("Start Fresh", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .help("Clear the sample show so you can place your own marks.")

                Button { finish() } label: {
                    Label("Explore Sample", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button { withAnimation { page += 1 } } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private func finish() {
        hasSeenDirectorIntro = true
        dismiss()
    }

    /// "Start Fresh" — clear the seeded sample so the in-space "tap the floor"
    /// hint fires and the director places their own marks. Mirrors the panel's
    /// Clear Stage action (broadcast + autosave).
    private func clearMarks() {
        for m in store.blocking.marks { session.broadcastMarkRemoved(m.id) }
        store.blocking.marks.removeAll()
        store.blocking.modifiedAt = Date()
        BlockingAutosave.save(store.blocking)
    }
}
#endif
