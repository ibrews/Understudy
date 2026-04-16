package agilelens.understudy.ui

import agilelens.understudy.ar.ArPoseProvider
import agilelens.understudy.ar.BackgroundRenderer
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark
import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.viewinterop.AndroidView
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.abs

/**
 * AR stage background — live ARCore camera feed with floor-anchored glowing discs
 * for each Mark. If ARCore isn't rendering (e.g., session not ready), the camera
 * layer is black and only the discs show, which is still useful.
 *
 * When [onFloorTap] is non-null, taps on the stage area raycast against the
 * y=0 floor plane using the latest view/projection matrices from [arProvider]
 * and report the resulting (worldX, worldZ). Useful for Author mode to place
 * marks by tapping on the live AR view (v0.22).
 *
 * Usage: wrap the teleprompter content in a Box, put this at the bottom:
 *   Box {
 *       ArStageView(...)
 *       YourUI()
 *   }
 */
@Composable
fun ArStageView(
    arProvider: ArPoseProvider,
    marks: List<Mark>,
    nextMarkId: Id?,
    modifier: Modifier = Modifier,
    onFloorTap: ((worldX: Float, worldZ: Float) -> Unit)? = null,
) {
    // Force recomposition at ~30Hz for the overlay.
    var tick by remember { mutableStateOf(0L) }
    LaunchedEffect(Unit) {
        while (true) {
            withFrameNanos { tick = it }
        }
    }

    // Capture the latest tap callback so the pointerInput closure stays in sync
    // without re-installing itself.
    val tapCallback by rememberUpdatedState(onFloorTap)

    Box(modifier = modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx -> ArGlView(ctx, arProvider) },
            update = { view -> view.requestRender() }
        )

        // Read latest matrices — tick dependency forces redraw each frame.
        @Suppress("UNUSED_EXPRESSION") tick
        val viewMatrix = arProvider.lastViewMatrix
        val projMatrix = arProvider.lastProjectionMatrix

        // Tap-to-place layer. Sits on top of the GL view but BELOW the app UI
        // (which lives in a separate sibling Box). Any taps that reach here
        // have already been ignored by the app chrome.
        if (tapCallback != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(Unit) {
                        detectTapGestures { offset ->
                            val w = size.width.toFloat()
                            val h = size.height.toFloat()
                            val hit = rayHitFloor(
                                screenX = offset.x,
                                screenY = offset.y,
                                screenW = w,
                                screenH = h,
                                view = arProvider.lastViewMatrix,
                                proj = arProvider.lastProjectionMatrix,
                            )
                            if (hit != null) {
                                tapCallback?.invoke(hit.first, hit.second)
                            }
                        }
                    }
            )
        }

        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val vp = FloatArray(16)
            Matrix.multiplyMM(vp, 0, projMatrix, 0, viewMatrix, 0)

            marks.forEach { mark ->
                val worldPt = floatArrayOf(mark.pose.x, 0f, mark.pose.z, 1f)
                val clip = FloatArray(4)
                Matrix.multiplyMV(clip, 0, vp, 0, worldPt, 0)
                if (clip[3] <= 0.0001f) return@forEach  // behind camera
                val ndcX = clip[0] / clip[3]
                val ndcY = clip[1] / clip[3]
                val sx = (ndcX * 0.5f + 0.5f) * w
                val sy = (1f - (ndcY * 0.5f + 0.5f)) * h
                if (sx.isNaN() || sy.isNaN()) return@forEach

                // Scale disc by distance — closer = bigger. Use clip.w as proxy.
                val dist = clip[3]
                val pxRadius = (mark.radius * 250f / dist).coerceIn(8f, 160f)

                val isNext = (mark.id == nextMarkId)
                val base = if (isNext) Color(0xFFFFE06B) else Color(0xFFD2405A)
                drawCircle(
                    color = base.copy(alpha = 0.22f),
                    radius = pxRadius,
                    center = Offset(sx, sy)
                )
                drawCircle(
                    color = base.copy(alpha = 0.55f),
                    radius = pxRadius * 0.7f,
                    center = Offset(sx, sy),
                    style = Stroke(width = 3f)
                )
                drawCircle(
                    color = base,
                    radius = (pxRadius * 0.15f).coerceAtLeast(3f),
                    center = Offset(sx, sy)
                )
            }
        }
    }
}

