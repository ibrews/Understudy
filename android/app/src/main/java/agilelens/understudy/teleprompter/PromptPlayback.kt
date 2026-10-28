package agilelens.understudy.teleprompter

/** Pure cursor math shared by the phone and projected display. Offsets are UTF-16. */
object PromptPlayback {
    data class Window(val start: Int, val end: Int)
    data class Prompt(val character: String?, val text: String, val page: Int, val pages: Int)

    fun normalized(progress: Double): Double =
        if (progress.isFinite()) progress.coerceIn(0.0, 1.0) else 0.0

    fun window(text: String, progress: Double, width: Int = 30): Window {
        val start = safeBoundary(text, (text.length * normalized(progress)).toInt())
        val end = safeBoundary(text, (start + width.coerceAtLeast(0)).coerceAtMost(text.length))
        return Window(start, end)
    }

    // Never split a surrogate pair when highlighting or paginating an imported script.
    private fun safeBoundary(text: String, offset: Int): Int =
        if (offset in 1 until text.length && text[offset].isLowSurrogate() &&
            text[offset - 1].isHighSurrogate()) offset - 1 else offset

    /** Bounded pages preserve every character, including whitespace and very long words. */
    fun chunks(text: String, maxChars: Int = 100): List<Window> {
        require(maxChars >= 2)
        val result = mutableListOf<Window>()
        var start = 0
        while (start < text.length) {
            var end = safeBoundary(text, (start + maxChars).coerceAtMost(text.length))
            if (end < text.length) {
                val space = (end - 1 downTo start + maxChars / 2)
                    .firstOrNull { text[it].isWhitespace() }
                if (space != null) end = space + 1
            }
            result.add(Window(start, end))
            start = end
        }
        return result
    }

    /** Headers/gaps preview the next spoken line; crossing its end advances the cue. */
    fun prompt(document: TeleprompterDocument, progress: Double, maxChars: Int = 100): Prompt? {
        val cursor = window(document.text, progress).start
        val line = document.spokenLines.firstOrNull { it.endOffset > cursor } ?: return null
        val pages = chunks(line.text, maxChars)
        val local = (cursor - line.startOffset).coerceIn(0, line.text.length)
        val index = pages.indexOfFirst { it.end > local }.coerceAtLeast(0)
        val page = pages[index]
        return Prompt(line.character, line.text.substring(page.start, page.end), index + 1, pages.size)
    }

    fun advance(progress: Double, charsPerSecond: Int, elapsedMillis: Long, length: Int): Double {
        if (length <= 0) return normalized(progress)
        return normalized(normalized(progress) + charsPerSecond.coerceAtLeast(0) *
            elapsedMillis.coerceAtLeast(0).toDouble() / 1000.0 / length)
    }

    fun canFollowMark(nowMillis: Long, lastManualMillis: Long): Boolean =
        nowMillis - lastManualMillis >= 3000L
}
