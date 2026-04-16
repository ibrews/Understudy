package agilelens.understudy.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColors = darkColorScheme(
    primary = StageRed,
    onPrimary = Color.White,
    secondary = StageAmber,
    onSecondary = Color.Black,
    background = CurtainBlack,
    onBackground = WhiteText,
    surface = CurtainBlack,
    onSurface = WhiteText
)

@Composable
fun UnderstudyTheme(
    @Suppress("UNUSED_PARAMETER") darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColors,
        typography = Typography(),
        content = content
    )
}
