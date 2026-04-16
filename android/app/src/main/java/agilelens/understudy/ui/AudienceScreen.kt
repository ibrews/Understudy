package agilelens.understudy.ui

import agilelens.understudy.BuildConfig
import agilelens.understudy.ar.ArPoseProvider
import agilelens.understudy.model.Blocking
import agilelens.understudy.model.Cue
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark
import agilelens.understudy.model.Performer
import agilelens.understudy.ui.theme.CurtainBlack
import agilelens.understudy.ui.theme.CurtainRed
import agilelens.understudy.ui.theme.StageAmber
import agilelens.understudy.ui.theme.StageRed
import agilelens.understudy.ui.theme.WhiteDim
import agilelens.understudy.ui.theme.WhiteFaint
import agilelens.understudy.ui.theme.WhiteText
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.GpsNotFixed
import androidx.compose.material.icons.filled.Hearing
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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

private val AudienceGradient = Brush.verticalGradient(
    colors = listOf(CurtainRed, CurtainBlack)  // same theme as Perform / Author
)

/**
 * Audience mode — the phone becomes a self-paced AR audio guide.
 *
 * The audience walks between marks in sequence. When they enter the next
 * mark's radius, [BlockingStore.updateLocalFromArSample] flips the local
 * performer's `currentMarkID` to that mark and the UI auto-advances to show
 * its cues. No wall-clock timing; proximity alone drives the show.
 *
 * Over the wire this device is a normal performer — its pose is shared so
 * a director view can see audience positions in real time, but it never
 * authors or mutates marks.
 */
@Composable
fun AudienceScreen(
    blocking: Blocking,
    local: Performer,
    peerCount: Int,
    roomCode: String,
    onOpenSettings: () -> Unit,
    arProvider: ArPoseProvider? = null,
    showArStage: Boolean = true,
) {
    val ordered: List<Mark> = remember(blocking.marks) {
        blocking.marks.filter { it.sequenceIndex >= 0 }.sortedBy { it.sequenceIndex }
    }
    val currentMark: Mark? = local.currentMarkID?.let { id ->
        blocking.marks.firstOrNull { it.id == id }
    }
    val nextMark: Mark? = nextAudienceMark(ordered, local.currentMarkID)
    val currentIdx = ordered.indexOfFirst { it.id == local.currentMarkID }

    var started by remember { mutableStateOf(false) }
    // Track most-recently-fired mark so we could wire haptics / log transitions
    // without re-firing on unrelated recompositions.
    var lastFiredMarkID by remember { mutableStateOf<Id?>(null) }
    LaunchedEffect(local.currentMarkID) {
        if (started && local.currentMarkID != null && local.currentMarkID != lastFiredMarkID) {
            lastFiredMarkID = local.currentMarkID
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(AudienceGradient)
    ) {
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

            if (!started) {
                BeginCard(
                    firstMarkName = ordered.firstOrNull()?.name,
                    enabled = ordered.isNotEmpty(),
                    onBegin = { started = true }
                )
                Spacer(Modifier.weight(1f))
            } else {
                CurrentCard(
                    mark = currentMark,
                    nextMark = nextMark,
                    distanceToNext = nextMark?.let { local.pose.distance(it.pose) }
                )
                Spacer(Modifier.height(12.dp))
                NextLinePreview(nextMark = nextMark)
                Spacer(Modifier.weight(1f))
            }

            ProgressBlock(
                currentIdx = currentIdx,
                total = ordered.size
            )
            Spacer(Modifier.height(8.dp))
            BottomBar(
                quality = local.trackingQuality,
                started = started,
                onStop = {
                    started = false
                    lastFiredMarkID = null
                }
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
        Box(
            Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.08f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Hearing,
                contentDescription = null,
                tint = WhiteText
            )
        }
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = title,
                    color = WhiteText,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.width(8.dp))
                Box(
                    Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(StageRed.copy(alpha = 0.85f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = "AUDIENCE",
                        color = WhiteText,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
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
private fun BeginCard(
    firstMarkName: String?,
    enabled: Boolean,
    onBegin: () -> Unit
) {
    Box(
        Modifier
            .fillMaxWidth()
            .wrapContentHeight()
            .clip(RoundedCornerShape(22.dp))
            .background(Color.Black.copy(alpha = 0.55f))
            .padding(24.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                imageVector = Icons.Filled.DirectionsWalk,
                contentDescription = null,
                tint = WhiteText.copy(alpha = 0.9f),
                modifier = Modifier.size(64.dp)
            )
            Spacer(Modifier.height(14.dp))
            Text(
                text = if (enabled)
                    "Find ${firstMarkName ?: "the first mark"}.\nWhen you're ready, begin."
                else
                    "No blocking loaded.\nConnect to a director or import a .understudy file.",
                color = WhiteDim,
                fontSize = 14.sp
            )
            Spacer(Modifier.height(18.dp))
            Box(
                Modifier
                    .clip(RoundedCornerShape(28.dp))
                    .background(
                        if (enabled) StageRed.copy(alpha = 0.9f)
                        else Color.White.copy(alpha = 0.08f)
                    )
                    .let { m -> if (enabled) m.clickable(onClick = onBegin) else m }
                    .padding(horizontal = 28.dp, vertical = 14.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Filled.PlayArrow,
                        contentDescription = null,
                        tint = WhiteText
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = "Begin",
                        color = WhiteText,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

@Composable
private fun CurrentCard(
    mark: Mark?,
    nextMark: Mark?,
    distanceToNext: Float?
) {
    Box(
        Modifier
            .fillMaxWidth()
            .wrapContentHeight()
            .clip(RoundedCornerShape(20.dp))
            .background(Color.Black.copy(alpha = 0.55f))
            .padding(22.dp)
    ) {
        when {
            mark != null -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = "${mark.sequenceIndex + 1}. ${mark.name}",
                    color = WhiteDim,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace
                )
                if (mark.cues.isEmpty()) {
                    Text(
                        text = "Take in the space.",
                        color = WhiteDim,
                        fontSize = 20.sp,
                        fontStyle = FontStyle.Italic
                    )
                } else {
                    mark.cues.forEach { cue -> AudienceCueRow(cue) }
                }
            }
            nextMark != null -> Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "Walk to ${nextMark.name}",
                    color = WhiteText,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = distanceToNext?.let { "%.1f m away".format(it) } ?: "—",
                    color = WhiteDim,
                    fontSize = 14.sp,
                    fontFamily = FontFamily.Monospace
                )
            }
            else -> Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "End of journey.",
                    color = WhiteText,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "Thank you for walking this blocking.",
                    color = WhiteDim,
                    fontSize = 14.sp
                )
            }
        }
    }
}

@Composable
private fun AudienceCueRow(cue: Cue) {
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
            color = StageAmber,
            fontSize = 18.sp
        )
        is Cue.Light -> Text(
            text = "A ${cue.color.name} light washes the space.",
            color = StageAmber.copy(alpha = 0.85f),
            fontSize = 16.sp,
            fontStyle = FontStyle.Italic
        )
        // Director notes are hidden from audiences — same as iOS.
        is Cue.Note -> {}
        is Cue.Wait -> Text(
            text = "— pause, ${"%.0f".format(cue.seconds)}s —",
            color = WhiteDim,
            fontSize = 12.sp,
            fontStyle = FontStyle.Italic
        )
    }
}

@Composable
private fun NextLinePreview(nextMark: Mark?) {
    val preview = nextMark?.cues?.firstOrNull { it is Cue.Line } as? Cue.Line ?: return
    Box(
        Modifier
            .fillMaxWidth()
            .wrapContentHeight()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .padding(14.dp)
    ) {
        Column {
            Text(
                text = "NEXT — ${nextMark.name}".uppercase(),
                color = WhiteDim,
                fontSize = 10.sp,
                fontFamily = FontFamily.Monospace
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = preview.text,
                color = WhiteDim,
                fontSize = 14.sp,
                fontStyle = FontStyle.Italic,
                maxLines = 2
            )
        }
    }
}

@Composable
private fun ProgressBlock(currentIdx: Int, total: Int) {
    val fraction: Float = if (total <= 0) 0f
    else ((currentIdx + 1).coerceAtLeast(0).toFloat() / total.toFloat()).coerceIn(0f, 1f)
    val animFrac by animateFloatAsState(
        targetValue = fraction,
        animationSpec = tween(durationMillis = 300),
        label = "audienceProgress"
    )
    Column {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
        ) {
            val h = size.height
            // Track
            drawRoundRect(
                color = WhiteFaint,
                size = size,
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(h / 2f, h / 2f)
            )
            // Fill
            val fillWidth = max(h, size.width * animFrac)
            drawRoundRect(
                color = StageRed.copy(alpha = 0.85f),
                size = androidx.compose.ui.geometry.Size(fillWidth, h),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(h / 2f, h / 2f)
            )
        }
        Spacer(Modifier.height(4.dp))
        Text(
            text = if (total <= 0) "No marks"
            else "Mark ${max(0, currentIdx + 1)} of $total",
            color = WhiteDim,
            fontSize = 11.sp,
            fontFamily = FontFamily.Monospace
        )
    }
}

