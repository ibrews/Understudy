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
    /// Playback of the director's reference walk: 0…1, or nil if not playing.
    public var playbackT: Double? = nil
    /// Most recently fired cue queue — the UI consumes and drains this.
    public var cueQueue: [FiredCue] = []
    /// Host-assigned identity on the network. Nil until connected.
    public var sessionKey: String? = nil

    private var recordStart: Date?
    private var currentRecording: [RecordedWalk.Sample] = []

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
            fireCues(for: mark, triggeredBy: me.id)
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
    }

    public func updateMark(_ mark: Mark) {
        guard let i = blocking.marks.firstIndex(where: { $0.id == mark.id }) else { return }
        blocking.marks[i] = mark
        blocking.modifiedAt = Date()
    }

    public func removeMark(id: ID) {
        blocking.marks.removeAll { $0.id == id }
        blocking.modifiedAt = Date()
    }

    public func addCue(_ cue: Cue, to markID: ID) {
        guard let i = blocking.marks.firstIndex(where: { $0.id == markID }) else { return }
        blocking.marks[i].cues.append(cue)
        blocking.modifiedAt = Date()
    }

    // MARK: - Cue firing

    public struct FiredCue: Identifiable {
        public let id = UUID()
        public let cue: Cue
        public let markName: String
        public let performerID: ID
        public let at: Date = Date()
    }

    private func fireCues(for mark: Mark, triggeredBy performerID: ID) {
        for cue in mark.cues {
            cueQueue.append(FiredCue(cue: cue, markName: mark.name, performerID: performerID))
        }
    }

    public func drainCue(_ id: UUID) {
        cueQueue.removeAll { $0.id == id }
    }

    // MARK: - Recording

    public func startRecording() {
        currentRecording = []
        recordStart = Date()
        isRecording = true
    }

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
}
