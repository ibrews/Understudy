package agilelens.understudy.model

import agilelens.understudy.net.Envelope
import agilelens.understudy.net.NetMessage
import agilelens.understudy.net.Wire
import kotlinx.serialization.decodeFromString
import org.junit.Test
import org.junit.Assert.*
import java.io.File

/**
 * Round-trip every fixture from `/test-fixtures/` (Swift-generated JSON)
 * through the Kotlin decoder. This catches platform drift the moment Swift
 * adds a field or changes a shape — if Kotlin can't decode a Swift fixture,
 * the test fails with a clear diff instead of silently dropping data at
 * runtime during a real rehearsal.
 *
 * Fixtures are regenerated from Swift via `test-fixtures/regenerate.sh`.
 */
class WireCompatTest {

    private val fixturesDir = File("../../test-fixtures")

    @Test
    fun allNetMessageFixturesDecode() {
        require(fixturesDir.exists()) {
            "Test fixtures not found at ${fixturesDir.absolutePath}"
        }
        val files = fixturesDir.listFiles { f -> f.name.startsWith("netmsg-") && f.extension == "json" }
            ?: emptyArray()
        assertTrue("Expected fixtures on disk", files.isNotEmpty())

        for (file in files) {
            val json = file.readText()
            try {
                val env = Wire.decodeFromString<Envelope>(json)
                assertEquals(1, env.version)
                assertNotNull(env.senderID.raw)
                // Sanity — the message is non-null by type.
                val msg: NetMessage = env.message
                assertNotNull(msg)
            } catch (t: Throwable) {
                fail("Fixture ${file.name} failed to decode: ${t.message}\n${json.take(400)}")
            }
        }
    }

    @Test
    fun allCueFixturesDecode() {
        val files = fixturesDir.listFiles { f -> f.name.startsWith("cue-") && f.extension == "json" }
            ?: emptyArray()
        assertTrue("Expected cue fixtures", files.isNotEmpty())
        for (file in files) {
            val json = file.readText()
            try {
                val cue = Wire.decodeFromString<Cue>(json)
                assertNotNull(cue.id)
            } catch (t: Throwable) {
                fail("Cue fixture ${file.name} failed: ${t.message}\n$json")
            }
        }
    }

    @Test
    fun markWithCameraKindRoundTrips() {
        // Exercise the v0.8 fields — a camera mark encoded from Kotlin
        // should decode back with the same kind + camera.
        val original = Mark(
            id = Id("test-1"),
            name = "Cam 1 · 35mm",
            pose = Pose(x = 1f, y = 0f, z = -2f, yaw = 0f),
            radius = 0.4f,
            cues = emptyList(),
            sequenceIndex = -1,
            kind = MarkKind.camera,
            camera = CameraSpec(focalLengthMM = 35f, heightM = 1.55f)
        )
        val json = Wire.encodeToString(Mark.serializer(), original)
        val decoded = Wire.decodeFromString(Mark.serializer(), json)
        assertEquals(MarkKind.camera, decoded.kind)
        assertNotNull(decoded.camera)
        assertEquals(35f, decoded.camera!!.focalLengthMM, 0.001f)
        assertEquals(1.55f, decoded.camera!!.heightM, 0.001f)
    }

    @Test
    fun legacyActorMarkWithoutKindFieldStillDecodes() {
        // v0.1-v0.7 `.understudy` files and older peers' wire messages
        // have no `kind` / `camera` keys. They should still parse as
        // actor marks with no camera.
        val legacyJson = """
            {
              "id": {"raw": "legacy-1"},
              "name": "Francisco's Post",
              "pose": {"x": 0.0, "y": 0.0, "z": -2.0, "yaw": 0.0},
              "radius": 0.7,
              "cues": [],
              "sequenceIndex": 0
            }
        """.trimIndent()
        val decoded = Wire.decodeFromString(Mark.serializer(), legacyJson)
        assertEquals(MarkKind.actor, decoded.kind)
        assertNull(decoded.camera)
        assertEquals("Francisco's Post", decoded.name)
    }

    @Test
    fun blockingWithRoomScanRoundTrips() {
        // Exercise the v0.9 field — a Blocking with a RoomScan should
        // survive encode/decode without dropping the scan.
        val scan = RoomScan(
            positionsBase64 = "AAAAAA==",  // four zero bytes = one Float32 zero
            indicesBase64 = "AAAAAA==",
            capturedAt = "2026-04-16T12:00:00Z",
            name = "Test scan"
        )
        val blocking = Blocking(
            id = Id("b-1"),
            title = "Test",
            createdAt = "2026-04-16T12:00:00Z",
            modifiedAt = "2026-04-16T12:00:00Z",
            roomScan = scan
        )
        val json = Wire.encodeToString(Blocking.serializer(), blocking)
        val decoded = Wire.decodeFromString(Blocking.serializer(), json)
        assertNotNull(decoded.roomScan)
        assertEquals("Test scan", decoded.roomScan!!.name)
        assertEquals("AAAAAA==", decoded.roomScan!!.positionsBase64)
    }

    @Test
    fun legacyBlockingWithoutRoomScanStillDecodes() {
        val legacyJson = """
            {
              "id": {"raw": "b-legacy"},
              "title": "Scene 1",
              "authorName": "",
              "createdAt": "2026-01-01T00:00:00Z",
              "modifiedAt": "2026-01-01T00:00:00Z",
              "marks": [],
              "origin": {"x": 0, "y": 0, "z": 0, "yaw": 0}
            }
        """.trimIndent()
        val decoded = Wire.decodeFromString(Blocking.serializer(), legacyJson)
        assertNull(decoded.roomScan)
        assertNull(decoded.reference)
    }
}
