package agilelens.understudy.teleprompter

import android.content.Context
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

/**
 * Loads the bundled play-script JSON assets lazily — one per play, cached
 * after first read. Mirror of Swift's `Scripts` enum.
 *
 * Assets live at `app/src/main/assets/<name>.json`. Classic plays mirror the
 * iOS bundle; original practice samples use the same PlayScript JSON format.
 */
object Scripts {
    /** Tolerant JSON config — plays use their own shape, not the Understudy
     *  wire format (different date encoding, no Envelope wrapper). */
    private val scriptJson = Json {
        ignoreUnknownKeys = true
        isLenient = false
    }

    data class PlayRef(
        val displayName: String,
        val assetName: String,   // e.g. "hamlet.json"
        val author: String,
        val isSample: Boolean = false,
    )

    val samples: List<PlayRef> = listOf(
        PlayRef("The Last Work Light — monologue", "sample-stage-monologue.json", "Agile Lens", true),
        PlayRef("Start With the Room — keynote", "sample-keynote-opener.json", "Agile Lens", true),
        PlayRef("Platform Nine Minutes Late — film", "sample-film-scene.json", "Agile Lens", true),
        PlayRef("Community Desk — news read", "sample-news-read.json", "Agile Lens", true),
        PlayRef("To the People Who Stay — toast", "sample-toast.json", "Agile Lens", true),
        PlayRef("A Cue Without Looking Down — demo", "sample-product-demo.json", "Agile Lens", true),
        PlayRef("Why a Pause Carries Meaning — lecture", "sample-lecture.json", "Agile Lens", true),
        PlayRef("Keep the Rehearsal Moving — 60-second pitch", "sample-sixty-second-pitch.json", "Agile Lens", true),
        PlayRef("Readable Under Pressure — accessibility", "sample-accessibility.json", "Agile Lens", true),
        PlayRef("The Spare Chair — multi-speaker", "sample-multi-speaker.json", "Agile Lens", true),
        PlayRef("Alex: Android XR in Three Minutes", "sample-aura-walkthrough.json", "Agile Lens", true),
    )

    val all: List<PlayRef> = listOf(
        PlayRef("Hamlet", "hamlet.json", "Shakespeare"),
        PlayRef("Macbeth", "macbeth.json", "Shakespeare"),
        PlayRef("A Midsummer Night's Dream", "midsummer.json", "Shakespeare"),
        PlayRef("The Seagull", "seagull.json", "Chekhov"),
        PlayRef("The Importance of Being Earnest", "earnest.json", "Wilde"),
        PlayRef("The Cherry Orchard", "cherry-orchard.json", "Chekhov"),
        PlayRef("Three Sisters", "three-sisters.json", "Chekhov"),
    ) + samples

    private val cache = mutableMapOf<String, PlayScript>()

    /** Load and parse a script. Cached after first call. */
    @Synchronized
    fun load(context: Context, assetName: String): PlayScript? {
        cache[assetName]?.let { return it }
        return try {
            val json = context.assets.open(assetName)
                .bufferedReader().use { it.readText() }
            val script = parse(json)
            cache[assetName] = script
            script
        } catch (_: Exception) {
            null
        }
    }

    /** Same decoder for bundled assets and JVM import validation. */
    fun parse(json: String): PlayScript = scriptJson.decodeFromString(json)

    /** Load the default (first listed) script — Hamlet. */
    fun defaultScript(context: Context): PlayScript? =
        load(context, all.first().assetName)
}
