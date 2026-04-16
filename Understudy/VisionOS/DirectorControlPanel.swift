//
//  DirectorControlPanel.swift
//  Understudy (visionOS)
//
//  The floating window where the director runs the show: room code, mark list,
//  cue editor, playback transport.
//

#if os(visionOS)
import SwiftUI

struct DirectorControlPanel: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var immersiveActive = false
    @State private var editingMark: Mark?
    @State private var newCueText: String = ""
    @State private var newCueCharacter: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                roomRow
                marksList
                Spacer()
                footer
            }
            .padding(24)
            .navigationTitle("Understudy — Director")
            .sheet(item: $editingMark) { mark in
                MarkEditor(mark: mark)
                    .environment(store)
                    .environment(session)
                    .frame(minWidth: 420, minHeight: 520)
            }
        }
    }

    @ViewBuilder private var header: some View {
        HStack {
            Image(systemName: "theatermasks.fill")
                .font(.largeTitle)
            VStack(alignment: .leading) {
                Text(store.blocking.title)
                    .font(.title)
                    .fontWeight(.bold)
                Text("\(store.blocking.marks.count) marks  •  \(session.peerCount) connected  •  \(AppVersion.formatted)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var roomRow: some View {
        HStack {
            Label("Room", systemImage: "number")
            TextField("Room code", text: Binding(
                get: { session.roomCode },
                set: { session.roomCode = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 180)

            Toggle(isOn: $immersiveActive) {
                Text(immersiveActive ? "Stage On" : "Stage Off")
            }
            .toggleStyle(.button)
            .onChange(of: immersiveActive) { _, on in
                Task {
                    if on { _ = await openImmersiveSpace(id: "Stage") }
                    else { await dismissImmersiveSpace() }
                }
            }
        }
    }

    @ViewBuilder private var marksList: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Marks")
                    .font(.headline)
                Spacer()
                Button {
                    // Quick-add a mark at the origin — mostly for testing without
                    // entering the immersive space.
                    let i = store.blocking.marks.count + 1
                    let m = Mark(name: "Mark \(i)", pose: Pose(x: 0, y: 0, z: -Float(i) * 0.8),
                                 sequenceIndex: i - 1)
                    store.addMark(m)
                    session.broadcastMarkAdded(m)
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            if store.blocking.marks.isEmpty {
                ContentUnavailableView(
                    "No marks yet",
                    systemImage: "mappin.slash",
                    description: Text("Open the stage and tap to place marks, or use Add.")
                )
            } else {
                List {
                    ForEach(store.blocking.marks.sorted(by: { $0.sequenceIndex < $1.sequenceIndex })) { mark in
                        Button {
                            editingMark = mark
                        } label: {
                            HStack {
                                Text("\(mark.sequenceIndex + 1)")
                                    .frame(width: 28, alignment: .leading)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading) {
                                    Text(mark.name).font(.headline)
                                    if !mark.cues.isEmpty {
                                        Text(mark.cues.map(\.humanLabel).joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(String(format: "%.1f, %.1f m",
                                            mark.pose.x, mark.pose.z))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { idx in
                        let sorted = store.blocking.marks.sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
                        for i in idx {
                            let id = sorted[i].id
                            store.removeMark(id: id)
                            session.broadcastMarkRemoved(id)
                        }
                    }
                }
                .frame(minHeight: 280)
            }
        }
    }

    @ViewBuilder private var footer: some View {
        HStack {
            if let t = store.playbackT {
                Label("Playback", systemImage: "play.circle")
                ProgressView(value: t)
                    .frame(maxWidth: 240)
            }
            Spacer()
            Button(role: .destructive) {
                for m in store.blocking.marks {
                    session.broadcastMarkRemoved(m.id)
                }
                store.blocking.marks.removeAll()
            } label: {
                Label("Clear Stage", systemImage: "trash")
            }
        }
    }
}

struct MarkEditor: View {
    @Environment(BlockingStore.self) private var store
    @Environment(SessionController.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State var mark: Mark
    @State private var newLine: String = ""
    @State private var newCharacter: String = ""
    @State private var newNote: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Mark name", text: $mark.name)
                    Stepper("Radius: \(String(format: "%.1f", mark.radius)) m",
                            value: $mark.radius, in: 0.2...3.0, step: 0.1)
                }
                Section("Position") {
                    HStack {
                        Text("x"); TextField("x", value: $mark.pose.x, format: .number.precision(.fractionLength(2)))
                        Text("z"); TextField("z", value: $mark.pose.z, format: .number.precision(.fractionLength(2)))
                    }
                    .textFieldStyle(.roundedBorder)
                }
                Section("Cues") {
                    ForEach(mark.cues, id: \.id) { cue in
                        Text(cue.humanLabel)
                    }
                    .onDelete { idx in
                        mark.cues.remove(atOffsets: idx)
                    }
                    VStack(alignment: .leading) {
                        TextField("Character (optional)", text: $newCharacter)
                        TextField("Add a line…", text: $newLine)
                        Button("Add Line") {
                            guard !newLine.isEmpty else { return }
                            mark.cues.append(.line(id: ID(),
                                                   text: newLine,
                                                   character: newCharacter.isEmpty ? nil : newCharacter))
                            newLine = ""
                        }
                        .disabled(newLine.isEmpty)
                    }
                    VStack(alignment: .leading) {
                        TextField("Add a director note…", text: $newNote)
                        Button("Add Note") {
                            guard !newNote.isEmpty else { return }
                            mark.cues.append(.note(id: ID(), text: newNote))
                            newNote = ""
                        }
                        .disabled(newNote.isEmpty)
                    }
                }
            }
            .navigationTitle(mark.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateMark(mark)
                        session.broadcastMarkUpdated(mark)
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif
