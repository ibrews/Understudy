package agilelens.understudy.ar

import android.opengl.GLES20
import android.util.Log
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import com.google.ar.core.exceptions.NotYetAvailableException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * DepthRenderer — Android analogue of the iOS LiDAR mesh ghost visualization.
 *
 * Samples `frame.acquireDepthImage16Bits()` each frame, maps each millimeter
 * value through a warm-to-cool color ramp (near = warm red, far = cool blue,
 * no-data = transparent), and draws the result as a translucent screen-space
 * quad sitting on top of the ARCore camera feed.
 *
 * ARCore's raw depth image is small (typically 160×120 or 256×192 depending
 * on the device), so we do the uint16 → RGBA8 color-ramp conversion on the
 * CPU each frame and upload the small RGBA texture to GL. That keeps the
 * shader trivial and avoids GLES20 limitations around 16-bit formats.
 *
 * Coordinate transform: we reuse ARCore's
 * `transformCoordinates2d(OPENGL_NDC → TEXTURE_NORMALIZED)` like the
 * camera background renderer, so the depth overlay stays aligned with the
 * camera image across device orientations.
 *
 * Depth API quirks worth remembering:
 *   - AUTOMATIC mode may still hand back no depth on the first few frames
 *     after resume — `acquireDepthImage16Bits()` throws `NotYetAvailableException`
 *     which we swallow silently.
 *   - Pixels with no valid depth read as 0 mm; we render those transparent.
 *   - The returned Image must be `close()`-d or ARCore will leak frames.
 */
class DepthRenderer {

    companion object {
        private const val TAG = "UnderstudyDepth"

        // Depth range used for the color ramp. Values are in millimeters (the raw units
        // of ARCore's DEPTH16 image). Anything outside [NEAR, FAR] clamps at the endpoint
        // color. Tuned for indoor / theatre-rehearsal distances.
        private const val DEPTH_NEAR_MM = 300      // 0.3 m
        private const val DEPTH_FAR_MM  = 6000     // 6 m

        // Overall opacity of the depth overlay when composited over the camera feed.
        private const val OVERLAY_ALPHA = 0.60f
    }

    // Full-screen quad in NDC space.
    private val quadCoords: FloatBuffer = run {
        val verts = floatArrayOf(
            -1f, -1f,
             1f, -1f,
            -1f,  1f,
             1f,  1f
        )
        ByteBuffer.allocateDirect(verts.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply { put(verts); position(0) }
    }

    // Texture coords — updated each frame via frame.transformCoordinates2d so the
    // depth overlay rotates with the device exactly like the camera background does.
    private val quadTexCoords: FloatBuffer =
        ByteBuffer.allocateDirect(4 * 2 * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                // Seed identity so the first frame isn't wildly wrong if
                // hasDisplayGeometryChanged() happens to be false.
                put(floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f))
                position(0)
            }

    private var textureId: Int = -1
    private var program: Int = 0
    private var positionAttrib: Int = 0
    private var texCoordAttrib: Int = 0
    private var textureUniform: Int = 0
    private var alphaUniform: Int = 0

    // Reusable CPU staging buffer sized to the last-seen depth image. Reallocated
    // when the depth image dimensions change (shouldn't happen in practice, but
    // some devices may switch modes).
    private var rgbaBuffer: ByteBuffer? = null
    private var lastWidth: Int = 0
    private var lastHeight: Int = 0

    fun createOnGlThread() {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)

        val vs = """
            attribute vec2 a_Position;
            attribute vec2 a_TexCoord;
            varying vec2 v_TexCoord;
            void main() {
                gl_Position = vec4(a_Position, 0.0, 1.0);
                v_TexCoord = a_TexCoord;
            }
        """.trimIndent()

        val fs = """
            precision mediump float;
            uniform sampler2D u_Texture;
            uniform float u_Alpha;
            varying vec2 v_TexCoord;
            void main() {
                vec4 c = texture2D(u_Texture, v_TexCoord);
                // RGBA is already the color ramp; alpha channel encodes
                // "has valid depth" (1.0) vs no-data (0.0). Modulate by
                // the global overlay alpha so the camera still reads through.
                gl_FragColor = vec4(c.rgb, c.a * u_Alpha);
            }
        """.trimIndent()

