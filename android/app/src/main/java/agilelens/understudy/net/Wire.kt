package agilelens.understudy.net

import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json

/**
 * Shared Json configuration matching Swift's WireCoding on the iOS side.
 * - ignoreUnknownKeys: forward-compatibility; older peers may lack new fields.
 * - explicitNulls: Swift Codable emits `"field": null` for Optional values, so keep them.
 * - encodeDefaults: emit defaults (matches Swift).
 * - classDiscriminator is unused here because we hand-roll the enum encoding.
 */
@OptIn(ExperimentalSerializationApi::class)
val Wire: Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = true
    encodeDefaults = true
    isLenient = false
    prettyPrint = false
}
