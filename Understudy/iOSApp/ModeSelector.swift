//
//  ModeSelector.swift
//  Understudy (iOS)
//
//  First-launch role picker. Three big cards — Perform, Author, Audience —
//  with brief taglines. The choice is sticky (AppStorage) but always
//  re-reachable from Settings.
//

#if os(iOS)
import SwiftUI

struct ModeSelector: View {
    @AppStorage("appMode") private var appModeRaw: String = ""
    @AppStorage("hasPickedMode") private var hasPickedMode: Bool = false
    @State private var showingDemoLauncher = false
    @State private var showingGuidedTour = false
    var onPicked: (AppMode) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.18, green: 0.03, blue: 0.05)],
                startPoint: .bottom, endPoint: .top
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                header
                Spacer(minLength: 12)
                VStack(spacing: 14) {
                    ForEach(AppMode.allCases, id: \.self) { mode in
                        ModeCard(mode: mode) {
                            pick(mode)
                        }
                    }
                }
                // Headline CTA — the on-rails interactive tour for absolute
                // newcomers. Designed to be handed to a stranger at a
                // conference booth and produce a "wow" moment in 60 seconds.
                Button {
                    showingGuidedTour = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Try the 60-second tour")
                                .font(.headline)
                            Text("New here? Tap-tap-tap — feel what Understudy does.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.callout)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color.purple.opacity(0.85), Color.red.opacity(0.65)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                // Secondary: the auto-play showcase library.
                Button {
                    showingDemoLauncher = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles.tv.fill")
                            .font(.callout)
                        Text("Browse showcase demos")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
                footer
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingGuidedTour) {
            GuidedTourView()
        }
        .sheet(isPresented: $showingDemoLauncher) {
            DemoLauncherView()
        }
    }

    private func pick(_ mode: AppMode) {
        appModeRaw = mode.rawValue
        hasPickedMode = true
        onPicked(mode)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.9))
            Text("Understudy")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text("What brings you to the stage?")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var footer: some View {
        Text("You can switch modes anytime from Settings.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.4))
    }
}

private struct ModeCard: View {
    let mode: AppMode
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .frame(width: 54, alignment: .center)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(mode.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
