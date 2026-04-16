package agilelens.understudy.glasses

import agilelens.understudy.model.Cue
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.min

/**
 * The pixel-tight renderer that goes on the glasses display. Identical
 * logic as the phone TeleprompterScreen's ScrollingText, but sized for a
 * 480×480 canvas and with two modes (single-line prompt vs flowing script).
 *
 * Inputs come entirely from GlassesTeleprompterState — no store access here
 * so this composable is cheap and can run inside the projected-display
 * Activity without pulling the rest of the app over the IPC boundary.
 */
@Composable
fun GlassesTeleprompterRenderer(
    canvasSize: Int = 480,
    activeColor: Color = Color.Cyan,
    pastColor: Color = Color.White.copy(alpha = 0.35f),
    futureColor: Color = Color.White,
) {
    Surface(
        modifier = Modifier.size(canvasSize.dp),
        color = Color.Black
    ) {
        val mode = GlassesTeleprompterState.renderMode
        val doc = GlassesTeleprompterState.document
        val progress = GlassesTeleprompterState.scrollProgress

        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            when (mode) {
                GlassesTeleprompterState.RenderMode.SINGLE_LINE ->
                    SingleLinePrompt(activeColor = activeColor)

                GlassesTeleprompterState.RenderMode.FLOWING_SCRIPT ->
                    FlowingScript(
                        doc = doc,
                        progress = progress,
                        pastColor = pastColor,
                        activeColor = activeColor,
                        futureColor = futureColor,
                    )
            }
        }
    }
}

/**
 * Big character label + line at screen center. Reads as a teleprompter.
 * When there's no current mark (performer hasn't entered one yet), shows
 * the next expected line as a pre-view in dimmer color.
 */
@Composable
private fun SingleLinePrompt(activeColor: Color) {
    val mark = GlassesTeleprompterState.currentMark
    if (mark == null) {
        Text(
            "Waiting…",
            color = Color.White.copy(alpha = 0.45f),
            fontSize = 28.sp,
            fontFamily = FontFamily.Serif
        )
        return
    }
    // Find the first unspoken line cue — currently defined as the first
    // Line on the mark. (Once Android has a CueFXEngine with firedCueIDs,
    // we'll track per-cue state here too.)
    val line = mark.cues.filterIsInstance<Cue.Line>().firstOrNull()
    if (line == null) {
        Text(
            mark.name,
            color = Color.White.copy(alpha = 0.7f),
            fontSize = 32.sp,
            fontFamily = FontFamily.Serif,
            fontWeight = FontWeight.SemiBold
        )
        return
    }
    Column(
        modifier = Modifier.padding(horizontal = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        if (!line.character.isNullOrEmpty()) {
            Text(
                line.character.uppercase(),
                color = Color.Red.copy(alpha = 0.85f),
                fontSize = 14.sp,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
        }
        Text(
            line.text,
            color = activeColor,
            fontSize = 28.sp,
            fontFamily = FontFamily.Serif,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            lineHeight = 36.sp,
            maxLines = 4
        )
    }
}

/**
 * 3-color karaoke scroll — same rendering as the phone teleprompter, just
 * a tighter viewport. No manual scroll or auto-scroll controls; the phone
 * drives everything via GlassesTeleprompterState.scrollProgress.
 */
@Composable
private fun FlowingScript(
    doc: agilelens.understudy.teleprompter.TeleprompterDocument,
    progress: Double,
    pastColor: Color,
    activeColor: Color,
    futureColor: Color,
) {
    if (doc.text.isEmpty()) {
        Text(
            "Waiting for script…",
            color = Color.White.copy(alpha = 0.45f),
            fontSize = 24.sp,
            fontFamily = FontFamily.Serif
        )
        return
    }
    val totalLen = doc.text.length
    val cursor = (totalLen * progress).toInt().coerceIn(0, totalLen - 1)
    val activeEnd = min(cursor + 30, totalLen)

    val annotated: AnnotatedString = buildAnnotatedString {
        withStyle(SpanStyle(color = pastColor)) { append(doc.text.substring(0, cursor)) }
        withStyle(SpanStyle(color = activeColor)) { append(doc.text.substring(cursor, activeEnd)) }
        withStyle(SpanStyle(color = futureColor)) { append(doc.text.substring(activeEnd)) }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            annotated,
            fontSize = 22.sp,
            fontFamily = FontFamily.Serif,
            fontWeight = FontWeight.SemiBold,
            lineHeight = 30.sp,
            textAlign = TextAlign.Center
        )
    }
}