        val vsId = compile(GLES20.GL_VERTEX_SHADER, vs)
        val fsId = compile(GLES20.GL_FRAGMENT_SHADER, fs)
        program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vsId)
        GLES20.glAttachShader(program, fsId)
        GLES20.glLinkProgram(program)

        positionAttrib = GLES20.glGetAttribLocation(program, "a_Position")
        texCoordAttrib = GLES20.glGetAttribLocation(program, "a_TexCoord")
        textureUniform = GLES20.glGetUniformLocation(program, "u_Texture")
        alphaUniform   = GLES20.glGetUniformLocation(program, "u_Alpha")
    }

    private fun compile(type: Int, src: String): Int {
        val id = GLES20.glCreateShader(type)
        GLES20.glShaderSource(id, src)
        GLES20.glCompileShader(id)
        return id
    }

    /**
     * Draw the depth overlay for the given frame. Safe to call every frame:
     * if depth isn't available (not supported, not yet ready, or a transient
     * error), this method quietly does nothing and the camera feed shows
     * through unchanged.
     */
    fun draw(frame: Frame) {
        if (frame.timestamp == 0L) return

        // Keep tex coords aligned with the camera background whenever the
        // display geometry changes (orientation, resize, etc.).
        if (frame.hasDisplayGeometryChanged()) {
            // Reuse a scratch NDC buffer; small allocation is fine on geometry-change.
            val ndc = ByteBuffer.allocateDirect(4 * 2 * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .apply {
                    put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
                    position(0)
                }
            frame.transformCoordinates2d(
                Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
                ndc,
                Coordinates2d.TEXTURE_NORMALIZED,
                quadTexCoords
            )
            quadTexCoords.position(0)
        }

        val image = try {
            frame.acquireDepthImage16Bits()
        } catch (_: NotYetAvailableException) {
            return  // normal during first few frames / after a resume
        } catch (t: Throwable) {
            // Depth disabled or unsupported on this device — quietly skip.
            return
        }

        try {
            val w = image.width
            val h = image.height
            if (w <= 0 || h <= 0) return

            val plane = image.planes[0]
            val rowStride = plane.rowStride   // bytes per row
            val pixelStride = plane.pixelStride  // bytes per pixel (should be 2)
            val src = plane.buffer.order(ByteOrder.nativeOrder())

            val needed = w * h * 4
            val buf = rgbaBuffer?.takeIf { it.capacity() == needed && w == lastWidth && h == lastHeight }
                ?: ByteBuffer.allocateDirect(needed).order(ByteOrder.nativeOrder()).also {
                    rgbaBuffer = it
                    lastWidth = w
                    lastHeight = h
                }
            buf.clear()

            // Convert uint16 millimeter depth → RGBA color ramp, pixel by pixel.
            // Row-major, matching how GL_TEXTURE_2D expects its data.
            for (y in 0 until h) {
                val rowBase = y * rowStride
                for (x in 0 until w) {
                    val i = rowBase + x * pixelStride
                    // Little-endian uint16 → Int in [0, 65535]
                    val lo = src.get(i).toInt() and 0xFF
                    val hi = src.get(i + 1).toInt() and 0xFF
                    val depthMm = lo or (hi shl 8)
                    if (depthMm == 0) {
                        // No-data — fully transparent so the camera reads through.
                        buf.put(0).put(0).put(0).put(0)
                    } else {
                        val clamped = depthMm.coerceIn(DEPTH_NEAR_MM, DEPTH_FAR_MM)
                        val t = (clamped - DEPTH_NEAR_MM).toFloat() /
                            (DEPTH_FAR_MM - DEPTH_NEAR_MM).toFloat()
                        // Warm (near) → cool (far) ramp through green in the middle.
                        // r: 1.0 → 0.0   g: 0.0 → 1.0 → 0.0   b: 0.0 → 1.0
                        val r = (1f - t).coerceIn(0f, 1f)
                        val g = (1f - kotlin.math.abs(2f * t - 1f)).coerceIn(0f, 1f)
                        val b = t.coerceIn(0f, 1f)
                        buf.put((r * 255f).toInt().toByte())
                        buf.put((g * 255f).toInt().toByte())
                        buf.put((b * 255f).toInt().toByte())
                        buf.put(255.toByte())
                    }
                }
            }
            buf.position(0)

            // Upload. Reuse the texture object; allocate storage once per size.
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
            GLES20.glTexImage2D(
                GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA,
                w, h, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buf
            )

            // Blend the overlay over whatever was rendered before (camera feed).
            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
            GLES20.glDisable(GLES20.GL_DEPTH_TEST)
            GLES20.glDepthMask(false)

            GLES20.glUseProgram(program)
            GLES20.glUniform1i(textureUniform, 0)
            GLES20.glUniform1f(alphaUniform, OVERLAY_ALPHA)

            quadCoords.position(0)
            quadTexCoords.position(0)

            GLES20.glEnableVertexAttribArray(positionAttrib)
            GLES20.glVertexAttribPointer(positionAttrib, 2, GLES20.GL_FLOAT, false, 0, quadCoords)

            GLES20.glEnableVertexAttribArray(texCoordAttrib)
            GLES20.glVertexAttribPointer(texCoordAttrib, 2, GLES20.GL_FLOAT, false, 0, quadTexCoords)

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            GLES20.glDisableVertexAttribArray(positionAttrib)
            GLES20.glDisableVertexAttribArray(texCoordAttrib)

            GLES20.glDisable(GLES20.GL_BLEND)
            GLES20.glDepthMask(true)
            GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        } catch (t: Throwable) {
            Log.w(TAG, "depth render failed: ${t.message}")
        } finally {
            image.close()
        }
    }
}
