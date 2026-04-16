package agilelens.understudy.ui

import agilelens.understudy.BuildConfig
import agilelens.understudy.model.Blocking
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark
import agilelens.understudy.model.Performer
import agilelens.understudy.ui.theme.CurtainBlack
import agilelens.understudy.ui.theme.CurtainRed
import agilelens.understudy.ui.theme.StageRed
import agilelens.understudy.ui.theme.WhiteDim
import agilelens.understudy.ui.theme.WhiteFaint
import agilelens.understudy.ui.theme.WhiteText
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val CurtainGradient = Brush.verticalGradient(colors = listOf(CurtainRed, CurtainBlack))

/**
 * Author mode — list of marks + drop / export / import actions.
 * Mutations fan out through the callbacks; the Activity broadcasts them over the transport.
 */
@Composable
fun AuthorScreen(
    blocking: Blocking,
    local: Performer,
    peerCount: Int,
    roomCode: String,
    onDropMarkHere: () -> Unit,
    onEditMark: (Mark) -> Unit,
    onExport: () -> Unit,
    onImport: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenTeleprompter: () -> Unit = {}
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(CurtainGradient)
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .padding(16.dp)
        ) {
            // Top bar
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = blocking.title,
                            color = WhiteText,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Spacer(Modifier.width(8.dp))
                        ModeChip("AUTHOR")
                    }
                    Text(
                        text = "Room: $roomCode  •  $peerCount peers  •  v${BuildConfig.APP_VERSION} (${BuildConfig.APP_BUILD})",
                        color = WhiteDim,
                        fontSize = 11.sp
                    )
                }
                IconButton(onClick = onOpenTeleprompter) {
                    Icon(
                        Icons.Filled.Description,
                        contentDescription = "Teleprompter",
                        tint = WhiteText
                    )
                }
                IconButton(onClick = onImport) {
                    Icon(Icons.Filled.FileUpload, contentDescription = "Import", tint = WhiteText)
                }
                IconButton(onClick = onExport) {
                    Icon(Icons.Filled.FileDownload, contentDescription = "Export", tint = WhiteText)
                }
                IconButton(onClick = onOpenSettings) {
                    Box(
                        Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.08f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Filled.Settings, contentDescription = "Settings", tint = WhiteText)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))

            // Stats / subtitle
            Text(
                text = "${blocking.marks.size} marks on stage",
                color = WhiteDim,
                fontSize = 13.sp
            )
            Spacer(Modifier.height(8.dp))

            // Marks list
            if (blocking.marks.isEmpty()) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(200.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color.White.copy(alpha = 0.05f))
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Tap \"Drop mark here\" to place your first mark at your current position.",
                        color = WhiteDim,
                        fontSize = 14.sp
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(
                        items = blocking.marks.sortedBy { it.sequenceIndex },
                        key = { it.id.raw }
                    ) { mark ->
                        MarkRow(mark = mark, onClick = { onEditMark(mark) })
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            // Big drop-mark button
            Button(
                onClick = onDropMarkHere,
                colors = ButtonDefaults.buttonColors(containerColor = StageRed),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(64.dp)
            ) {
                Icon(Icons.Filled.Add, contentDescription = null, tint = WhiteText)
                Spacer(Modifier.width(8.dp))
                Text("Drop mark here", color = WhiteText, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = "Pose: x=${"%.2f".format(local.pose.x)}  z=${"%.2f".format(local.pose.z)}",
                color = WhiteFaint,
                fontSize = 11.sp
            )
        }
    }
}

@Composable
private fun MarkRow(mark: Mark, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(mark.name.ifBlank { "(unnamed)" }, color = WhiteText, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            Text(
                text = "r=${"%.2f".format(mark.radius)}m  •  ${mark.cues.size} cue${if (mark.cues.size == 1) "" else "s"}",
                color = WhiteDim,
                fontSize = 11.sp
            )
        }
        Text(
            text = "(${"%.1f".format(mark.pose.x)}, ${"%.1f".format(mark.pose.z)})",
            color = WhiteDim,
            fontSize = 11.sp
        )
    }
}

@Composable
private fun ModeChip(label: String) {
    Box(
        Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(StageRed.copy(alpha = 0.8f))
            .padding(horizontal = 8.dp, vertical = 2.dp)
    ) {
        Text(label, color = WhiteText, fontSize = 10.sp, fontWeight = FontWeight.Bold)
    }
}
