package agilelens.understudy.ar

import android.opengl.GLES11Ext
import android.opengl.GLES20
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Minimal ARCore camera-feed renderer.
 *
 * Adapted from Google's ARCore Java sample (BackgroundRenderer.java) — a single
 * OES texture sampled by a tiny pass-through shader across a fullscreen quad,
 * with texture coordinates transformed per-frame via Frame.transformCoordinates2d
 * so the image stays right-side-up whatever the device orientation.
 */
class BackgroundRenderer {

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

    private val quadTexCoords: FloatBuffer =
        ByteBuffer.allocateDirect(4 * 2 * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()

    private val quadTexCoordsTransformed: FloatBuffer =
        ByteBuffer.allocateDirect(4 * 2 * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()

    var textureId: Int = -1
        private set

    private var program: Int = 0
    private var positionAttrib: Int = 0
    private var texCoordAttrib: Int = 0
    private var textureUniform: Int = 0

    fun createOnGlThread() {
        // Create the OES external texture ARCore will fill each frame.
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)

        // --- shaders ---
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
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            uniform samplerExternalOES u_Texture;
            varying vec2 v_TexCoord;
            void main() {
                gl_FragColor = texture2D(u_Texture, v_TexCoord);
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

        // Seed tex coords (gets overwritten per frame anyway).
        quadTexCoords.put(floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f)).position(0)
    }

    private fun compile(type: Int, src: String): Int {
        val id = GLES20.glCreateShader(type)
        GLES20.glShaderSource(id, src)
        GLES20.glCompileShader(id)
        return id
    }

    /** Call once per frame AFTER session.update() so the transform is current. */
    fun draw(frame: Frame) {
        if (frame.hasDisplayGeometryChanged()) {
            frame.transformCoordinates2d(
                Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
                quadCoords,
                Coordinates2d.TEXTURE_NORMALIZED,
                quadTexCoords
            )
        }
        if (frame.timestamp == 0L) return  // no image yet

        // Swap the per-frame transformed coords into our drawing buffer.
        quadTexCoords.position(0)
        quadTexCoordsTransformed.position(0)
        quadTexCoordsTransformed.put(quadTexCoords)
        quadTexCoordsTransformed.position(0)
        quadCoords.position(0)

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)

        GLES20.glUseProgram(program)
        GLES20.glUniform1i(textureUniform, 0)

        GLES20.glEnableVertexAttribArray(positionAttrib)
        GLES20.glVertexAttribPointer(positionAttrib, 2, GLES20.GL_FLOAT, false, 0, quadCoords)

        GLES20.glEnableVertexAttribArray(texCoordAttrib)
        GLES20.glVertexAttribPointer(texCoordAttrib, 2, GLES20.GL_FLOAT, false, 0, quadTexCoordsTransformed)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(positionAttrib)
        GLES20.glDisableVertexAttribArray(texCoordAttrib)

        GLES20.glDepthMask(true)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }
}
