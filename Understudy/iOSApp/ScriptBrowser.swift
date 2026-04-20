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
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session

    /// The mark currently being edited. Selected lines are appended to /
    /// removed from its `cues` in place.
    @Binding var mark: Mark

    /// Which script to browse. Today just Hamlet; future scripts can be
    /// selected via `Scripts.all`.
    @State private var script: PlayScript = Scripts.hamlet
    @State private var allScripts: [PlayScript] = [Scripts.hamlet]
    @State private var query: String = ""
    @State private var sceneFilter: SceneFilter = .all
    @FocusState private var searchFocused: Bool
    @State private var droppingScene: PlayScript.Scene?

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
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(allScripts, id: \.title) { s in
                                Button {
                                    script = s
                                    sceneFilter = .all
                                } label: {
                                    HStack {
                                        Text(s.title)
                                        if s.title == script.title {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "books.vertical")
                        }
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
            }
            .preferredColorScheme(.dark)
            .task {
                let loaded = await Task.detached(priority: .userInitiated) {
                    Scripts.all
                }.value
                allScripts = loaded
            }
            .alert(
                "Drop whole scene?",
                isPresented: Binding(
                    get: { droppingScene != nil },
                    set: { if !$0 { droppingScene = nil } }
                ),
                presenting: droppingScene
            ) { scene in
                Button("Drop \(beatCount(for: scene)) marks", role: .destructive) {
                    dropScene(scene)
                }
                Button("Cancel", role: .cancel) {}
            } message: { scene in
                Text("Adds marks in front of your current pose arranged in a zig-zag path, pre-populated with the lines from \"\(scene.location)\".")
            }
        }
    }

    private func beatCount(for scene: PlayScript.Scene) -> Int {
        // Ballpark preview; matches ScenePlacer's bucket() logic.
        ScenePlacer.layout(
            scene: scene,
            origin: Pose(),
            sequenceOffset: 0
        ).count
    }

    private func dropScene(_ scene: PlayScript.Scene) {
        let origin = store.localPerformer?.pose ?? Pose()
        let nextIndex = (store.blocking.marks.map(\.sequenceIndex).max() ?? -1) + 1
        let newMarks = ScenePlacer.layout(
            scene: scene,
            origin: origin,
            sequenceOffset: nextIndex
        )
        for mark in newMarks {
            store.addMark(mark)
            session.broadcastMarkAdded(mark)
        }
        dismiss()
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
                        HStack(alignment: .bottom) {
                            ScriptSceneHeader(
                                actRoman: group.first?.actRoman ?? "",
                                sceneRoman: group.first?.sceneRoman ?? "",
                                location: group.first?.location ?? ""
                            )
                            Spacer()
                            if let scene = sceneMatching(key: "\(group.first?.actRoman ?? "").\(group.first?.sceneRoman ?? "")") {
                                Button {
                                    droppingScene = scene
                                } label: {
                                    Label("Drop whole scene", systemImage: "square.and.arrow.down")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Color.red.opacity(0.75), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
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

    /// Find a Scene struct by its "<actRoman>.<sceneRoman>" key.
    private func sceneMatching(key: String) -> PlayScript.Scene? {
        for act in script.acts {
            for scene in act.scenes {
                if "\(act.roman).\(scene.roman)" == key { return scene }
            }
        }
        return nil
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
