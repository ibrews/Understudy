package agilelens.understudy.ui

import agilelens.understudy.model.Cue
import agilelens.understudy.model.Mark
import agilelens.understudy.ui.theme.StageRed
import agilelens.understudy.ui.theme.WhiteDim
import agilelens.understudy.ui.theme.WhiteText
import android.opengl.Matrix
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * ScriptPanelOverlay — billboarded "manuscript page" that floats above a mark in
 * world space. The Android equivalent of iOS `MarkScriptCard` / visionOS
 * RealityView attachments, but projected by hand: we multiply the mark's world
 * position by the cached view+projection matrices from [ArStageView]'s provider
 * and render a Compose card at the resulting screen point.
 *
 * Only one card is shown at a time — the [nextMark] the performer is walking
 * toward. Multiple floating cards in view at once clutters the AR scene and
 * defeats the "read ahead without looking down" goal.
 *
 * Card contents = the mark's next [Cue.Line] (character in uppercase red mono,
 * line in white serif) to match the teleprompter's type treatment.
 *
 * Scaling: inverse-distance, with the same clip.w proxy the mark discs use.
 * Anchor point: `pose.y + 1.6f` (roughly head-height above the floor mark).
 * Off-screen / behind-camera marks are skipped silently.
 */
@Composable
fun ScriptPanelOverlay(
    nextMark: Mark?,
    viewMatrix: FloatArray,
    projMatrix: FloatArray,
    modifier: Modifier = Modifier,
) {
    if (nextMark == null) return
    val nextLine = nextMark.cues.firstOrNull { it is Cue.Line } as? Cue.Line ?: return

    val density = LocalDensity.current

    Layout(
        modifier = modifier.fillMaxSize(),
        content = {
            ScriptCard(line = nextLine, markName = nextMark.name)
        }
    ) { measurables, constraints ->
        val screenW = constraints.maxWidth.toFloat()
        val screenH = constraints.maxHeight.toFloat()

        // Project mark's anchor point (head-height above the disc) to screen.
        val world = floatArrayOf(
            nextMark.pose.x,
            nextMark.pose.y + 1.6f,
            nextMark.pose.z,
            1f,
        )
        val vp = FloatArray(16)
        Matrix.multiplyMM(vp, 0, projMatrix, 0, viewMatrix, 0)
        val clip = FloatArray(4)
        Matrix.multiplyMV(clip, 0, vp, 0, world, 0)

        // Behind-camera, degenerate, or invalid — lay out nothing.
        if (clip[3] <= 0.0001f) {
            return@Layout layout(constraints.maxWidth, constraints.maxHeight) {}
        }
        val ndcX = clip[0] / clip[3]
        val ndcY = clip[1] / clip[3]
        if (ndcX.isNaN() || ndcY.isNaN()) {
            return@Layout layout(constraints.maxWidth, constraints.maxHeight) {}
        }

        val sx = (ndcX * 0.5f + 0.5f) * screenW
        val sy = (1f - (ndcY * 0.5f + 0.5f)) * screenH

        // Inverse-distance scale: matches the mark disc feel. Clamp so cards
        // don't get microscopic at the horizon or bigger than the screen when
        // the performer is right on top of the mark.
        val dist = clip[3]
        val scale = (1.4f / dist).coerceIn(0.35f, 1.6f)

        // Measure the card with looser width constraints — min 180dp, max 280dp
        // after scaling. Height is free.
        val minWpx = with(density) { 180.dp.toPx() }.toInt()
        val maxWpx = with(density) { 280.dp.toPx() }.toInt()
        val cardConstraints = Constraints(
            minWidth = minWpx.coerceAtMost(constraints.maxWidth),
            maxWidth = maxWpx.coerceAtMost(constraints.maxWidth),
            minHeight = 0,
            maxHeight = constraints.maxHeight,
        )
        val placeable = measurables.first().measure(cardConstraints)

        layout(constraints.maxWidth, constraints.maxHeight) {
            val halfW = placeable.width / 2
            val halfH = placeable.height / 2
            // Skip cards whose anchor is outside the screen bounds (with a
            // small margin so edge-of-view cards don't pop).
            val margin = 40f
            val onScreen = sx >= -margin && sx <= screenW + margin &&
                sy >= -margin && sy <= screenH + margin
            if (!onScreen) return@layout

            // Anchor above the mark disc, shifted up by half the card height
            // so the card sits ABOVE the head-height point, not centered on it.
            val placeX = (sx - halfW).toInt()
            val placeY = (sy - placeable.height - 8).toInt()

            placeable.placeRelativeWithLayer(
                x = placeX,
                y = placeY,
            ) {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin(0.5f, 1f)
            }
        }
    }
}

/**
 * The card itself — a rounded-rect "manuscript page" with the mark name,
 * character line, and cue text. Styled to match the teleprompter: serif white
 * body, monospace red character label.
 */
@Composable
private fun ScriptCard(line: Cue.Line, markName: String) {
    Box(
        modifier = Modifier
            .widthIn(min = 180.dp, max = 280.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color.Black.copy(alpha = 0.72f))
            .border(
                width = 1.dp,
                color = StageRed.copy(alpha = 0.55f),
                shape = RoundedCornerShape(14.dp),
            )
            .padding(horizontal = 14.dp, vertical = 12.dp)
    ) {
        Column {
            Text(
                text = markName,
                color = WhiteDim,
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace,
            )
            if (!line.character.isNullOrEmpty()) {
                Text(
                    text = line.character.uppercase(),
                    color = StageRed.copy(alpha = 0.9f),
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            Text(
                text = line.text,
                color = WhiteText,
                fontSize = 15.sp,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}