/**
 * Unproject a screen-space tap through the view+projection matrices and
 * intersect the resulting ray with the world y=0 plane (the stage floor).
 *
 * Returns (worldX, worldZ) of the intersection, or null if the ray doesn't
 * hit the floor (parallel / behind-camera / invalid matrices).
 *
 * This is a pure-math helper that lives alongside ArStageView because the
 * ray math is tied to the overlay's view/projection convention.
 */
internal fun rayHitFloor(
    screenX: Float,
    screenY: Float,
    screenW: Float,
    screenH: Float,
    view: FloatArray,
    proj: FloatArray,
): Pair<Float, Float>? {
    if (screenW <= 0f || screenH <= 0f) return null

    val vp = FloatArray(16)
    Matrix.multiplyMM(vp, 0, proj, 0, view, 0)
    val inv = FloatArray(16)
    if (!Matrix.invertM(inv, 0, vp, 0)) return null

    // Tap in normalized device coordinates. Screen Y goes down, NDC Y goes up.
    val ndcX = (screenX / screenW) * 2f - 1f
    val ndcY = 1f - (screenY / screenH) * 2f

    val nearNdc = floatArrayOf(ndcX, ndcY, -1f, 1f)
    val farNdc = floatArrayOf(ndcX, ndcY, 1f, 1f)
    val nearW = FloatArray(4)
    val farW = FloatArray(4)
    Matrix.multiplyMV(nearW, 0, inv, 0, nearNdc, 0)
    Matrix.multiplyMV(farW, 0, inv, 0, farNdc, 0)

    if (abs(nearW[3]) < 1e-6f || abs(farW[3]) < 1e-6f) return null

    val nx = nearW[0] / nearW[3]
    val ny = nearW[1] / nearW[3]
    val nz = nearW[2] / nearW[3]
    val fx = farW[0] / farW[3]
    val fy = farW[1] / farW[3]
    val fz = farW[2] / farW[3]

    val dx = fx - nx
    val dy = fy - ny
    val dz = fz - nz

    if (abs(dy) < 1e-4f) return null  // ray parallel to floor

    val t = -ny / dy
    if (t < 0f) return null  // floor is behind camera

    val hitX = nx + t * dx
    val hitZ = nz + t * dz

    // Reject absurdly far hits (camera pointed nearly at horizon, t huge).
    if (abs(hitX) > 50f || abs(hitZ) > 50f) return null

    return hitX to hitZ
}

/**
 * GLSurfaceView subclass that drives the ARCore camera feed through a
 * BackgroundRenderer. The host Activity owns the Session (via ArPoseProvider);
 * we only set the texture ID and call frame.update()'s results.
 */
private class ArGlView(context: Context, private val arProvider: ArPoseProvider) : GLSurfaceView(context) {
    private val bg = BackgroundRenderer()
    private var textureBound = false

    init {
        setEGLContextClientVersion(2)
        preserveEGLContextOnPause = true
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        holder.setFormat(android.graphics.PixelFormat.TRANSLUCENT)
        setRenderer(InnerRenderer())
        renderMode = RENDERMODE_CONTINUOUSLY
    }

    private inner class InnerRenderer : Renderer {
        override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            bg.createOnGlThread()
            textureBound = false
        }

        override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
            GLES20.glViewport(0, 0, width, height)
            val s = arProvider.session()
            try {
                s?.setDisplayGeometry(android.view.Surface.ROTATION_0, width, height)
            } catch (_: Throwable) {}
        }

        override fun onDrawFrame(gl: GL10?) {
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
            val session = arProvider.session() ?: return
            try {
                if (!textureBound) {
                    session.setCameraTextureName(bg.textureId)
                    textureBound = true
                }
                val frame = session.update() ?: return
                bg.draw(frame)
            } catch (_: Throwable) {
                // Session may be paused or racing; just skip this frame.
            }
        }
    }
}
