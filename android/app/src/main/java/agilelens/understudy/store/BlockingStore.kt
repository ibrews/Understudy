package agilelens.understudy.store

import agilelens.understudy.model.Blocking
import agilelens.understudy.model.Cue
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark
import agilelens.understudy.model.Performer
import agilelens.understudy.model.Pose
import agilelens.understudy.model.Role
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.time.Instant
import java.util.UUID

/**
 * Observable store mirroring the iOS BlockingStore.
 *
 * - holds the current Blocking (mark set, title, etc.) so the UI can react
 * - tracks all known Performers keyed by ID
 * - tracks the LOCAL performer separately so the UI knows which mark it's on
 */
class BlockingStore(
    localID: Id,
    localDisplayName: String
) {
    private val _blocking = MutableStateFlow(
        Blocking(
            id = Id(),
            title = "Untitled Piece",
            createdAt = Instant.now().toString(),
            modifiedAt = Instant.now().toString()
        )
    )
    val blocking: StateFlow<Blocking> = _blocking.asStateFlow()

    private val _performers = MutableStateFlow<Map<Id, Performer>>(emptyMap())
    val performers: StateFlow<Map<Id, Performer>> = _performers.asStateFlow()

    private val _localID = MutableStateFlow(localID)
    val localID: StateFlow<Id> = _localID.asStateFlow()

    private val _localPerformer = MutableStateFlow(
        Performer(id = localID, displayName = localDisplayName, role = Role.performer)
    )
    val localPerformer: StateFlow<Performer> = _localPerformer.asStateFlow()

    /**
     * Queue of cues freshly fired by mark entry — the CueFXEngine drains this on
     * the main thread and turns each one into audio/flash/hold. Mirrors Swift's
     * `BlockingStore.cueQueue`. Appended to only when a performer transitions
     * onto a new mark (never per-frame while camping on one).
     */
    data class FiredCue(
        val id: String = UUID.randomUUID().toString(),
        val cue: Cue,
        val markName: String,
        val performerID: Id,
    )

    private val _cueQueue = MutableStateFlow<List<FiredCue>>(emptyList())
    val cueQueue: StateFlow<List<FiredCue>> = _cueQueue.asStateFlow()

    fun drainCue(id: String) = _cueQueue.update { q -> q.filterNot { it.id == id } }

    fun drainCues(ids: Set<String>) = _cueQueue.update { q -> q.filterNot { it.id in ids } }

    /** Manually enqueue — used by OSC GO / "as-if-entered" flows. */
    fun enqueueCuesForMark(mark: Mark, performerID: Id) {
        val additions = mark.cues.map { FiredCue(cue = it, markName = mark.name, performerID = performerID) }
        if (additions.isEmpty()) return
        _cueQueue.update { it + additions }
    }

    // --- blocking updates ---

    fun replaceBlocking(b: Blocking) { _blocking.value = b }

    fun markAdded(m: Mark) = _blocking.update { b ->
        if (b.marks.any { it.id == m.id }) b else b.copy(marks = b.marks + m)
    }

    fun markUpdated(m: Mark) = _blocking.update { b ->
        b.copy(marks = b.marks.map { if (it.id == m.id) m else it })
    }

    fun markRemoved(id: Id) = _blocking.update { b ->
        b.copy(marks = b.marks.filter { it.id != id })
    }

    // --- performer updates ---

    fun upsertPerformer(p: Performer) = _performers.update { it + (p.id to p) }

    fun removePerformer(id: Id) = _performers.update { it - id }

    /** Recompute local performer from the latest AR sample. Returns true if currentMarkID changed. */
    fun updateLocalFromArSample(pose: Pose, quality: Float): Boolean {
        val b = _blocking.value
        val prev = _localPerformer.value
        val onMark = b.markContaining(pose)?.id
        val changed = onMark != prev.currentMarkID
        val updated = prev.copy(
            pose = pose,
            trackingQuality = quality,
            currentMarkID = onMark
        )
        _localPerformer.value = updated
        _performers.update { it + (updated.id to updated) }

        // Mirror iOS: fire cues ONLY on the entry transition — not per-frame
        // while camping on a mark. Requires a newly-bound mark id *and* that
        // it differs from the previous mark.
        if (changed && onMark != null) {
            val mark = b.marks.firstOrNull { it.id == onMark }
            if (mark != null) enqueueCuesForMark(mark, updated.id)
        }
        return changed
    }

    fun updateLocalDisplayName(name: String) {
        _localPerformer.update { it.copy(displayName = name) }
    }

    // --- helpers ---

    /** Next mark by sequenceIndex after the current one; falls back to lowest index. */
    fun nextMark(afterCurrent: Id?): Mark? {
        val marks = _blocking.value.marks
        if (marks.isEmpty()) return null
        val sorted = marks.sortedBy { it.sequenceIndex }
        val current = afterCurrent?.let { id -> sorted.firstOrNull { it.id == id } }
        return if (current != null) {
            sorted.firstOrNull { it.sequenceIndex > current.sequenceIndex } ?: sorted.first()
        } else {
            sorted.first()
        }
    }
}
