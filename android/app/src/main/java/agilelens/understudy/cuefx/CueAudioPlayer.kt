package agilelens.understudy.cuefx

import android.media.AudioManager
import android.media.ToneGenerator

/**
 * Plays theatrical SFX for `Cue.Sfx` firings.
 *
 * ### Divergence from iOS
 *
 * iOS fires SFX via `AudioServicesPlaySystemSound` against the built-in
 * Apple system sound catalog (e.g. ID 1005 "thunder", 1013 "bell"). Those
 * PCM assets only exist on Apple platforms — Android has no equivalent
 * library we can hit without shipping our own audio files.
 *
 * Rather than bloat the APK with custom WAVs for a prototype, this player
 * synthesizes brief dial-tone bursts via `ToneGenerator` that are distinct
 * enough per cue name to serve as placeholders during rehearsals. When
 * production assets ship, swap `ToneGenerator` for `SoundPool` pointing at
 * `res/raw/` WAV/OGG assets — the engine-facing API (`play(name)`) stays identical.
 *
 * All tone bursts are ≤1 s and the generator is released explicitly, so
 * this class is safe to instantiate per-app and never hang audio focus.
 */
class CueAudioPlayer {

    // Volume at 70 %. ToneGenerator clamps 0..100.
    private var tone: ToneGenerator? = null

    /** Map a cue name to a tone type + duration. Unknown names get a neutral ping. */
    private data class ToneRecipe(val toneType: Int, val durationMs: Int)

    private fun recipe(name: String): ToneRecipe = when (name.lowercase()) {
        "thunder"  -> ToneRecipe(ToneGenerator.TONE_CDMA_LOW_L, 800)
        "bell"     -> ToneRecipe(ToneGenerator.TONE_PROP_BEEP,  450)
        "chime"    -> ToneRecipe(ToneGenerator.TONE_PROP_ACK,   600)
        "knock"    -> ToneRecipe(ToneGenerator.TONE_CDMA_PIP,   300)
        "applause" -> ToneRecipe(ToneGenerator.TONE_CDMA_ALERT_NETWORK_LITE, 700)
        else       -> ToneRecipe(ToneGenerator.TONE_PROP_BEEP2, 250)
    }

    /**
     * Play a short burst for the given cue name. Creates a fresh generator
     * if needed (generators die when the app goes to background).
     */
    fun play(name: String) {
        val recipe = recipe(name)
        try {
            if (tone == null) {
                tone = ToneGenerator(AudioManager.STREAM_MUSIC, 70)
            }
            tone?.startTone(recipe.toneType, recipe.durationMs)
        } catch (_: Throwable) {
            // ToneGenerator can throw RuntimeException if the system stream is
            // unavailable (emulator without audio, silenced ringer on some
            // devices, etc.). Fall silent rather than crash a cue.
            tone = null
        }
    }

    fun release() {
        try { tone?.release() } catch (_: Throwable) { /* ignore */ }
        tone = null
    }
}
