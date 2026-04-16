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

/**
 * Mark kind — actor marks drive the performer teleprompter + cueing;
 * camera marks are pre-viz references with lens metadata. Mirrors Swift's
 * `MarkKind` (added in iOS v0.8). Missing on older `.understudy` files;
 * the decoder defaults to ACTOR so pre-v0.8 files still load.
 */
@Serializable
enum class MarkKind {
    actor, camera
}

/**
 * Camera lens metadata — mirrors Swift's `CameraSpec` (iOS v0.8).
 * Nil/null on actor marks. Units are mm for focal length + sensor dims,
 * meters for height, radians for tilt.
 */
@Serializable
data class CameraSpec(
    val focalLengthMM: Float = 35f,
    val sensorWidthMM: Float = 36f,
    val sensorHeightMM: Float = 24f,
    val heightM: Float = 1.55f,
    val tiltRadians: Float = 0f
)

@Serializable
data class Mark(
    val id: Id,
    val name: String,
    val pose: Pose,
    val radius: Float = 0.6f,
    val cues: List<Cue> = emptyList(),
    val sequenceIndex: Int = -1,
    /** Actor or camera mark. Defaults to ACTOR so pre-v0.8 files still load. */
    val kind: MarkKind = MarkKind.actor,
    /** Lens metadata — non-null only for camera marks. Omitted on actor marks. */
    val camera: CameraSpec? = null
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

/**
 * LiDAR room scan — mirrors Swift's `RoomScan` (iOS v0.9).
 *
 * Android can ROUND-TRIP scans received over the wire or loaded from
 * .understudy files, but doesn't yet render them (no RealityKit-equivalent
 * wireframe ghost pipeline in Compose / ARCore). This field exists so that
 * an Android device in a mixed-platform rehearsal doesn't silently strip
 * the scan when the Blocking gets re-broadcast.
 *
 * Positions: base64 of interleaved big-endian Float32 xyz (12 bytes/vertex).
 * Indices:   base64 of big-endian UInt32 triangle corner indices.
 * overlayOffset: yaw + translation applied when rendering the scan.
 */
@Serializable
data class RoomScan(
    val positionsBase64: String,
    val indicesBase64: String,
    /** ISO-8601 capture timestamp. */
    val capturedAt: String,
    val name: String = "Room scan",
    val overlayOffset: Pose = Pose()
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
    val reference: RecordedWalk? = null,
    /** LiDAR scan from a peer iPhone Pro. Defaulted to null so pre-v0.9
     *  `.understudy` files still load unchanged. Preserved through decode
     *  + encode so Android can re-broadcast without data loss. */
    val roomScan: RoomScan? = null
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
