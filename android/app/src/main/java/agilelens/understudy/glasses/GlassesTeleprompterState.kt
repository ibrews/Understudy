package agilelens.understudy.glasses

import agilelens.understudy.model.Mark
import agilelens.understudy.teleprompter.TeleprompterDocument
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue

/**
 * Shared state between the phone-side driver (Perform / Author mode, voice
 * recognition, settings) and the glasses-side display Activity. Follows
 * Alex's Gemini-Live-ToDo pattern — a singleton object whose state flows
 * through `mutableStateOf` so Compose on both displays recomposes
 * together.
 *
 * Two render modes, both available as a toggle:
 *   - SINGLE_LINE: show just the current mark's currently-active line cue,
 *     centered, max two lines of text, rest blank. Closest to a prompter
 *     for AR glasses — maximum legibility, minimum distraction.
 *   - FLOWING_SCRIPT: karaoke scroll of the whole blocking's flattened
 *     script, matching the phone's TeleprompterScreen (past gray, active
 *     cyan window, future white). Mirrors the phone but at 480x480.
 *
 * The phone-side UI writes to these properties; the glasses Activity
 * reads them via Compose and re-renders. When the glasses aren't paired
 * or the companion Activity isn't open, these properties just sit
 * unobserved — zero cost.
 */
object GlassesTeleprompterState {
    enum class RenderMode { SINGLE_LINE, FLOWING_SCRIPT }

    var renderMode by mutableStateOf(RenderMode.SINGLE_LINE)
    /// The flattened document. Re-set by the phone when the Blocking
    /// mutates. Empty doc = glasses show "Waiting for script…".
    var document by mutableStateOf(
        TeleprompterDocument(text = "", lowercasedText = "", markOffsets = emptyList(), lineCueEnds = emptyList())
    )
    /// Same 0…1 cursor used on the phone. Voice match / manual drag on
    /// the phone advances this; the glasses simply render the cursor.
    var scrollProgress by mutableStateOf(0.0)
    /// For SINGLE_LINE mode — the mark the performer is currently on.
    var currentMark by mutableStateOf<Mark?>(null)
    /// Flash state for firing cues visually on the glasses (cue just
    /// fired — quick blip). Milliseconds since epoch.
    var lastFlashAt by mutableStateOf(0L)
    /// Flash color, ARGB int. Pairs with lastFlashAt.
    var lastFlashColor by mutableStateOf(0xFFFFFFFF.toInt())
}
