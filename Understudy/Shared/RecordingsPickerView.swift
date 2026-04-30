//
//  RecordingsPickerView.swift
//  Understudy
//
//  Pick which named recording the ghost playback should use, with each
//  row previewing the avatar that captured it. The understudy-mode
//  killer feature: an actor records the lead's blocking, the understudy
//  picks "Hamlet's path" from the list and chases the ghost.
//

import SwiftUI

public struct RecordingsPickerView: View {
    @Environment(BlockingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var renamingID: ID?
    @State private var renameDraft: String = ""
    @State private var showingRenameAlert: Bool = false
    @State private var deletingID: ID?
    @State private var showingDeleteAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if store.blocking.recordings.isEmpty {
                    ContentUnavailableView(
                        "No recordings yet",
                        systemImage: "figure.walk",
                        description: Text("Press the red record dot in Perform mode and walk the blocking. Save it with a name and an understudy can rehearse against it.")
                    )
                } else {
                    Section {
                        ForEach(store.blocking.recordings) { recording in
                            row(recording)
                        }
                    } footer: {
                        Text("Tap to set as the active ghost. Long-press a row to rename or delete.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Recordings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Rename recording", isPresented: $showingRenameAlert) {
            TextField("Name", text: $renameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let id = renamingID {
                    store.renameRecording(id: id, to: renameDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        .alert("Delete recording?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let id = deletingID {
                    store.deleteRecording(id: id)
                }
            }
        } message: {
            Text("This recording will be removed from the blocking. Other recordings in the list are untouched.")
        }
    }

    private func row(_ recording: NamedRecording) -> some View {
        let isActive = (store.selectedRecordingID == recording.id)
            || (store.selectedRecordingID == nil && store.activeRecording?.id == recording.id)
        return Button {
            store.selectedRecordingID = recording.id
        } label: {
            HStack(spacing: 14) {
                AvatarPreview(avatar: recording.avatar ?? .defaultPick)
                    .frame(width: 56, height: 56)
                    .background(.black, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(recording.name).font(.headline)
                        if isActive {
                            Text("ACTIVE")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.green.opacity(0.3), in: Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                        Text(recording.performerName)
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formatDuration(recording.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renamingID = recording.id
                renameDraft = recording.name
                showingRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingID = recording.id
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        if s >= 60 {
            return String(format: "%dm %02ds", Int(s) / 60, Int(s) % 60)
        }
        return String(format: "%.1fs", s)
    }
}
