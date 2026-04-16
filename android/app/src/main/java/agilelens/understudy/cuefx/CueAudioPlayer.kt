package agilelens.understudy.cuefx

import agilelens.understudy.R
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
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
 * On Android we ship a handful of short PD/self-generated WAVs under
 * `res/raw/` (see `LICENSE-SOUNDS.md`) and load them into a [SoundPool].
 * For any cue name we don't have a matching WAV for — including runtime-
 * authored custom names — we fall back to the original [ToneGenerator]
 * dial-tone bursts so at least *something* audible fires.
 *
 * The engine-facing API stays identical: `play(name)` and `release()`.
 *
 * Unit tests construct the player without a context — in that mode the
 * SoundPool path is skipped and every cue falls through to ToneGenerator.
 */
class CueAudioPlayer(
    private val context: Context? = null,
) {

    // Volume 0..1 for SoundPool, 0..100 for ToneGenerator.
    private val sfxVolume: Float = 0.9f

    private val soundPool: SoundPool? = context?.let { buildSoundPool() }
    /** Map cue name → loaded sample id. Null entries mean "still loading". */
    private val sampleIds: Map<String, Int> = soundPool?.let { pool ->
        val ctx = context
        // Keep this table in sync with the iOS systemSoundID table in
        // CueFXEngine.swift. Filename stems must match the cue names exactly.
        val catalog = mapOf(
            "thunder"  to R.raw.thunder,
            "bell"     to R.raw.bell,
            "chime"    to R.raw.chime,
            "knock"    to R.raw.knock,
            "applause" to R.raw.applause,
        )
        catalog.mapValues { (_, resId) -> pool.load(ctx, resId, 1) }
    } ?: emptyMap()

    // ToneGenerator fallback for unknown cue names.
    private var tone: ToneGenerator? = null

    private data class ToneRecipe(val toneType: Int, val durationMs: Int)

    private fun toneRecipe(name: String): ToneRecipe = when (name.lowercase()) {
        "thunder"  -> ToneRecipe(ToneGenerator.TONE_CDMA_LOW_L, 800)
        "bell"     -> ToneRecipe(ToneGenerator.TONE_PROP_BEEP,  450)
        "chime"    -> ToneRecipe(ToneGenerator.TONE_PROP_ACK,   600)
        "knock"    -> ToneRecipe(ToneGenerator.TONE_CDMA_PIP,   300)
        "applause" -> ToneRecipe(ToneGenerator.TONE_CDMA_ALERT_NETWORK_LITE, 700)
        else       -> ToneRecipe(ToneGenerator.TONE_PROP_BEEP2, 250)
    }

    private fun buildSoundPool(): SoundPool {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        return SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(attrs)
            .build()
    }

    /**
     * Play a short burst for the given cue name. Tries SoundPool first; if
     * we didn't ship a matching WAV (or the player was built without a
     * context, e.g. in unit tests), falls back to [ToneGenerator].
     */
    fun play(name: String) {
        val key = name.lowercase()
        val pool = soundPool
        val sampleId = sampleIds[key]
        if (pool != null && sampleId != null) {
            // SoundPool.play returns 0 on failure (e.g. sample still loading).
            // Any non-zero stream id means the shot is in flight.
            val stream = pool.play(sampleId, sfxVolume, sfxVolume, 1, 0, 1.0f)
            if (stream != 0) return
            // fall through to ToneGenerator — better a beep than silence
        }
        playTone(key)
    }

    private fun playTone(name: String) {
        val recipe = toneRecipe(name)
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
        try { soundPool?.release() } catch (_: Throwable) { /* ignore */ }
        try { tone?.release() } catch (_: Throwable) { /* ignore */ }
        tone = null
    }
}
