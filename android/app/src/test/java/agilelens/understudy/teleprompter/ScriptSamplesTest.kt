package agilelens.understudy.teleprompter

import agilelens.understudy.model.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class ScriptSamplesTest {
    private val assets = File("src/main/assets")

    @Test fun allBundledScriptsUseTheProductionDecoderAndRoundTrip() {
        assertEquals("hamlet.json", Scripts.all.first().assetName)
        assertTrue(Scripts.samples.size >= 11)
        assertEquals(Scripts.all.size, Scripts.all.map { it.assetName }.toSet().size)
        for (ref in Scripts.all) {
            val script = Scripts.parse(File(assets, ref.assetName).readText())
            assertTrue(ref.assetName, script.allLines.isNotEmpty())
            assertEquals(script, Scripts.parse(Json.encodeToString(script)))
            assertTrue(script.allLines.all { it.text.isNotBlank() && it.character.isNotBlank() })
            assertEquals(script.allLines.size, script.allLines.map { it.lineID }.toSet().size)
            assertTrue(script.allLines.all { it.lineID.matches(Regex("[0-9]+\\.[0-9]+\\.[0-9]+")) })
        }
    }

    @Test fun oneTapImportPreservesExistingCuesAndAppendsInReadingOrder() {
        val note = Cue.Note(Id("note"), "Keep the existing stage direction")
        val original = Mark(Id("mark"), "Opening", Pose(x = 2f), sequenceIndex = 4, cues = listOf(note))
        for (sample in Scripts.samples) {
            val script = Scripts.parse(File(assets, sample.assetName).readText())
            val loaded = original.withAppendedScript(script)
            assertEquals(original.id, loaded.id)
            assertEquals(original.pose, loaded.pose)
            assertEquals(original.sequenceIndex, loaded.sequenceIndex)
            assertEquals(note, loaded.cues.first())
            val lines = loaded.cues.filterIsInstance<Cue.Line>()
            assertEquals(script.allLines.map { it.text }, lines.map { it.text })
            assertEquals(script.allLines.map { it.character }, lines.map { it.character })
            assertEquals(lines.size, lines.map { it.id }.toSet().size)
            assertEquals(listOf(note), original.cues)
            val doc = TeleprompterDocument.from(Blocking(Id(), createdAt = "", modifiedAt = "", marks = listOf(loaded)))
            assertEquals(lines.size, doc.spokenLines.size)
            assertEquals(lines.first().text.take(20), PromptPlayback.prompt(doc, 0.0)!!.text.take(20))
        }
    }

    @Test fun demoIsAboutThreeMinutesAndDoesNotAssertDeviceReadiness() {
        val demo = Scripts.parse(File(assets, "sample-aura-walkthrough.json").readText())
        val text = demo.allLines.joinToString(" ") { it.text }
        val words = text.split(Regex("\\s+")).size
        assertTrue("$words words", words in 350..430)
        for (topic in listOf("XREAL Aura", "AuraColocate", "Unreal 5.8.4", "foveation", "hands", "splat", "Stage Presence", "Understudy")) {
            assertTrue(topic, text.contains(topic))
        }
        assertTrue(text.contains("If"))
        assertTrue(text.contains("separate glasses companion"))
    }

    @Test fun malformedAndUnknownEntryKindsFailInsteadOfSilentlyDroppingDialogue() {
        for (json in listOf("not JSON", "{}", """{"title":"Bad","author":"Test","acts":[{"number":1,"roman":"I","scenes":[{"number":1,"roman":"I","location":"","entries":[{"kind":"unknown","text":"Keep me"}]}]}]}""")) {
            assertTrue(runCatching { Scripts.parse(json) }.isFailure)
        }
    }
}
