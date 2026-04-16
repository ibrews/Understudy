package agilelens.understudy.cuefx

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.Box
import kotlinx.coroutines.delay

/**
 * Full-screen color wash that fades when a [CueFXEngine] light cue fires.
 *
 * Mirrors Swift's `FlashOverlay`: reads the engine's current [CueFXEngine.FlashState],
 * snaps opacity to `alpha` for `holdDurationMs`, then animates opacity to 0 over
 * `fadeDurationMs`. Clears the render when the engine publishes `null`.
 *
 * Drop this at the top of any scaffold that should react to lighting cues.
 * Wrap in a Box with `Modifier.fillMaxSize()` — the component is
 * hit-test-transparent so it never intercepts taps.
 */
@Composable
fun FlashOverlay(
    flash: CueFXEngine.FlashState?,
    modifier: Modifier = Modifier,
) {
    // Track the cueID we've currently "rendered" so we only animate on a NEW flash,
    // not on every recomposition that happens to receive the same state.
    var renderedID by remember { mutableStateOf<String?>(null) }
    var targetOpacity by remember { mutableStateOf(0f) }
    val animated by animateFloatAsState(
        targetValue = targetOpacity,
        animationSpec = tween(durationMillis = 750),
        label = "flashOpacity"
    )

    LaunchedEffect(flash?.cueID) {
        if (flash == null) {
            targetOpacity = 0f
            renderedID = null
            return@LaunchedEffect
        }
        if (flash.cueID == renderedID) return@LaunchedEffect
        renderedID = flash.cueID
        // Snap to flash amplitude, hold briefly, then release so animateFloatAsState
        // can fade it back out over tween(750).
        targetOpacity = flash.alpha
        delay(flash.holdDurationMs)
        targetOpacity = 0f
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .alpha(animated)
            .background(flash?.color ?: Color.Transparent)
    )
}
