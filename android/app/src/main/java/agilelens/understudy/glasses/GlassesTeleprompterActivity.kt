package agilelens.understudy.glasses

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView

/**
 * The Activity that runs ON the AI Glasses display. Paired with the phone
 * app by `GlassesLauncher`, which hands it a `ProjectedContext` so it
 * lands on the glasses screen instead of the phone's.
 *
 * This Activity is intentionally minimal — it reads from
 * `GlassesTeleprompterState` (a singleton shared with the phone-side
 * Activity in the same process) and draws. All speech recognition, auto-
 * scroll, settings, and cue-firing happen on the phone; the glasses just
 * render.
 *
 * Following the pattern from Alex's Gemini-Live-ToDo TeleprompterActivity.
 */
class GlassesTeleprompterActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep the screen on while the teleprompter is showing — burning
        // glass battery is the right trade for not losing your line.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = Color.Black
                ) {
                    KeepScreenOn()
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black),
                        contentAlignment = Alignment.Center
                    ) {
                        GlassesTeleprompterRenderer()
                    }
                }
            }
        }
    }
}

@androidx.compose.runtime.Composable
private fun KeepScreenOn() {
    val view = LocalView.current
    DisposableEffect(Unit) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
}
