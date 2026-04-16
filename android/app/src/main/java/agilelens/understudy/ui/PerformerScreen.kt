package agilelens.understudy.ui

import agilelens.understudy.BuildConfig
import agilelens.understudy.ar.ArPoseProvider
import agilelens.understudy.model.Blocking
import agilelens.understudy.model.Cue
import agilelens.understudy.model.Mark
import agilelens.understudy.model.Performer
import agilelens.understudy.ui.theme.CurtainBlack
import agilelens.understudy.ui.theme.CurtainRed
import agilelens.understudy.ui.theme.StageRed
import agilelens.understudy.ui.theme.WhiteDim
import agilelens.understudy.ui.theme.WhiteFaint
import agilelens.understudy.ui.theme.WhiteText
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.GpsNotFixed
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.max
import kotlin.math.min

private val CurtainGradient = Brush.verticalGradient(
    colors = listOf(CurtainRed, CurtainBlack)   // red at top, black at bottom — matches iOS
)

@Composable
fun PerformerScreen(
    blocking: Blocking,
    local: Performer,
    peerCount: Int,
    roomCode: String,
    onOpenSettings: () -> Unit,
    isRecording: Boolean = false,
    onToggleRecording: () -> Unit = {},
    arProvider: ArPoseProvider? = null,
    showArStage: Boolean = false
) {
    val currentMark: Mark? = local.currentMarkID?.let { id ->
        blocking.marks.firstOrNull { it.id == id }
    }
    val nextMark: Mark? = nextMarkAfter(blocking, local.currentMarkID)

    Box(
        Modifier
            .fillMaxSize()
            .background(CurtainGradient)
    ) {
        // AR stage lives BEHIND the teleprompter UI.
        if (showArStage && arProvider != null) {
            ArStageView(
                arProvider = arProvider,
                marks = blocking.marks,
                nextMarkId = nextMark?.id,
                modifier = Modifier.fillMaxSize()
            )
        }

        Column(
            Modifier
                .fillMaxSize()
                .padding(16.dp)
        ) {
            TopBar(
                title = blocking.title,
                roomCode = roomCode,
                peerCount = peerCount,
                onOpenSettings = onOpenSettings
            )
            Spacer(Modifier.height(12.dp))
            CurrentCueCard(mark = currentMark, nextMark = nextMark)
            Spacer(Modifier.height(12.dp))

            if (!showArStage) {
                // Guidance ring over radar (fallback view)
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(300.dp),
                    contentAlignment = Alignment.Center
                ) {
                    RadarOverlay(
                        selfPose = local.pose,
                        marks = blocking.marks,
                        modifier = Modifier.size(280.dp)
                    )
                    GuidanceRing(local = local, next = nextMark ?: currentMark)
                }
            } else {
                // Minimal guidance ring overlay when AR stage is showing.
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(260.dp),
                    contentAlignment = Alignment.Center
                ) {
                    GuidanceRing(local = local, next = nextMark ?: currentMark)
                }
            }

            Spacer(Modifier.weight(1f))

            BottomBar(
                quality = local.trackingQuality,
                isRecording = isRecording,
                onToggleRecording = onToggleRecording
            )
        }
    }
}

@Composable
private fun TopBar(
    title: String,
    roomCode: String,
    peerCount: Int,
    onOpenSettings: () -> Unit
) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                text = title,
                color = WhiteText,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = "Room: $roomCode  •  $peerCount peers  •  v${BuildConfig.APP_VERSION} (${BuildConfig.APP_BUILD})",
                color = WhiteDim,
                fontSize = 11.sp
            )
        }
        IconButton(onClick = onOpenSettings) {
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.Settings,
                    contentDescription = "Settings",
                    tint = WhiteText
                )
            }
        }
    }
}

@Composable
private fun CurrentCueCard(mark: Mark?, nextMark: Mark?) {
    Box(
        Modifier
            .fillMaxWidth()
            .wrapContentHeight()
            .clip(RoundedCornerShape(24.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .padding(20.dp)
    ) {
        if (mark != null) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = "On ${mark.name}",
                    color = WhiteDim,
                    fontSize = 12.sp
                )
                if (mark.cues.isEmpty()) {
                    Text(
                        text = "No cues — hold.",
                        color = WhiteDim,
                        fontSize = 18.sp
                    )
                } else {
                    mark.cues.forEach { cue -> CueRow(cue) }
                }
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "Find your mark",
                    color = WhiteText,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = nextMark?.let { "Next: ${it.name}" } ?: "No blocking loaded",
                    color = WhiteDim,
                    fontSize = 14.sp
                )
            }
        }
    }
}

