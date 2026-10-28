package agilelens.understudy.teleprompter

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Track the actual wrapped line, rather than estimating height from character count. */
@Composable
fun KaraokeText(
    text: String,
    progress: Double,
    textSize: Int,
    activeColor: Color = Color.Cyan,
    pastColor: Color = Color.White.copy(alpha = 0.35f),
    futureColor: Color = Color.White,
) {
    val window = PromptPlayback.window(text, progress)
    val annotated = remember(text, window, activeColor, pastColor, futureColor) {
        buildAnnotatedString {
            withStyle(SpanStyle(color = pastColor)) { append(text.substring(0, window.start)) }
            withStyle(SpanStyle(color = activeColor)) { append(text.substring(window.start, window.end)) }
            withStyle(SpanStyle(color = futureColor)) { append(text.substring(window.end)) }
        }
    }
    var layout by remember(text, textSize) { mutableStateOf<TextLayoutResult?>(null) }
    val scroll = rememberScrollState()
    BoxWithConstraints(Modifier.fillMaxSize()) {
        // Half a viewport on either side lets the first and last line reach center.
        val inset = maxHeight / 2
        Column(
            Modifier.fillMaxSize().verticalScroll(scroll).padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(inset))
            Text(
                annotated,
                fontSize = textSize.sp,
                lineHeight = (textSize * 1.4).sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.SansSerif,
                textAlign = TextAlign.Center,
                onTextLayout = { layout = it },
            )
            Spacer(Modifier.height(inset))
        }
        LaunchedEffect(text, window.start, layout, scroll.maxValue) {
            val measured = layout ?: return@LaunchedEffect
            if (text.isEmpty()) return@LaunchedEffect
            val line = measured.getLineForOffset(window.start.coerceAtMost(text.lastIndex))
            val center = (measured.getLineTop(line) + measured.getLineBottom(line)) / 2f
            scroll.scrollTo(center.toInt().coerceIn(0, scroll.maxValue))
        }
    }
}
