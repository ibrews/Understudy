package agilelens.understudy.ui

import agilelens.understudy.model.CameraSpec
import agilelens.understudy.model.horizontalFOV
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.max
import kotlin.math.min

/**
 * Viewfinder overlay for camera marks. When the performer is standing on a
 * camera mark, dim everything except a rectangular "frame" sized to what
 * that lens/sensor would actually capture from here.
 *
 * Port of iOS `ViewfinderOverlay.swift`. Math is deliberately simple:
 *   frameWidthPx = (spec.hfov / phoneHfov) * screenWidth
 *   aspect       = sensorWidth / sensorHeight
 *   frameHeightPx = frameWidthPx / aspect
 *
 * The ballpark phone HFOV (65°) is close enough for previz at v0.23 — we
 * could read it from ARCore's projection matrix later for device-accurate
 * framing, but this matches the iOS overlay one-for-one right now.
 */
@Composable
fun ViewfinderOverlay(
    spec: CameraSpec,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier.fillMaxSize()) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                // Enable destination-out blend for the "punch a hole through
                // the dim layer" effect.
                .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
        ) {
            val hfovRatio = spec.horizontalFOV / PHONE_HORIZONTAL_FOV_RAD
            val screenW = size.width
            val screenH = size.height
            val frameW = max(40f, hfovRatio * screenW)
            val aspect = if (spec.sensorHeightMM > 0f) spec.sensorWidthMM / spec.sensorHeightMM else 1.5f
            // Never let the frame blow past the physical screen — DP still
            // needs to see *something* when framing a 14mm on a phone.
            val rawH = frameW / aspect
            val frameH = min(rawH, screenH * 0.96f)
            val cappedW = if (rawH > frameH) frameH * aspect else frameW
            val cappedFrameW = min(cappedW, screenW * 0.96f)
            val cappedFrameH = min(frameH, screenH * 0.96f)

            val cx = screenW / 2f
            val cy = screenH / 2f
            val frame = Rect(
                offset = Offset(cx - cappedFrameW / 2f, cy - cappedFrameH / 2f),
                size = Size(cappedFrameW, cappedFrameH)
            )

            // 1. Dim everything.
            drawRect(color = Color.Black.copy(alpha = 0.45f))
            // 2. Cut the framing rectangle out using destination-out. DstOut
            //    erases wherever the source alpha is non-zero, so any opaque
            //    color works here — White is a harmless choice.
            drawRect(
                color = Color.White,
                topLeft = frame.topLeft,
                size = frame.size,
                blendMode = BlendMode.DstOut,
            )
            // 3. Framing rectangle outline.
            drawRect(
                color = Color.White.copy(alpha = 0.9f),
                topLeft = frame.topLeft,
                size = frame.size,
                style = Stroke(width = 3f),
            )

            // 4. Corner ticks — bold, longer strokes at the four corners.
            val tick = 26f
            val corners = arrayOf(
                // (corner, along-x, along-y)  — three points: leg, corner, leg
                arrayOf(
                    Offset(frame.left + tick, frame.top),
                    Offset(frame.left, frame.top),
                    Offset(frame.left, frame.top + tick),
                ),
                arrayOf(
                    Offset(frame.right - tick, frame.top),
                    Offset(frame.right, frame.top),
                    Offset(frame.right, frame.top + tick),
                ),
                arrayOf(
                    Offset(frame.left + tick, frame.bottom),
                    Offset(frame.left, frame.bottom),
                    Offset(frame.left, frame.bottom - tick),
                ),
                arrayOf(
                    Offset(frame.right - tick, frame.bottom),
                    Offset(frame.right, frame.bottom),
                    Offset(frame.right, frame.bottom - tick),
                ),
            )
            val cornerPath = Path().apply {
                for (c in corners) {
                    moveTo(c[0].x, c[0].y)
                    lineTo(c[1].x, c[1].y)
                    lineTo(c[2].x, c[2].y)
                }
            }
            drawPath(cornerPath, color = Color.White, style = Stroke(width = 4f))

            // 5. Rule of thirds inside the frame.
            val thirdX1 = frame.left + frame.width / 3f
            val thirdX2 = frame.left + 2f * frame.width / 3f
            val thirdY1 = frame.top + frame.height / 3f
            val thirdY2 = frame.top + 2f * frame.height / 3f
            val thirdsColor = Color.White.copy(alpha = 0.25f)
            drawLine(thirdsColor, Offset(thirdX1, frame.top), Offset(thirdX1, frame.bottom), 1f)
            drawLine(thirdsColor, Offset(thirdX2, frame.top), Offset(thirdX2, frame.bottom), 1f)
            drawLine(thirdsColor, Offset(frame.left, thirdY1), Offset(frame.right, thirdY1), 1f)
            drawLine(thirdsColor, Offset(frame.left, thirdY2), Offset(frame.right, thirdY2), 1f)
        }

        // Lens label chip, centred above the frame.
        LensChip(
            spec = spec,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 12.dp),
        )
    }
}

@Composable
private fun LensChip(
    spec: CameraSpec,
    modifier: Modifier = Modifier,
) {
    val hfovDeg = (spec.horizontalFOV * 180f / Math.PI.toFloat()).toInt()
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(100.dp))
            .background(Color.Black.copy(alpha = 0.75f))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "${spec.focalLengthMM.toInt()}mm",
            color = Color.White,
            fontSize = 12.sp,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.width(6.dp))
        Text(
            text = "·",
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 12.sp,
        )
        Spacer(Modifier.width(6.dp))
        Text(
            text = "${hfovDeg}°",
            color = Color.White.copy(alpha = 0.85f),
            fontSize = 12.sp,
            fontFamily = FontFamily.Monospace,
        )
    }
}

/**
 * Approximate horizontal FOV of a modern phone's rear wide lens, in radians.
 * iPhone 13 Pro+ main ~65°, Pixel 7/8 main ~67°. Ballpark for previz.
 * Could be derived from ARCore's projection matrix later.
 */
private const val PHONE_HORIZONTAL_FOV_RAD = 65f * Math.PI.toFloat() / 180f
