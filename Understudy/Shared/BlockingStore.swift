//
//  BlockingStore.swift
//  Understudy
//
//  Observable state container. Owns the current `Blocking` document plus
//  the set of live performers. Mutations go through this store so the
//  networking layer can diff them and broadcast.
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
public final class BlockingStore {
    public var blocking: Blocking
    public var performers: [Performer] = []
    public var localPerformerID: ID
    /// True when this device is actively recording its own walk for playback.
    public var isRecording: Bool = false
    /// When false, the director can drag the room-scan ghost to align it
    /// with the rehearsal room. Locked by default so accidental drags
    /// don't shift the scan mid-session.
    public var scanAlignmentLocked: Bool = true
    /// Playback of the director's reference walk: 0…1, or nil if not playing.
    public var playbackT: Double? = nil
    /// Most recently fired cue queue — the UI consumes and drains this.
    public var cueQueue: [FiredCue] = []
    /// Host-assigned identity on the network. Nil until connected.
    public var sessionKey: String? = nil

    // MARK: Stage grid
    public var showStageGrid: Bool = false
    public var snapToGrid: Bool = false

    // MARK: Tabletop (director review) mode
    public var isTabletopMode: Bool = false

    // MARK: Prop placement
    public var isPropPlacementMode: Bool = false
    public var selectedPropShape: PropShape = .cube

    // MARK: Rehearsal timer
    public var rehearsalElapsed: TimeInterval = 0
    public var rehearsalTimerRunning: Bool = false
    private var rehearsalTimerStart: Date?
    private var rehearsalTimerTask: Task<Void, Never>?

    private var recordStart: Date?
    private var currentRecording: [RecordedWalk.Sample] = []

    /// Marks pre-advanced by voice auto-advance. When the performer physically
    /// walks onto one of these marks, cues are skipped (already fired).
    /// Cleared when the performer progresses past that mark in sequence.
    public var voiceAdvancedMarkIDs: Set<ID> = []

    public init(blocking: Blocking = Blocking(), localPerformer: Performer) {
        self.blocking = blocking
        self.localPerformerID = localPerformer.id
        self.performers = [localPerformer]
    }

    // MARK: - Performers

    public func upsertPerformer(_ p: Performer) {
        if let i = performers.firstIndex(where: { $0.id == p.id }) {
            performers[i] = p
        } else {
            performers.append(p)
        }
    }

    public func removePerformer(id: ID) {
        performers.removeAll { $0.id == id }
    }

    public var localPerformer: Performer? {
        performers.first(where: { $0.id == localPerformerID })
    }

    /// Update this device's own pose. Fires cues on mark entry.
    public func updateLocalPose(_ pose: Pose, quality: Float = 1.0) {
        guard var me = localPerformer else { return }
        let previousMark = me.currentMarkID
        me.pose = pose
        me.trackingQuality = quality
        me.currentMarkID = blocking.mark(containing: pose)?.id
        upsertPerformer(me)

        // Fire cues only on *entry* — not every frame we're inside the zone.
        if let newID = me.currentMarkID, newID != previousMark,
           let mark = blocking.marks.first(where: { $0.id == newID }) {
            if voiceAdvancedMarkIDs.contains(newID) {
                // Already fired by voice auto-advance — skip re-fire.
                voiceAdvancedMarkIDs.remove(newID)
            } else {
                fireCues(for: mark, triggeredBy: me.id)
            }
        }

        if isRecording, let start = recordStart {
            currentRecording.append(
                RecordedWalk.Sample(t: Date().timeIntervalSince(start), pose: pose)
            )
        }
    }

    // MARK: - Marks

    public func addMark(_ mark: Mark) {
        var m = mark
        if m.sequenceIndex < 0 {
            m.sequenceIndex = (blocking.marks.map(\.sequenceIndex).max() ?? -1) + 1
        }
        blocking.marks.append(m)
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }

    public func updateMark(_ mark: Mark) {
        guard let i = blocking.marks.firstIndex(where: { $0.id == mark.id }) else { return }
        blocking.marks[i] = mark
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }

    public func removeMark(id: ID) {
        blocking.marks.removeAll { $0.id == id }
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }

    public func addCue(_ cue: Cue, to markID: ID) {
        guard let i = blocking.marks.firstIndex(where: { $0.id == markID }) else { return }
        blocking.marks[i].cues.append(cue)
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }

    // MARK: - Cue firing

    public struct FiredCue: Identifiable {
        public let id = UUID()
        public let cue: Cue
        public let markName: String
        public let performerID: ID
    }

    private func fireCues(for mark: Mark, triggeredBy performerID: ID) {
        for cue in mark.cues {
            cueQueue.append(FiredCue(cue: cue, markName: mark.name, performerID: performerID))
        }
    }

    /// Fire a mark's cues from outside (e.g. voice auto-advance) without requiring
    /// the performer to physically walk onto it. Marks the ID in `voiceAdvancedMarkIDs`
    /// so the next physical entry skips double-firing.
    public func fireMarkByVoiceAdvance(markID: ID) {
        guard let mark = blocking.marks.first(where: { $0.id == markID }),
              let me = localPerformer else { return }
        voiceAdvancedMarkIDs.insert(markID)
        if var performer = localPerformer {
            performer.currentMarkID = markID
            upsertPerformer(performer)
        }
        fireCues(for: mark, triggeredBy: me.id)
    }

    public func drainCue(_ id: UUID) {
        cueQueue.removeAll { $0.id == id }
    }

    // MARK: - Recording

    /// Which named recording is currently selected for ghost playback.
    /// Nil = use the legacy `blocking.reference` walk if it exists, or
    /// the most recent named recording.
    public var selectedRecordingID: ID? = nil

