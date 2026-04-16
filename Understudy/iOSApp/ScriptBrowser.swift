//
//  ScriptBrowser.swift
//  Understudy
//
//  Sheet that opens from the mark editor (Author mode on iPhone, MarkEditor
//  on visionOS). Shows the full bundled Hamlet so the user can tap a line
//  and have it appear as a `.line(...)` cue on the mark they're editing.
//
//  Design:
//    - Search bar filters lines by character or text, case-insensitive
//    - List is grouped by Scene with a dark serif header and location caption
//    - Each row shows the character label (uppercase monospace red) above
//      the line text (serif body)
//    - Lines already present on the current mark show a checkmark
//    - Tapping a row adds (or removes) the line from the current mark's
//      cues without dismissing the sheet — stage managers paste multiple
//      lines in a burst and don't want to reopen the sheet every time
//

import SwiftUI

struct ScriptBrowser: View {
    @Environment(\.dismiss) private var dismiss

    /// The mark currently being edited. Selected lines are appended to /
    /// removed from its `cues` in place.
    @Binding var mark: Mark

    /// Which script to browse. Today just Hamlet; future scripts can be
    /// selected via `Scripts.all`.
    @State private var script: PlayScript = Scripts.hamlet
    @State private var query: String = ""
    @State private var sceneFilter: SceneFilter = .all
    @FocusState private var searchFocused: Bool

    enum SceneFilter: Hashable, Identifiable {
        case all
        case scene(act: Int, scene: Int)
        var id: String {
            switch self {
            case .all: return "all"
            case .scene(let a, let s): return "\(a).\(s)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider().background(.white.opacity(0.1))
                content
            }
            .background(Color.black)
            .navigationTitle(script.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Picker("Scene", selection: $sceneFilter) {
                            Text("All scenes").tag(SceneFilter.all)
                            ForEach(script.acts, id: \.number) { act in
                                Section("Act \(act.roman)") {
                                    ForEach(act.scenes, id: \.number) { scene in
                                        Text("Scene \(scene.roman) — \(scene.location)")
                                            .tag(SceneFilter.scene(act: act.number, scene: scene.number))
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.5))
                TextField("Find a line or character", text: $query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .focused($searchFocused)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Text("\(filteredCount) lines")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(mark.cues.filter { if case .line = $0 { return true }; return false }.count) on this mark")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.black)
    }

    private var filteredCount: Int {
        script.linesMatching(query).filter { matchesSceneFilter($0) }.count
    }

    // MARK: - List

    @ViewBuilder private var content: some View {
        if script.acts.isEmpty {
            ContentUnavailableView(
                "No script bundled",
                systemImage: "doc.text",
                description: Text("hamlet.json was not found in the app bundle.")
            )
        } else if filteredLines.isEmpty {
            ContentUnavailableView(
                "No matches",
                systemImage: "magnifyingglass",
                description: Text("Try a shorter query or clear the filter.")
            )
        } else {
            List {
                ForEach(groupedBySceneKeys, id: \.self) { key in
                    let group = groupedByScene[key] ?? []
                    Section {
                        ForEach(group, id: \.id) { line in
                            ScriptLineRow(
                                line: line,
                                isOnMark: lineIsOnCurrentMark(line),
                                onTap: { toggle(line) }
                            )
                            .listRowBackground(Color.black)
                            .listRowSeparatorTint(.white.opacity(0.08))
                        }
                    } header: {
                        ScriptSceneHeader(
                            actRoman: group.first?.actRoman ?? "",
                            sceneRoman: group.first?.sceneRoman ?? "",
                            location: group.first?.location ?? ""
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
        }
    }

    private var filteredLines: [PlayScript.LocatedLine] {
        script.linesMatching(query).filter { matchesSceneFilter($0) }
    }

    private func matchesSceneFilter(_ line: PlayScript.LocatedLine) -> Bool {
        switch sceneFilter {
        case .all: return true
        case .scene(let a, let s):
            // lineID format: "<act>.<scene>.<n>"
            let parts = line.lineID.split(separator: ".")
            return parts.count == 3
                && Int(parts[0]) == a
                && Int(parts[1]) == s
        }
    }

    private var groupedByScene: [String: [PlayScript.LocatedLine]] {
        Dictionary(grouping: filteredLines) { "\($0.actRoman).\($0.sceneRoman)" }
    }

    private var groupedBySceneKeys: [String] {
        // Preserve script order by pulling the first line's scene key in order.
        var seen = Set<String>()
        var order: [String] = []
        for line in filteredLines {
            let key = "\(line.actRoman).\(line.sceneRoman)"
            if seen.insert(key).inserted { order.append(key) }
        }
        return order
    }

    // MARK: - Mark cue manipulation

    private func lineIsOnCurrentMark(_ line: PlayScript.LocatedLine) -> Bool {
        mark.cues.contains { cue in
            if case .line(_, let text, let character) = cue {
                return text == line.text && character == line.character
            }
            return false
        }
    }

    private func toggle(_ line: PlayScript.LocatedLine) {
        if lineIsOnCurrentMark(line) {
            // Remove the first matching line cue.
            for (i, cue) in mark.cues.enumerated() {
                if case .line(_, let text, let character) = cue,
                   text == line.text && character == line.character {
                    mark.cues.remove(at: i)
                    break
                }
            }
        } else {
            mark.cues.append(.line(
                id: ID(),
                text: line.text,
                character: line.character
            ))
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
        }
    }
}

// MARK: - Row + header

private struct ScriptLineRow: View {
    let line: PlayScript.LocatedLine
    let isOnMark: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(line.character)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(Color.red.opacity(0.85))
                    Text(line.text)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: isOnMark ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isOnMark ? Color.green : Color.white.opacity(0.35))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ScriptSceneHeader: View {
    let actRoman: String
    let sceneRoman: String
    let location: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Act \(actRoman)  •  Scene \(sceneRoman)")
                .font(.caption.monospaced().bold())
                .foregroundStyle(.white.opacity(0.65))
            Text(location)
                .font(.caption.italic())
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .textCase(nil)
    }
}
