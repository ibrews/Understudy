package agilelens.understudy.model

import kotlin.math.atan

/**
 * Lens math + common presets for `CameraSpec`. Lives outside `CoreModels.kt`
 * to keep the wire-format-defining data class untouched — these are all
 * derived values that don't need serialization.
 *
 * Mirrors Swift's `CameraSpec.horizontalFOV` / `.verticalFOV` / `.presets`
 * so iOS and Android render the same FOV wedge for the same spec.
 */

/** Horizontal field of view in radians: 2 * atan(sensorWidth / (2 * focal)). */
val CameraSpec.horizontalFOV: Float
    get() = 2f * atan(sensorWidthMM / (2f * focalLengthMM))

/** Vertical field of view in radians. */
val CameraSpec.verticalFOV: Float
    get() = 2f * atan(sensorHeightMM / (2f * focalLengthMM))

/** Frame aspect ratio (width / height), fallback 1.5 if height is zero. */
val CameraSpec.aspectRatio: Float
    get() = if (sensorHeightMM > 0f) sensorWidthMM / sensorHeightMM else 1.5f

/** "35mm · 1.50:1 · 1.55m" — human-readable UI label. */
val CameraSpec.shortLabel: String
    get() = "%.0fmm · %.2f:1 · %.2fm".format(focalLengthMM, aspectRatio, heightM)

/**
 * Common 35mm-equivalent primes — matches the six preset chips on iOS.
 * Sensor defaults to full-frame (36×24mm) so HFOVs line up with iOS.
 */
object LensPresets {
    val preset14mm = CameraSpec(focalLengthMM = 14f)
    val preset24mm = CameraSpec(focalLengthMM = 24f)
    val preset35mm = CameraSpec(focalLengthMM = 35f)
    val preset50mm = CameraSpec(focalLengthMM = 50f)
    val preset85mm = CameraSpec(focalLengthMM = 85f)
    val preset135mm = CameraSpec(focalLengthMM = 135f)
    val all: List<CameraSpec> = listOf(
        preset14mm, preset24mm, preset35mm, preset50mm, preset85mm, preset135mm
    )
    /** Focal lengths for chip display, in mm. */
    val focalLengthsMM: List<Float> = all.map { it.focalLengthMM }
}

/**
 * Common sensor-size presets for the author picker. Width × height in mm.
 * Full-frame is the default; Super-35 and S16 for film look; 2/3" for broadcast.
 */
data class SensorPreset(val name: String, val widthMM: Float, val heightMM: Float)

object SensorPresets {
    val fullFrame  = SensorPreset("Full-frame",  36.0f, 24.0f)
    val super35    = SensorPreset("Super 35",    24.89f, 18.66f)
    val s16        = SensorPreset("Super 16",    12.52f, 7.41f)
    val micro43    = SensorPreset("Micro 4/3",   17.3f, 13.0f)
    val apsc       = SensorPreset("APS-C",       23.6f, 15.6f)
    val all: List<SensorPreset> = listOf(fullFrame, super35, apsc, micro43, s16)
}