    public func startRecording() {
        currentRecording = []
        recordStart = Date()
        isRecording = true
    }

    /// Legacy stop — kept for backward-compat callers (PerformerView).
    /// Internally now delegates to stopRecording(name:performerName:avatar:)
    /// with a default name.
    @discardableResult
    public func stopRecording(saveAsReference: Bool, performerName: String) -> RecordedWalk? {
        isRecording = false
        guard let start = recordStart else { return nil }
        let walk = RecordedWalk(
            performerName: performerName,
            samples: currentRecording,
            duration: Date().timeIntervalSince(start)
        )
        recordStart = nil
        currentRecording = []
        if saveAsReference {
            blocking.reference = walk
            blocking.modifiedAt = Date()
        }
        return walk
    }

    /// Stop recording and append a NamedRecording to the blocking. The
    /// avatar parameter captures whatever the local performer was using
    /// at recording time, so playback can render with the correct avatar.
    @discardableResult
    public func stopRecordingNamed(
        name: String,
        performerName: String,
        avatar: Avatar?
    ) -> NamedRecording? {
        isRecording = false
        guard let start = recordStart else { return nil }
        let duration = Date().timeIntervalSince(start)
        let recording = NamedRecording(
            name: name,
            performerName: performerName,
            avatar: avatar,
            samples: currentRecording,
            duration: duration,
            blockingTitle: blocking.title
        )
        recordStart = nil
        currentRecording = []
        blocking.recordings.append(recording)
        // Also write to the legacy `reference` slot so older code keeps
        // working until every call site is migrated to recordings[].
        blocking.reference = RecordedWalk(
            performerName: performerName,
            samples: recording.samples,
            duration: duration
        )
        blocking.modifiedAt = Date()
        selectedRecordingID = recording.id
        BlockingAutosave.save(blocking)
        return recording
    }

    public func deleteRecording(id: ID) {
        blocking.recordings.removeAll { $0.id == id }
        if selectedRecordingID == id {
            selectedRecordingID = blocking.recordings.last?.id
        }
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }

    public func renameRecording(id: ID, to newName: String) {
        guard let i = blocking.recordings.firstIndex(where: { $0.id == id }) else { return }
        blocking.recordings[i].name = newName
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }

    /// Currently active recording for ghost playback. Defaults to the
    /// selected one, or the most-recent named recording, or the legacy
    /// `reference` walk wrapped as a NamedRecording on demand.
    public var activeRecording: NamedRecording? {
        if let id = selectedRecordingID,
           let r = blocking.recordings.first(where: { $0.id == id }) {
            return r
        }
        if let last = blocking.recordings.last { return last }
        if let legacy = blocking.reference {
            return NamedRecording(legacyWalk: legacy, blockingTitle: blocking.title)
        }
        return nil
    }

    // MARK: - Playback

    /// Interpolate the active named recording (or legacy reference) at a
    /// given 0…1 normalized time. Returns `nil` if there's no recording.
    public func ghostPose(at normalizedT: Double) -> Pose? {
        if let recording = activeRecording {
            return recording.pose(at: normalizedT)
        }
        return nil
    }

    /// The avatar to render the ghost with — the one that was bound to
    /// the recording at capture time, or nil to fall back to the default.
    public var ghostAvatar: Avatar? {
        activeRecording?.avatar
    }

    // MARK: - Sequencing helpers

    /// Next mark the performer should hit, based on current position.
    public func nextMark(after current: ID?) -> Mark? {
        let ordered = blocking.marks
            .filter { $0.sequenceIndex >= 0 }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        guard let current,
              let idx = ordered.firstIndex(where: { $0.id == current }) else {
            return ordered.first
        }
        let next = idx + 1
        return next < ordered.count ? ordered[next] : nil
    }

    // MARK: - Stage grid snap

    /// If `snapToGrid` is on and the pose is within `threshold` meters of a
    /// zone center, snaps to that center; otherwise returns the pose unchanged.
    public func snappedToGrid(_ pose: Pose, threshold: Float = 0.7) -> Pose {
        guard snapToGrid else { return pose }
        var best = pose
        var bestDist = threshold
        for area in StageArea.allCases {
            let c = area.worldCenter()
            let dx = c.x - pose.x
            let dz = c.z - pose.z
            let d = sqrtf(dx * dx + dz * dz)
            if d < bestDist {
                bestDist = d
                best = Pose(x: c.x, y: pose.y, z: c.z, yaw: pose.yaw)
            }
        }
        return best
    }

    // MARK: - Rehearsal timer

    public func startRehearsalTimer() {
        guard !rehearsalTimerRunning else { return }
        rehearsalTimerStart = Date().addingTimeInterval(-rehearsalElapsed)
        rehearsalTimerRunning = true
        rehearsalTimerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.rehearsalTimerRunning,
                      let start = self.rehearsalTimerStart else { break }
                self.rehearsalElapsed = Date().timeIntervalSince(start)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    public func stopRehearsalTimer() {
        rehearsalTimerRunning = false
        rehearsalTimerTask?.cancel()
        rehearsalTimerTask = nil
    }

    public func resetRehearsalTimer() {
        stopRehearsalTimer()
        rehearsalElapsed = 0
        rehearsalTimerStart = nil
    }

    // MARK: - Props

    public func addProp(_ prop: PropObject) {
        blocking.props.append(prop)
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }

    public func updateProp(_ prop: PropObject) {
        guard let i = blocking.props.firstIndex(where: { $0.id == prop.id }) else { return }
        blocking.props[i] = prop
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }

    public func removeProp(id: ID) {
        blocking.props.removeAll { $0.id == id }
        blocking.modifiedAt = Date()
        BlockingAutosave.save(blocking)
    }
}
