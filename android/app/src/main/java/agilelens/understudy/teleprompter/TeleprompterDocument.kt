package agilelens.understudy.teleprompter

import agilelens.understudy.model.Blocking
import agilelens.understudy.model.Cue
import agilelens.understudy.model.Id

/**
 * Kotlin mirror of Swift's TeleprompterDocument. Flattens a Blocking into a
 * single flowing script with per-mark character offsets AND per-line-cue end
 * offsets, so voice matching + auto-fire can both operate on one coord system.
 *
 * Android's Mark doesn't carry `kind` (v0.8 film-mode types aren't ported),
 * so we include every mark with sequenceIndex >= 0 — same behavior for a
 * theater-only blocking as iOS.
 */
data class TeleprompterDocument(
    val text: String,
    val lowercasedText: String,
    val markOffsets: List<MarkOffset>,
    val lineCueEnds: List<LineCueMarker>,
) {
    data class MarkOffset(
        val markId: Id,
        val name: String,
        val headerStart: Int,
        val firstLineStart: Int,
        val endOffset: Int,
    )

    data class LineCueMarker(
        val markId: Id,
        val cueId: Id,
        val endOffset: Int,
    )

    /** Find the mark a given scrollProgress (0..1) is currently inside. */
    fun markAt(progress: Double): MarkOffset? {
        if (markOffsets.isEmpty() || text.isEmpty()) return null
        val idx = (text.length * progress.coerceIn(0.0, 1.0)).toInt()
        var last: MarkOffset? = null
        for (mo in markOffsets) {
            if (mo.headerStart <= idx) last = mo else break
        }
        return last ?: markOffsets.firstOrNull()
    }

    /** Character offset (as scrollProgress) of a mark's header, if known. */
    fun progressForMark(id: Id): Double? {
        if (text.isEmpty()) return null
        val mo = markOffsets.firstOrNull { it.markId == id } ?: return null
        return mo.headerStart.toDouble() / text.length.toDouble()
    }

    /** Line cues whose endOffset lies strictly in (old, new]. Used for auto-fire. */
    fun linesFinishedBetween(oldProgress: Double, newProgress: Double): List<LineCueMarker> {
        if (text.isEmpty() || newProgress <= oldProgress) return emptyList()
        val total = text.length.toDouble()
        val oldIdx = (oldProgress * total).toInt()
        val newIdx = (newProgress * total).toInt()
        return lineCueEnds.filter { it.endOffset > oldIdx && it.endOffset <= newIdx }
    }

    companion object {
        fun from(blocking: Blocking): TeleprompterDocument {
            val ordered = blocking.marks
                .filter { it.sequenceIndex >= 0 }
                .sortedBy { it.sequenceIndex }

            val builder = StringBuilder()
            val markOffsets = mutableListOf<MarkOffset>()
            val lineCueEnds = mutableListOf<LineCueMarker>()

            for ((i, mark) in ordered.withIndex()) {
                val headerStart = builder.length
                builder.append("${mark.sequenceIndex + 1}. ${mark.name.uppercase()}\n")
                val beforeLines = builder.length

                for (cue in mark.cues) {
                    if (cue !is Cue.Line) continue
                    if (!cue.character.isNullOrEmpty()) {
                        builder.append("\n${cue.character.uppercase()}\n")
                    } else {
                        builder.append("\n")
                    }
                    val spokenStart = builder.length
                    builder.append(cue.text)
                    val spokenEnd = builder.length
                    lineCueEnds.add(LineCueMarker(mark.id, cue.id, spokenEnd))
                    builder.append("\n")
                }
                if (i < ordered.size - 1) builder.append("\n")

                markOffsets.add(MarkOffset(
                    markId = mark.id,
                    name = mark.name,
                    headerStart = headerStart,
                    firstLineStart = beforeLines,
                    endOffset = builder.length,
                ))
            }

            val text = builder.toString()
            return TeleprompterDocument(
                text = text,
                lowercasedText = text.lowercase(),
                markOffsets = markOffsets,
                lineCueEnds = lineCueEnds,
            )
        }
    }
}
