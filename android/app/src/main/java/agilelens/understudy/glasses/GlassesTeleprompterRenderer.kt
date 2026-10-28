package agilelens.understudy.glasses

import agilelens.understudy.teleprompter.KaraokeText
import agilelens.understudy.teleprompter.PromptPlayback
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The pixel-tight renderer that goes on the glasses display. Identical
 * cursor logic as the phone TeleprompterScreen. Fits the available projected
 * viewport up to 480 dp, with paged single-line and measured flowing modes.
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
        modifier = Modifier.sizeIn(maxWidth = canvasSize.dp, maxHeight = canvasSize.dp).fillMaxSize(),
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
 * Uses the shared document cursor, so reading also works before entering a mark.
 */
@Composable
private fun SingleLinePrompt(activeColor: Color) {
    val doc = GlassesTeleprompterState.document
    BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val fontScale = LocalDensity.current.fontScale
        val pageSize = (((maxWidth.value - 40) / (28 * fontScale * 0.7f)).toInt() * 3)
            .coerceIn(16, 100)
        val prompt = PromptPlayback.prompt(doc, GlassesTeleprompterState.scrollProgress, pageSize)
        if (prompt == null) {
            Text(
                if (doc.spokenLines.isEmpty()) "Open a script on your phone" else "End of script",
                color = Color.White,
                fontSize = 24.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(20.dp),
            )
        } else {
            Column(Modifier.padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                if (!prompt.character.isNullOrEmpty()) {
                    Text(prompt.character.uppercase(), color = Color.White,
                        fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                }
                Text(prompt.text, color = activeColor, fontSize = 28.sp,
                    fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center, lineHeight = 36.sp)
                if (prompt.pages > 1) {
                    Spacer(Modifier.height(8.dp))
                    Text("${prompt.page} / ${prompt.pages}", color = Color.White, fontSize = 14.sp)
                }
            }
        }
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
    KaraokeText(doc.text, progress, 22, activeColor, pastColor, futureColor)
}
