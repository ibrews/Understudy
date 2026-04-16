package agilelens.understudy.teleprompter

import android.content.Context
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

/**
 * Loads the bundled play-script JSON assets lazily — one per play, cached
 * after first read. Mirror of Swift's `Scripts` enum.
 *
 * Assets live at `app/src/main/assets/<name>.json`. They are byte-for-byte
 * copies of `Understudy/Resources/<name>.json` (the iOS bundle), regenerated
 * via `scripts/parse_hamlet.py` + `scripts/parse_modern.py`.
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
    )

    val all: List<PlayRef> = listOf(
        PlayRef("Hamlet", "hamlet.json", "Shakespeare"),
        PlayRef("Macbeth", "macbeth.json", "Shakespeare"),
        PlayRef("A Midsummer Night's Dream", "midsummer.json", "Shakespeare"),
        PlayRef("The Seagull", "seagull.json", "Chekhov"),
        PlayRef("The Importance of Being Earnest", "earnest.json", "Wilde"),
    )

    private val cache = mutableMapOf<String, PlayScript>()

    /** Load and parse a script. Cached after first call. */
    fun load(context: Context, assetName: String): PlayScript? {
        cache[assetName]?.let { return it }
        return try {
            val json = context.assets.open(assetName)
                .bufferedReader().use { it.readText() }
            val script = scriptJson.decodeFromString<PlayScript>(json)
            cache[assetName] = script
            script
        } catch (t: Throwable) {
            null
        }
    }

    /** Load the default (first listed) script — Hamlet. */
    fun defaultScript(context: Context): PlayScript? =
        load(context, all.first().assetName)
}
