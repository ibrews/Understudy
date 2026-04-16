package agilelens.understudy.ui

import agilelens.understudy.AppMode
import agilelens.understudy.ui.theme.CurtainBlack
import agilelens.understudy.ui.theme.CurtainRed
import agilelens.understudy.ui.theme.StageRed
import agilelens.understudy.ui.theme.WhiteDim
import agilelens.understudy.ui.theme.WhiteText
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val CurtainGradient = Brush.verticalGradient(colors = listOf(CurtainRed, CurtainBlack))

/**
 * First-launch mode picker. Mirrors the iOS card layout —
 * Perform, Author, and Audience (self-paced AR audio tour).
 */
@Composable
fun ModePickerScreen(
    onPick: (AppMode) -> Unit
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(CurtainGradient)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                text = "Understudy",
                color = WhiteText,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = "Pick your role for this rehearsal.",
                color = WhiteDim,
                fontSize = 14.sp
            )
            Spacer(Modifier.height(32.dp))

            ModeCard(
                title = "Perform",
                subtitle = "You're on stage. Teleprompter, marks, guidance.",
                icon = Icons.Filled.PlayArrow,
                onClick = { onPick(AppMode.PERFORM) }
            )
            Spacer(Modifier.height(16.dp))
            ModeCard(
                title = "Author",
                subtitle = "Drop marks, edit cues, share the blocking.",
                icon = Icons.Filled.Edit,
                onClick = { onPick(AppMode.AUTHOR) }
            )
            Spacer(Modifier.height(16.dp))
            ModeCard(
                title = "Audience",
                subtitle = "Walk someone else's blocking.",
                icon = Icons.Filled.DirectionsWalk,
                onClick = { onPick(AppMode.AUDIENCE) }
            )
            Spacer(Modifier.height(24.dp))
            Text(
                text = "You can switch modes later in Settings.",
                color = WhiteDim,
                fontSize = 11.sp
            )
        }
    }
}

@Composable
private fun ModeCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    onClick: () -> Unit
) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .clickable { onClick() }
            .padding(horizontal = 20.dp, vertical = 22.dp)
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = StageRed
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    text = title,
                    color = WhiteText,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = subtitle,
                color = WhiteDim,
                fontSize = 13.sp
            )
        }
    }
}