@Composable
private fun CueRow(cue: Cue) {
    when (cue) {
        is Cue.Line -> Column {
            if (!cue.character.isNullOrEmpty()) {
                Text(
                    text = cue.character.uppercase(),
                    color = StageRed.copy(alpha = 0.85f),
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace
                )
            }
            Text(
                text = cue.text,
                color = WhiteText,
                fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Serif
            )
        }
        is Cue.Sfx -> Text(
            text = "♪ ${cue.name}",
            color = Color(0xFFFFEB8A),
            fontSize = 16.sp
        )
        is Cue.Light -> Text(
            text = "◐ Light: ${cue.color.name}",
            color = Color(0xFFFFB56B),
            fontSize = 16.sp
        )
        is Cue.Note -> Text(
            text = "(${cue.text})",
            color = WhiteDim,
            fontSize = 14.sp,
            fontStyle = FontStyle.Italic
        )
        is Cue.Wait -> Text(
            text = "• hold ${"%.1f".format(cue.seconds)}s",
            color = WhiteDim,
            fontSize = 14.sp
        )
    }
}

@Composable
private fun GuidanceRing(local: Performer, next: Mark?) {
    val distance: Float? = next?.let { local.pose.distance(it.pose) }
    val proximity = proximityNormalized(distance)
    val animProx by animateFloatAsState(
        targetValue = proximity,
        animationSpec = tween(durationMillis = 300),
        label = "proximity"
    )
    Box(
        Modifier.size(260.dp),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val cx = size.width / 2f
            val cy = size.height / 2f
            val outer = (minOf(size.width, size.height) / 2f) - 10f
            drawCircle(
                color = WhiteFaint,
                radius = outer,
                center = Offset(cx, cy),
                style = Stroke(width = 2f)
            )
            val inner = outer * (1f - animProx) + 20f
            drawCircle(
                color = StageRed.copy(alpha = 0.65f),
                radius = inner,
                center = Offset(cx, cy),
                style = Stroke(width = 3f)
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            if (distance != null) {
                Text(
                    text = "%.1f m".format(distance),
                    color = WhiteText,
                    fontSize = 40.sp,
                    fontWeight = FontWeight.Light
                )
                Text(
                    text = "to ${next?.name ?: "—"}",
                    color = WhiteDim,
                    fontSize = 12.sp
                )
            } else {
                Text(
                    text = "—",
                    color = WhiteDim,
                    fontSize = 40.sp,
                    fontWeight = FontWeight.Light
                )
            }
        }
    }
}

@Composable
private fun BottomBar(
    quality: Float,
    isRecording: Boolean,
    onToggleRecording: () -> Unit
) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val good = quality > 0.6f
        Icon(
            imageVector = if (good) Icons.Filled.GpsFixed else Icons.Filled.GpsNotFixed,
            contentDescription = null,
            tint = if (good) Color(0xFF6ED787) else Color(0xFFE2A84B)
        )
        Spacer(Modifier.width(6.dp))
        Text(
            text = trackingLabel(quality),
            color = if (good) Color(0xFF6ED787) else Color(0xFFE2A84B),
            fontSize = 12.sp
        )
        Spacer(Modifier.weight(1f))
        IconButton(onClick = onToggleRecording) {
            Icon(
                imageVector = if (isRecording) Icons.Filled.Stop else Icons.Filled.FiberManualRecord,
                contentDescription = "Record",
                tint = if (isRecording) StageRed else WhiteText
            )
        }
    }
}

// --- helpers ---

private fun nextMarkAfter(b: Blocking, currentID: agilelens.understudy.model.Id?): Mark? {
    if (b.marks.isEmpty()) return null
    val sorted = b.marks.sortedBy { it.sequenceIndex }
    val current = currentID?.let { id -> sorted.firstOrNull { it.id == id } }
    return if (current != null) {
        sorted.firstOrNull { it.sequenceIndex > current.sequenceIndex } ?: sorted.first()
    } else sorted.first()
}

private fun proximityNormalized(d: Float?): Float {
    if (d == null) return 0f
    return max(0f, min(1f, 1f - (d / 3f)))
}

private fun trackingLabel(q: Float): String = when {
    q > 0.8f -> "Tracking good"
    q > 0.4f -> "Tracking limited"
    else -> "No tracking — move around"
}
