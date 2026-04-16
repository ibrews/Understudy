package agilelens.understudy.cuefx

import agilelens.understudy.model.Cue
import agilelens.understudy.model.Id
import agilelens.understudy.model.LightColor
import agilelens.understudy.store.BlockingStore
import android.content.Context
import androidx.compose.ui.graphics.Color
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

// (CueFXEngine body below — stateflows + attach/detach/voiceLineFinished)

/**
 * Kotlin port of Swift's [CueFXEngine]. Drains the store's `cueQueue` and
 * turns each entry into an actual effect:
 *
 *  - [Cue.Sfx]     → brief audio burst via [CueAudioPlayer]
 *  - [Cue.Light]   → sets [flashState], which [FlashOverlay] reads and
 *                    fades over the hold + fade window
 *  - [Cue.Wait]    → counts down [holdState] on a 10 Hz tick
 *  - [Cue.Line]    → ignored (UI owns lines)
 *  - [Cue.Note]    → ignored (stage direction)
 *
 * The engine is NOT a Compose `@Composable`; it's a plain object with
 * observable [StateFlow]s so the Compose tree can `collectAsState` into it.
 * Views drive overlays directly off [flashState] and [holdState].
 *
 * Voice-driven auto-fire lives here as [voiceLineFinished]. The teleprompter
 * computes which line cues were crossed during a voice jump and asks the
 * engine to fire the trailing SFX/light/wait cues on each.
 */
