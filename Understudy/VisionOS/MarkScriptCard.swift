//
//  MarkScriptCard.swift
//  Understudy (visionOS)
//
//  The floating "manuscript page" that sits next to each Mark in the
//  immersive stage. Shows the mark's cues in theatrical type — the script
//  is literally in the room, next to where the action happens.
//
//  Used as a RealityView Attachment keyed by mark.id.raw.
//

#if os(visionOS)
import SwiftUI

struct MarkScriptCard: View {
    let mark: Mark
    /// Whether this mark is the "next" the active performer should walk to —
    /// the card highlights subtly for it.
    var isNext: Bool = false
    /// Number of cues to show at full size before collapsing the rest to a footer.
    var inlineCueLimit: Int = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider().background(.white.opacity(0.25))
            if mark.cues.isEmpty {
                Text("No cues.")
                    .font(.caption.italic())
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                cuesList
            }
        }
        .padding(16)
        .frame(minWidth: 220, maxWidth: 300, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isNext ? Color.red.opacity(0.7) : Color.white.opacity(0.12), lineWidth: isNext ? 2 : 1)
        )
    }

    @ViewBuilder private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(mark.name)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Spacer()
            Text("#\(mark.sequenceIndex + 1)")
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    @ViewBuilder private var cuesList: some View {
        let visible = Array(mark.cues.prefix(inlineCueLimit))
        let overflow = mark.cues.count - visible.count
        VStack(alignment: .leading, spacing: 10) {
            ForEach(visible, id: \.id) { cue in
                cueRow(cue)
            }
            if overflow > 0 {
                Text("+ \(overflow) more cue\(overflow == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder private func cueRow(_ cue: Cue) -> some View {
        switch cue {
        case .line(_, let text, let character):
            VStack(alignment: .leading, spacing: 2) {
                if let c = character {
                    Text(c.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.red.opacity(0.85))
                }
                Text(text)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .sfx(_, let name):
            Label(name, systemImage: "music.note")
                .font(.caption)
                .foregroundStyle(.yellow.opacity(0.85))
        case .light(_, let color, _):
            Label("light: \(color.rawValue)", systemImage: "lightbulb")
                .font(.caption)
                .foregroundStyle(.orange.opacity(0.85))
        case .note(_, let text):
            Text(text)
                .font(.caption.italic())
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        case .wait(_, let seconds):
            Label("hold \(String(format: "%.1f", seconds))s", systemImage: "pause.circle")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
#endif
