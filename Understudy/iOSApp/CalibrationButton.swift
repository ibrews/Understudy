//
//  CalibrationButton.swift
//  Understudy (iOS)
//
//  Small compass button in the top bar of every iPhone mode. Tap to set
//  the current pose as the shared blocking origin for this session.
//  When calibrated, the compass is green + shows a time-since-calibration
//  caption on long-press. Uncalibrated = amber, hinting "tap me."
//

#if os(iOS)
import SwiftUI
import Combine

struct CalibrationButton: View {
    @Environment(BlockingStore.self) private var store
    @State private var tick: Date = Date()
    @State private var confirmClear = false
    @State private var justCalibrated = false

    /// We poll a cheap wall-clock timer to refresh the calibration-age label
    /// and re-read PerformerARHost.shared.calibration (which is outside the
    /// Observable world and doesn't auto-republish).
    private let pollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        let calibrated = PerformerARHost.shared.calibration != nil
        Menu {
            Button {
                calibrateNow()
            } label: {
                Label(calibrated ? "Re-calibrate here" : "Set origin here",
                      systemImage: "scope")
            }
            if calibrated {
                Button(role: .destructive) {
                    confirmClear = true
                } label: {
                    Label("Clear calibration", systemImage: "xmark.circle")
                }
            }
            Section {
                Text(helpText(calibrated: calibrated))
            }
        } label: {
            ZStack {
                Image(systemName: calibrated ? "location.north.circle.fill" : "location.north.circle")
                    .font(.title3)
                    .foregroundStyle(calibrated ? Color.green : Color.orange)
                    .padding(10)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay {
                        if justCalibrated {
                            Circle()
                                .stroke(Color.green, lineWidth: 2)
                                .scaleEffect(1.6)
                                .opacity(0)
                                .animation(.easeOut(duration: 0.6), value: justCalibrated)
                        }
                    }
            }
        }
        .onReceive(pollTimer) { _ in tick = Date() }
        .alert("Clear calibration?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                PerformerARHost.shared.clearCalibration()
            }
        } message: {
            Text("Poses will go back to each device's raw AR frame. Multi-device rehearsals won't share a coordinate system until you re-calibrate.")
        }
    }

    private func calibrateNow() {
        let ok = PerformerARHost.shared.calibrateAtCurrentPose()
        if ok {
            withAnimation(.easeOut(duration: 0.4)) { justCalibrated = true }
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation { justCalibrated = false }
            }
        }
    }

    private func helpText(calibrated: Bool) -> String {
        if calibrated, let cal = PerformerARHost.shared.calibration {
            let age = Int(Date().timeIntervalSince(cal.capturedAt))
            return "Calibrated \(age)s ago. Stand at agreed stage center, face upstage, and re-calibrate if anyone drifts."
        } else {
            return "Stand at the agreed stage-center position, face upstage, and tap to set this spot as the shared blocking origin."
        }
    }
}
#endif