class CueFXEngine(
    /**
     * Optional application context used by [CueAudioPlayer] to load WAV
     * assets from `res/raw/` into a [android.media.SoundPool]. When null
     * (e.g. unit tests), SFX falls back to ToneGenerator dial-tone bursts.
     */
    context: Context? = null,
) {

    /** Snapshot of a transient lighting flash; the overlay reads this. */
    data class FlashState(
        val color: Color,
        val alpha: Float,
        val holdDurationMs: Long,
        val fadeDurationMs: Long,
        val cueID: String = UUID.randomUUID().toString(),
    )

    /** Small rolling log entry so a future debug HUD can surface recent fires. */
    data class LogEntry(
        val id: String = UUID.randomUUID().toString(),
        val cue: Cue,
        val markName: String,
        val atEpochMs: Long,
    )

    // --- Observable state ---

    private val _flashState = MutableStateFlow<FlashState?>(null)
    val flashState: StateFlow<FlashState?> = _flashState.asStateFlow()

    /** Remaining seconds on an active wait cue, null when idle. */
    private val _holdState = MutableStateFlow<Double?>(null)
    val holdState: StateFlow<Double?> = _holdState.asStateFlow()

    private val _recentLog = MutableStateFlow<List<LogEntry>>(emptyList())
    val recentLog: StateFlow<List<LogEntry>> = _recentLog.asStateFlow()

    private val maxLog = 24

    /**
     * Number of auto-fire cues fired in the most recent [voiceLineFinished]
     * batch, paired with the epoch ms it happened. UI uses this to flash a
     * "🔥 N cues fired" banner without having to count cues itself.
     */
    private val _lastAutoFireBatch = MutableStateFlow(AutoFireBatch(0, 0L))
    val lastAutoFireBatch: StateFlow<AutoFireBatch> = _lastAutoFireBatch.asStateFlow()

    data class AutoFireBatch(val count: Int, val atEpochMs: Long)

    // --- Private ---

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val audio = CueAudioPlayer(context)
    private var store: BlockingStore? = null
    private var drainJob: Job? = null
    private var flashClearJob: Job? = null
    private var holdJob: Job? = null

    /** Prevent a voice-fired cue from re-firing when scroll progress bounces. */
    private val voiceFiredCueIDs: MutableSet<Id> = mutableSetOf()

    // --- Lifecycle ---

    /**
     * Attach the engine to a store. Starts collecting the store's `cueQueue`
     * and dispatching each fired entry. Safe to call once at app launch.
     */
    fun attach(store: BlockingStore) {
        this.store = store
        drainJob?.cancel()
        drainJob = scope.launch {
            store.cueQueue.collect { queue ->
                if (queue.isEmpty()) return@collect
                // Snapshot + drain the ids we're about to dispatch, so the store
                // doesn't re-deliver them if another mutator fires mid-loop.
                val snapshot = queue.toList()
                store.drainCues(snapshot.map { it.id }.toSet())
                for (fired in snapshot) dispatch(fired)
            }
        }
    }

    fun detach() {
        drainJob?.cancel(); drainJob = null
        flashClearJob?.cancel(); flashClearJob = null
        holdJob?.cancel(); holdJob = null
        audio.release()
    }

    /** Call from `onDestroy` to cancel the root scope. */
    fun shutdown() {
        detach()
        scope.cancel()
    }

    // --- Public fire entrypoints ---

    /**
     * Fire a single cue immediately, as though it were enqueued — used by the
     * mark-editor "preview" button so authors can hear/see a cue while
     * building it. Mirrors Swift's `CueFXEngine.preview`.
     */
    fun preview(cue: Cue) {
        appendLog(cue, "Preview")
        when (cue) {
            is Cue.Line -> Unit
            is Cue.Sfx -> audio.play(cue.name)
            is Cue.Light -> flash(cue.color, cue.intensity)
            is Cue.Wait -> beginHold(cue.seconds)
            is Cue.Note -> Unit
        }
    }

    /**
     * Called by the teleprompter when voice mode crosses a line cue's end
     * offset. Fires every following non-line cue on the same mark, up to the
     * next line (or end of mark). Already-fired cues (tracked via
     * [voiceFiredCueIDs]) are skipped so scroll-bounce doesn't re-trigger.
     *
     * Returns the number of cues fired so the UI can show a feedback flash.
     */
    fun voiceLineFinished(cueID: Id, onMarkID: Id): Int {
        val store = store ?: return 0
        val mark = store.blocking.value.marks.firstOrNull { it.id == onMarkID } ?: return 0
        val lineIdx = mark.cues.indexOfFirst { it.id == cueID }
        if (lineIdx < 0) return 0
        voiceFiredCueIDs.add(cueID)

        val performer = store.localPerformer.value.id
        var fired = 0
        for (cue in mark.cues.drop(lineIdx + 1)) {
            if (cue is Cue.Line) break // next line is a future voice trigger
            if (cue.id in voiceFiredCueIDs) continue
            voiceFiredCueIDs.add(cue.id)
            // Route through dispatch() rather than the store queue so preview +
            // voice-fire share one code path and never race the drain loop.
            appendLog(cue, mark.name)
            when (cue) {
                is Cue.Sfx   -> audio.play(cue.name)
                is Cue.Light -> flash(cue.color, cue.intensity)
                is Cue.Wait  -> beginHold(cue.seconds)
                is Cue.Note, is Cue.Line -> Unit
            }
            fired += 1
        }
        if (fired > 0) {
            _lastAutoFireBatch.value = AutoFireBatch(fired, System.currentTimeMillis())
        }
        return fired
    }

    /** Clear voice-fire memory when the teleprompter scrolls back to top. */
    fun resetVoiceFiredCues() { voiceFiredCueIDs.clear() }

    // --- Internal dispatch ---

    private fun dispatch(fired: BlockingStore.FiredCue) {
        appendLog(fired.cue, fired.markName)
        when (val c = fired.cue) {
            is Cue.Line -> Unit
            is Cue.Sfx -> audio.play(c.name)
            is Cue.Light -> flash(c.color, c.intensity)
            is Cue.Wait -> beginHold(c.seconds)
            is Cue.Note -> Unit
        }
    }

    private fun appendLog(cue: Cue, markName: String) {
        val now = System.currentTimeMillis()
        _recentLog.update { log ->
            val next = log + LogEntry(cue = cue, markName = markName, atEpochMs = now)
            if (next.size > maxLog) next.drop(next.size - maxLog) else next
        }
    }

    // --- Flash ---

    private fun flash(color: LightColor, intensity: Float) {
        // Clamp alpha to a theatrical ceiling so full-white cues don't blind.
        val alpha = min(0.85f, max(0.3f, intensity))
        val state = FlashState(
            color = composeColor(color),
            alpha = alpha,
            holdDurationMs = 250L,
            fadeDurationMs = 500L,
        )
        _flashState.value = state
        flashClearJob?.cancel()
        flashClearJob = scope.launch {
            delay(state.holdDurationMs + state.fadeDurationMs)
            // Only clear if a newer flash hasn't taken over in the meantime.
            if (_flashState.value?.cueID == state.cueID) _flashState.value = null
        }
    }

    // --- Hold ---

    private fun beginHold(seconds: Double) {
        _holdState.value = seconds
        holdJob?.cancel()
        holdJob = scope.launch {
            var remaining = seconds
            while (remaining > 0) {
                delay(100)
                remaining -= 0.1
                _holdState.value = if (remaining > 0) remaining else null
            }
        }
    }

    companion object {
        /** Mirrors Swift's `CueFXEngine.color(for:)`. */
        fun composeColor(color: LightColor): Color = when (color) {
            LightColor.warm     -> Color(red = 1.0f,  green = 0.85f, blue = 0.55f)
            LightColor.cool     -> Color(red = 0.55f, green = 0.85f, blue = 1.0f)
            LightColor.red      -> Color.Red
            LightColor.blue     -> Color.Blue
            LightColor.green    -> Color.Green
            LightColor.amber    -> Color(red = 1.0f, green = 0.75f, blue = 0.2f)
            LightColor.blackout -> Color.Black
        }
    }
}
