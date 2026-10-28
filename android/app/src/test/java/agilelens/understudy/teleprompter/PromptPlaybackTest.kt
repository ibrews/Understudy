package agilelens.understudy.teleprompter

import agilelens.understudy.model.*
import org.junit.Assert.*
import org.junit.Test

class PromptPlaybackTest {
    private fun document(vararg lines: String): TeleprompterDocument = TeleprompterDocument.from(
        Blocking(Id("script"), createdAt = "", modifiedAt = "", marks = listOf(
            Mark(Id("mark"), "Opening", Pose(), sequenceIndex = 0,
                cues = lines.mapIndexed { index, text -> Cue.Line(Id("line-$index"), text, "ALEX") })
        ))
    )

    @Test fun singleLineAdvancesAtCueEndAndPreviewsBeforeFirstLine() {
        val doc = document("First cue.", "Second cue.")
        assertEquals("First cue.", PromptPlayback.prompt(doc, 0.0)?.text)
        val boundary = doc.spokenLines.first().endOffset.toDouble() / doc.text.length
        assertEquals("Second cue.", PromptPlayback.prompt(doc, boundary)?.text)
        assertEquals("ALEX", PromptPlayback.prompt(doc, boundary)?.character)
        assertNull(PromptPlayback.prompt(doc, 1.0))
    }

    @Test fun longCuePagesAdvanceAndPreserveAllText() {
        val text = "Keep every word, even when a speech goes beyond four visible lines. ".repeat(8)
        val doc = document(text)
        val chunks = PromptPlayback.chunks(text)
        assertTrue(chunks.size > 1)
        assertEquals(text, chunks.joinToString("") { text.substring(it.start, it.end) })
        chunks.forEachIndexed { index, page ->
            assertTrue(page.end - page.start <= 100)
            val progress = (doc.spokenLines.first().startOffset + page.start + 1).toDouble() / doc.text.length
            val prompt = PromptPlayback.prompt(doc, progress)!!
            assertEquals(index + 1, prompt.page)
            assertEquals(chunks.size, prompt.pages)
            assertEquals(text.substring(page.start, page.end), prompt.text)
        }
    }

    @Test fun chunksHandleLongWordsNewlinesAndSurrogatePairs() {
        val text = "Pneumonoultramicroscopicsilicovolcanoconiosis\n" + "a".repeat(49) + "😀".repeat(70)
        for (size in listOf(2, 16, 31, 100)) {
            val chunks = PromptPlayback.chunks(text, size)
            assertEquals(text, chunks.joinToString("") { text.substring(it.start, it.end) })
            for (chunk in chunks) {
                assertTrue(chunk.end > chunk.start)
                assertTrue(chunk.end - chunk.start <= size)
                assertFalse(text[chunk.start].isLowSurrogate())
                assertFalse(text[chunk.end - 1].isHighSurrogate())
            }
        }
    }

    @Test fun karaokeWindowHandlesEmptyEndAndInvalidRestoredProgress() {
        assertEquals(PromptPlayback.Window(0, 0), PromptPlayback.window("", 0.5))
        assertEquals(PromptPlayback.Window(3, 3), PromptPlayback.window("abc", 1.0))
        assertEquals(PromptPlayback.Window(3, 3), PromptPlayback.window("abc", 2.0))
        for (value in listOf(-1.0, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertEquals(0, PromptPlayback.window("abc", value).start)
        }
        val text = "a😀b"
        assertEquals(1, PromptPlayback.window(text, 0.5).start)
        assertEquals(1, PromptPlayback.window(text, 0.0, 2).end)
        assertEquals(3, PromptPlayback.window(text, 0.0, 3).end)
    }

    @Test fun elapsedTimingSurvivesFrameJitterAndSpeedChange() {
        val oneStep = PromptPlayback.advance(0.2, 20, 1000, 100)
        var manySteps = 0.2
        for (elapsed in listOf(33L, 167L, 300L, 500L)) {
            manySteps = PromptPlayback.advance(manySteps, 20, elapsed, 100)
        }
        assertEquals(0.4, oneStep, 0.00001)
        assertEquals(oneStep, manySteps, 0.00001)
        assertEquals(0.6, PromptPlayback.advance(oneStep, 40, 500, 100), 0.00001)
        assertEquals(1.0, PromptPlayback.advance(0.9, 40, 500, 100), 0.0)
        assertEquals(0.5, PromptPlayback.advance(0.5, 20, 1000, 0), 0.0)
        assertEquals(0.5, PromptPlayback.advance(0.5, 20, -20, 100), 0.0)
    }

    @Test fun manualDragSuppressesMarkFollowForThreeSeconds() {
        assertFalse(PromptPlayback.canFollowMark(3999, 1000))
        assertTrue(PromptPlayback.canFollowMark(4000, 1000))
    }

    @Test fun restoredProgressSelectsTheSamePageWithoutResumingPlayback() {
        val doc = document("Opening.", "Restored cue.")
        val savedProgress = (doc.spokenLines[1].startOffset + 2).toDouble() / doc.text.length
        val rebuilt = document("Opening.", "Restored cue.")
        assertEquals(PromptPlayback.prompt(doc, savedProgress), PromptPlayback.prompt(rebuilt, savedProgress))
        assertEquals("Restored cue.", PromptPlayback.prompt(rebuilt, savedProgress)?.text)
    }

    @Test fun documentExcludesCamerasUnsequencedMarksAndBlankCues() {
        val base = Mark(Id("actor"), "Start", Pose(), sequenceIndex = 0,
            cues = listOf(Cue.Line(Id("blank"), "  ", null), Cue.Line(Id("spoken"), "Say this.", null)))
        val doc = TeleprompterDocument.from(Blocking(Id(), createdAt = "", modifiedAt = "",
            marks = listOf(base.copy(id = Id("camera"), kind = MarkKind.camera),
                base.copy(id = Id("draft"), sequenceIndex = -1), base)))
        assertEquals(1, doc.spokenLines.size)
        assertEquals("Say this.", doc.spokenLines.single().text)
        assertEquals("Say this.", doc.text.substring(doc.spokenLines.single().startOffset, doc.spokenLines.single().endOffset))
        assertEquals(1, doc.markOffsets.size)
        assertEquals(2, doc.lineCueEnds.size)
    }
}
