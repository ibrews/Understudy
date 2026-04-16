package agilelens.understudy.ui

import agilelens.understudy.model.Mark
import agilelens.understudy.model.Pose
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.sin

/**
 * Lightweight top-down radar overlay.
 *
 * This is the fallback / demo-safe version of the "AR mark discs" idea —
 * instead of drawing glowing anchors in a live AR view, we render a radar-style
 * minimap centered on the performer (with their heading as an arrow) and
 * plot all marks around them at true world-space distances.
 *
 * Why this instead of full ARCore rendering: ARCore background rendering needs
 * a GLSurfaceView + texture+shader pipeline that's significantly more code.
 * The radar gives the performer useful spatial info with a fraction of the risk.
 */
@Composable
fun RadarOverlay(
    selfPose: Pose?,
    marks: List<Mark>,
    modifier: Modifier = Modifier,
    rangeMeters: Float = 6f
) {
    Box(modifier = modifier) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val cx = size.width / 2f
            val cy = size.height / 2f
            val radius = (minOf(size.width, size.height) / 2f) - 16f
            val pxPerMeter = radius / rangeMeters

            // Range rings
            val ringColor = Color.White.copy(alpha = 0.08f)
            for (r in 1..(rangeMeters.toInt())) {
                drawCircle(
                    color = ringColor,
                    radius = r * pxPerMeter,
                    center = Offset(cx, cy),
                    style = Stroke(width = 1f)
                )
            }
            // Outer boundary
            drawCircle(
                color = Color.White.copy(alpha = 0.18f),
                radius = radius,
                center = Offset(cx, cy),
                style = Stroke(width = 2f)
            )

            val me = selfPose ?: return@Canvas

            // Draw marks relative to `me`.
            marks.forEach { mark ->
                val dx = mark.pose.x - me.x
                val dz = mark.pose.z - me.z
                // Rotate into performer-local frame: forward = -Z, so we rotate by -yaw.
                val cosY = cos(-me.yaw.toDouble())
                val sinY = sin(-me.yaw.toDouble())
                val localX = (dx * cosY - dz * sinY).toFloat()
                val localZ = (dx * sinY + dz * cosY).toFloat()

                // Screen mapping: +X right, -Z up (forward is up).
                val sx = cx + localX * pxPerMeter
                val sy = cy + localZ * pxPerMeter  // +Z behind, shown below center

                if (kotlin.math.hypot(localX.toDouble(), localZ.toDouble()) > rangeMeters) return@forEach

                // Mark disc (glow ring + fill)
                drawCircle(
                    color = Color(0xFFD2405A).copy(alpha = 0.22f),
                    radius = 22f,
                    center = Offset(sx, sy)
                )
                drawCircle(
                    color = Color(0xFFD2405A),
                    radius = 8f,
                    center = Offset(sx, sy)
                )
            }

            // Self dot + heading indicator (forward is up, i.e. -Z in world)
            drawCircle(
                color = Color.White,
                radius = 10f,
                center = Offset(cx, cy)
            )
            val headingLen = 24f
            val hx = cx
            val hy = cy - headingLen  // "forward" points toward top of screen
            drawLine(
                color = Color.White,
                start = Offset(cx, cy),
                end = Offset(hx, hy),
                strokeWidth = 3f
            )
        }
    }
}
