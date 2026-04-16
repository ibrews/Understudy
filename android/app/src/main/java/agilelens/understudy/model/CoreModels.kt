package agilelens.understudy.model

import kotlinx.serialization.Serializable
import java.util.UUID
import kotlin.math.sqrt

/**
 * ID — matches Swift's `struct ID { let raw: String }`.
 * On the wire: { "raw": "..." }.
 */
@Serializable
data class Id(val raw: String = UUID.randomUUID().toString()) {
    override fun toString(): String = raw
}

/**
 * World-space pose. Matches Swift `struct Pose`.
 * Units: meters, yaw in radians about +Y (world up).
 */
@Serializable
data class Pose(
    val x: Float = 0f,
    val y: Float = 0f,
    val z: Float = 0f,
    val yaw: Float = 0f
) {
    fun distance(other: Pose): Float {
        val dx = x - other.x; val dy = y - other.y; val dz = z - other.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
}

/**
 * Light colors — Swift `enum LightColor: String`.
 * Serializes as a string: "warm" | "cool" | ... | "blackout".
 */
@Serializable
enum class LightColor {
    warm, cool, red, blue, green, amber, blackout
}

/**
 * Performer role — matches Swift `Performer.Role: String`.
 */
@Serializable
enum class Role {
    director, performer, observer
}

@Serializable
data class Performer(
    val id: Id,
    val displayName: String,
    val role: Role = Role.performer,
    val pose: Pose = Pose(),
    val trackingQuality: Float = 1.0f,
    val currentMarkID: Id? = null
)

@Serializable
data class Mark(
    val id: Id,
    val name: String,
    val pose: Pose,
    val radius: Float = 0.6f,
    val cues: List<Cue> = emptyList(),
    val sequenceIndex: Int = -1
)

@Serializable
data class RecordedWalkSample(
    val t: Double,
    val pose: Pose
)

@Serializable
data class RecordedWalk(
    val performerName: String,
    val samples: List<RecordedWalkSample>,
    val duration: Double
)

@Serializable
data class Blocking(
    val id: Id,
    val title: String = "Untitled Piece",
    val authorName: String = "",
    val createdAt: String,   // ISO-8601
    val modifiedAt: String,  // ISO-8601
    val marks: List<Mark> = emptyList(),
    val origin: Pose = Pose(),
    val reference: RecordedWalk? = null
) {
    /** Mark containing the given pose — closest-by-center wins on overlap. */
    fun markContaining(pose: Pose): Mark? =
        marks
            .asSequence()
            .map { it to it.pose.distance(pose) }
            .filter { it.second <= it.first.radius }
            .minByOrNull { it.second }
            ?.first
}