@Composable
private fun BottomBar(
    quality: Float,
    started: Boolean,
    onStop: () -> Unit
) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val good = quality > 0.6f
        Icon(
            imageVector = if (good) Icons.Filled.GpsFixed else Icons.Filled.GpsNotFixed,
            contentDescription = null,
            tint = if (good) Color(0xFF6ED787) else StageAmber
        )
        Spacer(Modifier.width(6.dp))
        Text(
            text = if (good) "Tracking good" else "Walk slowly",
            color = if (good) Color(0xFF6ED787) else StageAmber,
            fontSize = 12.sp
        )
        Spacer(Modifier.weight(1f))
        if (started) {
            IconButton(onClick = onStop) {
                Icon(
                    imageVector = Icons.Filled.Stop,
                    contentDescription = "Stop",
                    tint = WhiteText.copy(alpha = 0.8f)
                )
            }
        }
    }
}

// --- helpers ---

/**
 * Next mark in audience sequence. If we're not on any mark yet, return the
 * first one by sequenceIndex. If we're on the final mark, return null — the
 * journey is over.
 */
private fun nextAudienceMark(ordered: List<Mark>, currentID: Id?): Mark? {
    if (ordered.isEmpty()) return null
    val current = currentID?.let { id -> ordered.firstOrNull { it.id == id } }
        ?: return ordered.first()
    val after = ordered.firstOrNull { it.sequenceIndex > current.sequenceIndex }
    return after
}

/**
 * Normalize distance to the next mark into a 0..1 proximity glow.
 * Kept here for parity with Perform's guidance ring in case we want to
 * surface a proximity cue on the Audience AR overlay later.
 */
@Suppress("unused")
private fun audienceProximity(d: Float?): Float {
    if (d == null) return 0f
    return max(0f, min(1f, 1f - (d / 3f)))
}
