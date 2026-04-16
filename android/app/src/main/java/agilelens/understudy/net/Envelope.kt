package agilelens.understudy.net

import agilelens.understudy.model.Blocking
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark
import agilelens.understudy.model.Performer
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * NetMessage — matches Swift `enum NetMessage: Codable`.
 *
 * Swift's default Codable enum encoding is a single-key object whose value is
 * ANOTHER object containing the associated values:
 *   - Unlabeled associated values → {"_0": v, "_1": v, ...}
 *   - Labeled   associated values → {"<label>": v, ...}
 *   - Nil optionals are OMITTED (not written as null).
 *
 * Verified empirically from Swift 5.10 JSONEncoder output.
 */
@Serializable(with = NetMessageSerializer::class)
sealed class NetMessage {
    data class Hello(val performer: Performer) : NetMessage()
    data class Goodbye(val id: Id) : NetMessage()
    data class PerformerUpdate(val performer: Performer) : NetMessage()
    data class BlockingSnapshot(val blocking: Blocking) : NetMessage()
    data class MarkAdded(val mark: Mark) : NetMessage()
    data class MarkUpdated(val mark: Mark) : NetMessage()
    data class MarkRemoved(val id: Id) : NetMessage()
    data class CueFired(val markID: Id, val cueID: Id, val by: Id) : NetMessage()
    data class PlaybackState(val t: Double?) : NetMessage()
}

object NetMessageSerializer : KSerializer<NetMessage> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("NetMessage")

    override fun serialize(encoder: Encoder, value: NetMessage) {
        require(encoder is JsonEncoder) { "NetMessageSerializer requires JSON" }
        val json = encoder.json

        val outer: JsonObject = buildJsonObject {
            when (value) {
                is NetMessage.Hello -> put("hello", buildJsonObject {
                    put("_0", json.encodeToJsonElement(Performer.serializer(), value.performer))
                })
                is NetMessage.Goodbye -> put("goodbye", buildJsonObject {
                    put("_0", json.encodeToJsonElement(Id.serializer(), value.id))
                })
                is NetMessage.PerformerUpdate -> put("performerUpdate", buildJsonObject {
                    put("_0", json.encodeToJsonElement(Performer.serializer(), value.performer))
                })
                is NetMessage.BlockingSnapshot -> put("blockingSnapshot", buildJsonObject {
                    put("_0", json.encodeToJsonElement(Blocking.serializer(), value.blocking))
                })
                is NetMessage.MarkAdded -> put("markAdded", buildJsonObject {
                    put("_0", json.encodeToJsonElement(Mark.serializer(), value.mark))
                })
                is NetMessage.MarkUpdated -> put("markUpdated", buildJsonObject {
                    put("_0", json.encodeToJsonElement(Mark.serializer(), value.mark))
                })
                is NetMessage.MarkRemoved -> put("markRemoved", buildJsonObject {
                    put("_0", json.encodeToJsonElement(Id.serializer(), value.id))
                })
                is NetMessage.CueFired -> put("cueFired", buildJsonObject {
                    put("markID", json.encodeToJsonElement(Id.serializer(), value.markID))
                    put("cueID", json.encodeToJsonElement(Id.serializer(), value.cueID))
                    put("by", json.encodeToJsonElement(Id.serializer(), value.by))
                })
                is NetMessage.PlaybackState -> put("playbackState", buildJsonObject {
                    // Swift omits nil — do the same so round-trip matches.
                    value.t?.let { put("t", JsonPrimitive(it)) }
                })
            }
        }
        encoder.encodeJsonElement(outer)
    }

    override fun deserialize(decoder: Decoder): NetMessage {
        require(decoder is JsonDecoder) { "NetMessageSerializer requires JSON" }
        val json = decoder.json
        val obj = decoder.decodeJsonElement().jsonObject
        val (key, payload) = obj.entries.first()
        val inner = payload.jsonObject
        return when (key) {
            "hello" -> NetMessage.Hello(
                json.decodeFromJsonElement(Performer.serializer(), inner.getValue("_0"))
            )
            "goodbye" -> NetMessage.Goodbye(
                json.decodeFromJsonElement(Id.serializer(), inner.getValue("_0"))
            )
            "performerUpdate" -> NetMessage.PerformerUpdate(
                json.decodeFromJsonElement(Performer.serializer(), inner.getValue("_0"))
            )
            "blockingSnapshot" -> NetMessage.BlockingSnapshot(
                json.decodeFromJsonElement(Blocking.serializer(), inner.getValue("_0"))
            )
            "markAdded" -> NetMessage.MarkAdded(
                json.decodeFromJsonElement(Mark.serializer(), inner.getValue("_0"))
            )
            "markUpdated" -> NetMessage.MarkUpdated(
                json.decodeFromJsonElement(Mark.serializer(), inner.getValue("_0"))
            )
            "markRemoved" -> NetMessage.MarkRemoved(
                json.decodeFromJsonElement(Id.serializer(), inner.getValue("_0"))
            )
            "cueFired" -> NetMessage.CueFired(
                markID = json.decodeFromJsonElement(Id.serializer(), inner.getValue("markID")),
                cueID = json.decodeFromJsonElement(Id.serializer(), inner.getValue("cueID")),
                by = json.decodeFromJsonElement(Id.serializer(), inner.getValue("by"))
            )
            "playbackState" -> NetMessage.PlaybackState(
                t = inner["t"]?.jsonPrimitive?.doubleOrNull
            )
            else -> throw IllegalArgumentException("Unknown NetMessage case: $key")
        }
    }
}

@Serializable
data class Envelope(
    val version: Int = 1,
    val senderID: Id,
    val message: NetMessage
) {
    companion object { const val CURRENT_VERSION = 1 }
}
