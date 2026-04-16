package agilelens.understudy.teleprompter

import kotlin.math.min

/**
 * Port of Swift's VoiceMatcher (itself a port of your Gemini-Live-ToDo
 * processSpokenText). Given the last few spoken words, find a forward
 * match within the current window and return the new scroll progress.
 */
object VoiceMatcher {
    const val DEFAULT_SEARCH_WINDOW = 50

    fun nextProgress(
        spoken: String,
        document: TeleprompterDocument,
        currentProgress: Double,
        searchWindow: Int = DEFAULT_SEARCH_WINDOW,
    ): Double? {
        val text = document.lowercasedText
        val totalLen = text.length
        if (totalLen == 0) return null

        val lower = spoken.lowercase().trim()
        if (lower.isEmpty()) return null

        val currentIdx = (totalLen * currentProgress).toInt().coerceIn(0, totalLen - 1)
        val searchEnd = min(currentIdx + searchWindow, totalLen)
        if (searchEnd <= currentIdx) return null

        val window = text.substring(currentIdx, searchEnd)
        val words = lower.split(" ").filter { it.isNotEmpty() }

        val candidates = mutableListOf<String>()
        if (words.size >= 3) candidates += words.takeLast(3).joinToString(" ")
        if (words.size >= 2) candidates += words.takeLast(2).joinToString(" ")
        if (words.isNotEmpty()) candidates += words.last()

        for (phrase in candidates) {
            if (phrase.length < 2) continue
            val idx = window.indexOf(phrase)
            if (idx != -1) {
                val matchEnd = currentIdx + idx + phrase.length
                return matchEnd.toDouble() / totalLen.toDouble()
            }
        }
        return null
    }
}
