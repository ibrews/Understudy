//
//  ShowMetricsView.swift
//  Understudy
//
//  Glance dashboard for the current blocking. The kind of overview a
//  director or stage manager wants the morning of rehearsal:
//
//    • Total marks, total cues, breakdown by cue type
//    • Estimated runtime (sum of waits + lines × theatrical pace)
//    • Per-character line counts (who has the most stage time)
//    • Missing-cue warnings ("Mark 5 has no line, no SFX, no light — intentional?")
//    • Calibration health across connected peers
//
//  Surfaced from the Director Panel and (on iPhone) from Settings.
//  Read-only. No mutating actions — this is a planning view.
//

import SwiftUI

public struct ShowMetricsView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                summarySection
                cueBreakdownSection
                runtimeSection
                charactersSection
                warningsSection
                peersSection
            }
            .navigationTitle("Show Stats")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    @ViewBuilder private var summarySection: some View {
        Section("Summary") {
            statRow("Title", store.blocking.title)
            statRow("Marks", "\(store.blocking.marks.count)")
            statRow("Actor marks", "\(actorMarks.count)")
            statRow("Camera marks", "\(cameraMarks.count)")
            statRow("Total cues", "\(totalCues)")
            statRow("Props", "\(store.blocking.props.count)")
        }
    }

    @ViewBuilder private var cueBreakdownSection: some View {
        Section("Cue breakdown") {
            cueRow("Lines", count: lineCount, color: .red)
            cueRow("Sound", count: sfxCount, color: .yellow)
            cueRow("Light", count: lightCount, color: .orange)
            cueRow("Hold (wait)", count: waitCount, color: .blue)
            cueRow("Director notes", count: noteCount, color: .gray)
        }
    }

    @ViewBuilder private var runtimeSection: some View {
        Section {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(estimatedRuntimeFormatted)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(.primary)
                    Text("Theatrical pace, all cues fired in order")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            statRow("Lines", String(format: "%.0fs", lineTime))
            statRow("Holds", String(format: "%.0fs", holdTime))
            statRow("Cue dwells", String(format: "%.0fs", dwellTime))
        } header: { Text("Estimated runtime") } footer: {
            Text("Estimate uses ~14 chars/sec for spoken lines, plus the sum of all hold cues, plus a 1.5s dwell per non-line cue. Real performances run shorter (skipped cues) or longer (audience response) — calibrate against your first run-through.")
                .font(.caption)
        }
    }

    @ViewBuilder private var charactersSection: some View {
        Section {
            if characterLineCounts.isEmpty {
                Text("No spoken lines yet. Add a `.line` cue with a character name to track stage time.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(characterLineCounts.sorted(by: { $0.value > $1.value }), id: \.key) { entry in
                    HStack {
                        Text(entry.key.uppercased())
                            .font(.caption.monospaced())
                            .foregroundStyle(.red)
                        Spacer()
                        Text("\(entry.value) line\(entry.value == 1 ? "" : "s")")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            }
        } header: { Text("Cast") } footer: {
            Text("Helps spot imbalances — if Hamlet has 87 lines and Bernardo has 4 in this blocking, the rehearsal calendar should reflect that.")
                .font(.caption)
        }
    }

    @ViewBuilder private var warningsSection: some View {
        Section("Warnings") {
            if warnings.isEmpty {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("No issues found.")
                }
                .font(.callout)
            } else {
                ForEach(warnings, id: \.self) { w in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(w).font(.callout)
                    }
                }
            }
        }
    }

    @ViewBuilder private var peersSection: some View {
        Section {
            if store.performers.isEmpty {
                Text("No connected performers.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.performers, id: \.id) { perf in
                    HStack {
                        Image(systemName: perf.role == .director ? "eyeglasses" : (perf.role == .observer ? "ear" : "figure.walk"))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(perf.displayName).font(.headline)
                                if perf.id == store.localPerformerID {
                                    Text("YOU")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Color.green.opacity(0.3), in: Capsule())
                                }
                            }
                            Text("Role: \(perf.role.rawValue) · tracking \(trackingLabel(perf.trackingQuality))")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Circle()
                            .fill(perf.trackingQuality > 0.6 ? Color.green : .orange)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        } header: {
            HStack {
                Text("Connected (\(store.performers.count))")
                Spacer()
                Text("Room: \(session.roomCode) · \(session.peerCount) peers")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        } footer: {
            Text("Tracking quality reads device confidence in its AR pose — green when ARKit/ARCore have a strong lock, orange when calibration may have drifted.")
                .font(.caption)
        }
    }

    // MARK: - Helpers

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.monospacedDigit())
        }
    }

    private func cueRow(_ label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text("\(count)").font(.body.monospacedDigit())
        }
    }

    private func trackingLabel(_ q: Float) -> String {
        if q > 0.8 { return "good" }
        if q > 0.4 { return "limited" }
        return "lost"
    }

    // MARK: - Derived

    private var actorMarks: [Mark] { store.blocking.marks.filter { $0.kind == .actor } }
    private var cameraMarks: [Mark] { store.blocking.marks.filter { $0.kind == .camera } }
    private var allCues: [Cue] { store.blocking.marks.flatMap(\.cues) }
    private var totalCues: Int { allCues.count }

    private var lineCount: Int { allCues.filter { if case .line = $0 { return true } else { return false } }.count }
    private var sfxCount: Int { allCues.filter { if case .sfx = $0 { return true } else { return false } }.count }
    private var lightCount: Int { allCues.filter { if case .light = $0 { return true } else { return false } }.count }
    private var waitCount: Int { allCues.filter { if case .wait = $0 { return true } else { return false } }.count }
    private var noteCount: Int { allCues.filter { if case .note = $0 { return true } else { return false } }.count }

    private var lineTime: Double {
        allCues.reduce(into: 0) { acc, cue in
            if case .line(_, let text, _) = cue {
                acc += max(1.8, Double(text.count) / 14.0)
            }
        }
    }
    private var holdTime: Double {
        allCues.reduce(into: 0) { acc, cue in
            if case .wait(_, let s) = cue { acc += s }
        }
    }
    private var dwellTime: Double {
        // 1.5s per non-line, non-wait cue (sfx, light, note).
        Double(sfxCount + lightCount + noteCount) * 1.5
    }
    private var totalRuntime: Double { lineTime + holdTime + dwellTime }
    private var estimatedRuntimeFormatted: String {
        let s = Int(totalRuntime)
        if s >= 60 {
            return String(format: "%dm %02ds", s / 60, s % 60)
        }
        return "\(s)s"
    }

    /// Map character names → number of `.line` cues attributed to them.
    private var characterLineCounts: [String: Int] {
        var map: [String: Int] = [:]
        for cue in allCues {
            if case .line(_, _, let c) = cue, let name = c, !name.isEmpty {
                map[name, default: 0] += 1
            }
        }
        return map
    }

    private var warnings: [String] {
        var w: [String] = []
        let actor = actorMarks.sorted { $0.sequenceIndex < $1.sequenceIndex }

        // Marks with zero cues — likely intentional (a hold) or missing content.
        let emptyMarks = actor.filter { $0.cues.isEmpty }
        if !emptyMarks.isEmpty {
            let names = emptyMarks.map(\.name).joined(separator: ", ")
            w.append("\(emptyMarks.count) actor mark\(emptyMarks.count == 1 ? "" : "s") with no cues: \(names). Add a line, sound, or hold so something happens when the performer arrives.")
        }

        // Sequence gaps — sequenceIndex should run 0,1,2,3… without gaps.
        if !actor.isEmpty {
            let indices = actor.map(\.sequenceIndex).sorted()
            for i in 0..<indices.count {
                if indices[i] != i {
                    w.append("Sequence indices have a gap: expected \(i), got \(indices[i]). This can confuse 'next mark' navigation.")
                    break
                }
            }
        }

        // Lines with no character name — cast assignment is unclear.
        let unnamedLines = allCues.compactMap { cue -> Cue? in
            if case .line(_, _, let c) = cue, c?.isEmpty != false { return cue }
            return nil
        }
        if !unnamedLines.isEmpty {
            w.append("\(unnamedLines.count) line cue\(unnamedLines.count == 1 ? "" : "s") with no character name. Performer teleprompter shows them but there's no speaker label.")
        }

        // Lighting cues that never get cleared — common cause of "stuck wash."
        let lights = allCues.compactMap { cue -> LightColor? in
            if case .light(_, let color, _) = cue { return color } else { return nil }
        }
        if !lights.isEmpty && !lights.contains(.blackout) {
            w.append("No `.light(blackout)` cue anywhere. Without a final blackout, the last wash holds after the show ends.")
        }

        // Camera marks without a CameraSpec — UI shows fallback default.
        let cameraNoSpec = cameraMarks.filter { $0.camera == nil }
        if !cameraNoSpec.isEmpty {
            w.append("\(cameraNoSpec.count) camera mark\(cameraNoSpec.count == 1 ? "" : "s") with no lens spec. They render as a default 35mm; edit each to set the real focal length.")
        }

        // No reference walk recorded — Audience mode + ghost playback won't work.
        if store.blocking.reference == nil && actor.count >= 3 {
            w.append("No reference walk recorded. Hit the red record button in Perform mode and walk the path once so audiences and late-joining performers can chase a ghost.")
        }

        return w
    }
}
