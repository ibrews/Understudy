package agilelens.understudy.cuefx

import agilelens.understudy.model.LightColor
import kotlin.math.max
import kotlin.math.min

/**
 * Kotlin port of Swift's DMXCueMapping.swift.
 *
 * Translates an abstract [LightColor] + intensity into a 512-byte DMX frame
 * across a small rig of fixtures. Default: 4 × 5-channel RGBW+dim pars at
 * addresses 1, 6, 11, 16 — the same default as the iOS build.
 */
data class DMXFixtureProfile(
    val footprint: Int,
    val red: Int? = null,
    val green: Int? = null,
    val blue: Int? = null,
    val white: Int? = null,
    val amber: Int? = null,
    val intensity: Int? = null,
) {
    companion object {
        /** 5-channel RGBW + dimmer: [dim, R, G, B, W]. */
        val rgbwDim5 = DMXFixtureProfile(
            footprint = 5,
            red = 1, green = 2, blue = 3, white = 4, intensity = 0,
        )
    }
}

data class DMXFixture(
    val name: String,
    /** 1-based DMX address (matches console UI conventions). */
    val startChannel: Int,
    val profile: DMXFixtureProfile,
)

data class RGBWA(val r: Int, val g: Int, val b: Int, val w: Int, val a: Int)

class DMXCueMapping(
    val fixtures: List<DMXFixture> = defaultFixtures,
) {
    companion object {
        val defaultFixtures: List<DMXFixture> = listOf(
            DMXFixture("Par 1", startChannel = 1,  profile = DMXFixtureProfile.rgbwDim5),
            DMXFixture("Par 2", startChannel = 6,  profile = DMXFixtureProfile.rgbwDim5),
            DMXFixture("Par 3", startChannel = 11, profile = DMXFixtureProfile.rgbwDim5),
            DMXFixture("Par 4", startChannel = 16, profile = DMXFixtureProfile.rgbwDim5),
        )

        fun rgbwa(color: LightColor): RGBWA = when (color) {
            LightColor.warm     -> RGBWA(255, 180,  80, 255, 180)
            LightColor.cool     -> RGBWA(140, 200, 255, 255,   0)
            LightColor.red      -> RGBWA(255,   0,   0,   0,   0)
            LightColor.blue     -> RGBWA(  0,   0, 255,   0,   0)
            LightColor.green    -> RGBWA(  0, 255,   0,   0,   0)
            LightColor.amber    -> RGBWA(255, 160,   0,   0, 255)
            LightColor.blackout -> RGBWA(  0,   0,   0,   0,   0)
        }
    }

    /**
     * Build a full 512-slot DMX universe for a light cue. Every fixture in
     * the rig lights the same color at [intensity] (0..1). Mirrors
     * DMXCueMapping.frame(for:intensity:) in Swift.
     */
    fun frame(color: LightColor, intensity: Float): ByteArray {
        val frame = ByteArray(512)
        val c = rgbwa(color)
        val dim = max(0, min(255, (intensity.coerceIn(0f, 1f) * 255).toInt()))

        fun scale(v: Int): Byte = max(0, min(255, v * dim / 255)).toByte()

        for (fixture in fixtures) {
            val base = fixture.startChannel - 1   // 0-based slot index
            if (base < 0 || base + fixture.profile.footprint > 512) continue
            val p = fixture.profile
            val hasDim = p.intensity != null

            p.intensity?.let { frame[base + it] = dim.toByte() }

            // If no dimmer channel, pre-multiply RGBW by dim so the colour
            // is still intensity-scaled on RGB-only fixtures.
            val r: Byte = if (hasDim) c.r.toByte() else scale(c.r)
            val g: Byte = if (hasDim) c.g.toByte() else scale(c.g)
            val b: Byte = if (hasDim) c.b.toByte() else scale(c.b)
            val w: Byte = if (hasDim) c.w.toByte() else scale(c.w)
            val a: Byte = if (hasDim) c.a.toByte() else scale(c.a)

            p.red?.let   { frame[base + it] = r }
            p.green?.let { frame[base + it] = g }
            p.blue?.let  { frame[base + it] = b }
            p.white?.let { frame[base + it] = w }
            p.amber?.let { frame[base + it] = a }
        }
        return frame
    }
}
