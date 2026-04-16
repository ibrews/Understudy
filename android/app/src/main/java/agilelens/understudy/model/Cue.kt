package agilelens.understudy.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.float
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Cue — matches Swift `enum Cue: Codable`.
 *
 * All Swift cases have LABELED associated values, so Swift encodes each as
 *   `{"<caseName>": {"label1": v1, "label2": v2, ...}}`
 * Nil optionals are OMITTED entirely (so a nil `character` means the key is absent).
 */
@Serializable(with = CueSerializer::class)
sealed class Cue {
    abstract val id: Id

    data class Line(override val id: Id, val text: String, val character: String?) : Cue()
    data class Sfx(override val id: Id, val name: String) : Cue()
    data class Light(override val id: Id, val color: LightColor, val intensity: Float) : Cue()
    data class Note(override val id: Id, val text: String) : Cue()
    data class Wait(override val id: Id, val seconds: Double) : Cue()
}

object CueSerializer : KSerializer<Cue> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("Cue")

    override fun serialize(encoder: Encoder, value: Cue) {
        require(encoder is JsonEncoder) { "CueSerializer requires JSON" }
        val json = encoder.json
        val outer = buildJsonObject {
            when (value) {
                is Cue.Line -> put("line", buildJsonObject {
                    put("id", json.encodeToJsonElement(Id.serializer(), value.id))
                    put("text", JsonPrimitive(value.text))
                    // Swift omits nil optionals entirely.
                    value.character?.let { put("character", JsonPrimitive(it)) }
                })
                is Cue.Sfx -> put("sfx", buildJsonObject {
                    put("id", json.encodeToJsonElement(Id.serializer(), value.id))
                    put("name", JsonPrimitive(value.name))
                })
                is Cue.Light -> put("light", buildJsonObject {
                    put("id", json.encodeToJsonElement(Id.serializer(), value.id))
                    put("color", JsonPrimitive(value.color.name))
                    put("intensity", JsonPrimitive(value.intensity))
                })
                is Cue.Note -> put("note", buildJsonObject {
                    put("id", json.encodeToJsonElement(Id.serializer(), value.id))
                    put("text", JsonPrimitive(value.text))
                })
                is Cue.Wait -> put("wait", buildJsonObject {
                    put("id", json.encodeToJsonElement(Id.serializer(), value.id))
                    put("seconds", JsonPrimitive(value.seconds))
                })
            }
        }
        encoder.encodeJsonElement(outer)
    }

    override fun deserialize(decoder: Decoder): Cue {
        require(decoder is JsonDecoder) { "CueSerializer requires JSON" }
        val json = decoder.json
        val obj = decoder.decodeJsonElement().jsonObject
        val (key, payload) = obj.entries.first()
        val inner = payload.jsonObject
        val id = json.decodeFromJsonElement(Id.serializer(), inner.getValue("id"))
        return when (key) {
            "line" -> Cue.Line(
                id = id,
                text = inner.getValue("text").jsonPrimitive.content,
                character = inner["character"]?.jsonPrimitive?.contentOrNull
            )
            "sfx" -> Cue.Sfx(id, inner.getValue("name").jsonPrimitive.content)
            "light" -> Cue.Light(
                id = id,
                color = LightColor.valueOf(inner.getValue("color").jsonPrimitive.content),
                intensity = inner.getValue("intensity").jsonPrimitive.float
            )
            "note" -> Cue.Note(id, inner.getValue("text").jsonPrimitive.content)
            "wait" -> Cue.Wait(id, inner.getValue("seconds").jsonPrimitive.double)
            else -> throw IllegalArgumentException("Unknown Cue case: $key")
        }
    }
}

fun Cue.humanLabel(): String = when (this) {
    is Cue.Line -> character?.let { "$it: $text" } ?: text
    is Cue.Sfx -> "♪ $name"
    is Cue.Light -> "◐ ${color.name}"
    is Cue.Note -> "note: $text"
    is Cue.Wait -> "• hold ${"%.1f".format(seconds)}s"
}
