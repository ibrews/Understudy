package agilelens.understudy.teleprompter

import agilelens.understudy.model.Cue
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark
import agilelens.understudy.model.Pose
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Kotlin port of Swift's ScenePlacer. Given a scene from a bundled play
 * and an origin pose, generate a zig-zag walk of Marks with the scene's
 * dialogue bucketed by speaker (max 4 lines per beat). Stage directions
 * attach as leading/trailing .note cues on the beat's Mark.
 */
object ScenePlacer {

    private const val MAX_LINES_PER_BEAT = 4

    fun layout(
        scene: PlayScript.Scene,
        origin: Pose,
        spacing: Float = 1.2f,
        lateralOffset: Float = 0.8f,
        sequenceOffset: Int = 0,
    ): List<Mark> {
        val beats = bucket(scene.entries)

        // Author's forward direction (phone's yaw) = (sin, 0, -cos).
        val forwardX = sin(origin.yaw)
        val forwardZ = -cos(origin.yaw)
        // Right vector = (cos, 0, sin).
        val rightX = cos(origin.yaw)
        val rightZ = sin(origin.yaw)

        val out = mutableListOf<Mark>()
        for ((i, beat) in beats.withIndex()) {
            val side = if (i % 2 == 0) -1f else 1f
            val step = (i + 1) * spacing
            val posX = origin.x + forwardX * step + rightX * side * lateralOffset
            val posZ = origin.z + forwardZ * step + rightZ * side * lateralOffset

            // Yaw toward the next beat (or center for the last beat).
            val yaw: Float = if (i < beats.size - 1) {
                val nextSide = if ((i + 1) % 2 == 0) -1f else 1f
                val nextX = origin.x + forwardX * (i + 2) * spacing +
                    rightX * nextSide * lateralOffset
                val nextZ = origin.z + forwardZ * (i + 2) * spacing +
                    rightZ * nextSide * lateralOffset
                val dx = nextX - posX
                val dz = nextZ - posZ
                atan2(dx, -dz)
            } else {
                // Point back toward the spine — away from the lateral offset.
                atan2(-rightX * side * lateralOffset, rightZ * side * lateralOffset)
            }

            out.add(Mark(
                id = Id(),
                name = beat.title,
                pose = Pose(x = posX, y = 0f, z = posZ, yaw = yaw),
                radius = 0.6f,
                cues = beat.cues(),
                sequenceIndex = sequenceOffset + i,
            ))
        }
        return out
    }

    private data class Beat(
        val leadingStage: MutableList<String> = mutableListOf(),
        var speaker: String = "",
        val lines: MutableList<Pair<String, String>> = mutableListOf(),  // (character, text)
        val trailingStage: MutableList<String> = mutableListOf(),
    ) {
        val title: String
            get() = when {
                lines.isNotEmpty() -> lines[0].first.replaceFirstChar { it.uppercase() }
                leadingStage.isNotEmpty() ->
                    leadingStage.first().let { if (it.length > 24) it.take(23) + "…" else it }
                else -> "Beat"
            }

        fun cues(): List<Cue> = buildList {
            for (stage in leadingStage) {
                add(Cue.Note(id = Id(), text = stage))
            }
            for ((character, text) in lines) {
                add(Cue.Line(id = Id(), text = text, character = character))
            }
            for (stage in trailingStage) {
                add(Cue.Note(id = Id(), text = stage))
            }
        }
    }

    private fun bucket(entries: List<PlayScript.Entry>): List<Beat> {
        val raw = mutableListOf<Beat>()
        var current = Beat()

        fun flush() {
            if (current.lines.isNotEmpty() || current.leadingStage.isNotEmpty()) {
                raw.add(current)
            }
            current = Beat()
        }

        for (entry in entries) {
            when (entry) {
                is PlayScript.Entry.Stage -> {
                    if (current.lines.isEmpty()) current.leadingStage.add(entry.text)
                    else current.trailingStage.add(entry.text)
                }
                is PlayScript.Entry.Line -> {
                    if (current.lines.isEmpty()) {
                        current.speaker = entry.character
                        current.lines.add(entry.character to entry.text)
                    } else if (entry.character == current.speaker &&
                        current.lines.size < MAX_LINES_PER_BEAT
                    ) {
                        current.lines.add(entry.character to entry.text)
                    } else {
                        flush()
                        current.speaker = entry.character
                        current.lines.add(entry.character to entry.text)
                    }
                }
            }
        }
        flush()

        // Merge leading-stage-only beats into the next beat so every output
        // mark has at least one line (unless the whole scene has no lines).
        val merged = mutableListOf<Beat>()
        val carry = mutableListOf<String>()
        for (beat in raw) {
            if (beat.lines.isEmpty()) {
                carry.addAll(beat.leadingStage)
                carry.addAll(beat.trailingStage)
            } else {
                val b = beat.copy(
                    leadingStage = (carry + beat.leadingStage).toMutableList()
                )
                carry.clear()
                merged.add(b)
            }
        }
        if (carry.isNotEmpty() && merged.isNotEmpty()) {
            merged.last().trailingStage.addAll(carry)
        } else if (carry.isNotEmpty()) {
            merged.add(Beat(leadingStage = carry.toMutableList()))
        }
        return merged
    }
}
