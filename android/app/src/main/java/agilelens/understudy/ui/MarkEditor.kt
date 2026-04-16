package agilelens.understudy.ui

import agilelens.understudy.model.Cue
import agilelens.understudy.model.Id
import agilelens.understudy.model.LightColor
import agilelens.understudy.model.Mark
import agilelens.understudy.model.humanLabel
import agilelens.understudy.ui.theme.CurtainBlack
import agilelens.understudy.ui.theme.CurtainRed
import agilelens.understudy.ui.theme.StageRed
import agilelens.understudy.ui.theme.WhiteDim
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
 * Full-screen mark editor. Every edit is committed immediately through `onChange`,
 * which is wired to the transport (markUpdated envelope) at the call site.
 */
@Composable
fun MarkEditor(
    initial: Mark,
    onChange: (Mark) -> Unit,
    onDelete: () -> Unit,
    onBack: () -> Unit,
    // v0.21 — Script Browser needs these to be able to "Drop whole scene"
    // from the browser, which spawns N new marks in front of the performer.
    // Callers that don't support drop-scene (e.g. early-version tests) can
    // pass empty/no-op defaults.
    performerPose: agilelens.understudy.model.Pose = agilelens.understudy.model.Pose(),
    existingMarks: List<Mark> = emptyList(),
    onMarksDrop: (List<Mark>) -> Unit = {},
) {
    var name by remember { mutableStateOf(initial.name) }
    var radius by remember { mutableStateOf(initial.radius) }
    var cues by remember { mutableStateOf(initial.cues) }
    var showScriptBrowser by remember { mutableStateOf(false) }

    // Helpers — commit whenever any field changes
    fun commit(
        newName: String = name,
        newRadius: Float = radius,
        newCues: List<Cue> = cues
    ) {
        name = newName
        radius = newRadius
        cues = newCues
        onChange(initial.copy(name = newName, radius = newRadius, cues = newCues))
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(CurtainGradient)
    ) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            // Top bar
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = WhiteText
                    )
                }
                Text("Edit mark", color = WhiteText, fontSize = 20.sp)
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onDelete) {
                    Icon(
                        Icons.Filled.Delete,
                        contentDescription = "Delete mark",
                        tint = StageRed
                    )
                }
            }
            Spacer(Modifier.height(12.dp))

            // Name
            SectionLabel("Name")
            DarkField(
                value = name,
                onChange = { commit(newName = it) },
                placeholder = "e.g. Downstage centre"
            )
            Spacer(Modifier.height(16.dp))

            // Radius
            SectionLabel("Radius: ${"%.2f".format(radius)} m")
            Slider(
                value = radius,
                onValueChange = { commit(newRadius = it) },
                valueRange = 0.2f..2.0f
            )
            Spacer(Modifier.height(24.dp))

            // Cues list
            SectionLabel("Cues")
            Spacer(Modifier.height(6.dp))
            if (cues.isEmpty()) {
                Text("No cues yet.", color = WhiteDim, fontSize = 13.sp)
            } else {
                cues.forEach { cue ->
                    CueListRow(
                        cue = cue,
                        onRemove = { commit(newCues = cues.filter { it.id != cue.id }) }
                    )
                    Spacer(Modifier.height(6.dp))
                }
            }
            Spacer(Modifier.height(12.dp))

            AddLineRow(
                onAdd = { line -> commit(newCues = cues + line) },
                onOpenScriptBrowser = { showScriptBrowser = true }
            )
            Spacer(Modifier.height(8.dp))
            AddSfxRow { sfx -> commit(newCues = cues + sfx) }
            Spacer(Modifier.height(8.dp))
            AddLightRow { light -> commit(newCues = cues + light) }
            Spacer(Modifier.height(8.dp))
            AddWaitRow { wait -> commit(newCues = cues + wait) }
            Spacer(Modifier.height(8.dp))
            AddNoteRow { note -> commit(newCues = cues + note) }
            Spacer(Modifier.height(48.dp))
        }
    }

    if (showScriptBrowser) {
        ScriptBrowserDialog(
            currentMark = initial.copy(name = name, radius = radius, cues = cues),
            performerPose = performerPose,
            existingMarks = existingMarks,
            onMarkChange = { updated ->
                cues = updated.cues
                onChange(initial.copy(name = name, radius = radius, cues = updated.cues))
            },
            onMarksDrop = { marks ->
                onMarksDrop(marks)
                showScriptBrowser = false
            },
            onDismiss = { showScriptBrowser = false }
        )
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(text.uppercase(), color = WhiteDim, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
}

@Composable
private fun PickFromScriptButton(onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        color = Color(0xFF9C27B0).copy(alpha = 0.78f),   // theatrical purple
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Filled.MenuBook,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "Pick from script…",
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun CueListRow(cue: Cue, onRemove: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = cue.humanLabel(),
            color = WhiteText,
            fontSize = 14.sp,
            modifier = Modifier.weight(1f)
        )
        IconButton(onClick = onRemove) {
            Icon(
                Icons.Filled.Close,
                contentDescription = "Remove cue",
                tint = WhiteDim
            )
        }
    }
}

@Composable
private fun AddLineRow(
    onAdd: (Cue.Line) -> Unit,
    onOpenScriptBrowser: () -> Unit = {},
) {
    var character by remember { mutableStateOf("") }
    var text by remember { mutableStateOf("") }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .padding(12.dp)
    ) {
        SectionLabel("Add line")
        Spacer(Modifier.height(6.dp))
        PickFromScriptButton(onClick = onOpenScriptBrowser)
        Spacer(Modifier.height(8.dp))
        DarkField(character, onChange = { character = it }, placeholder = "Character (optional)")
        Spacer(Modifier.height(6.dp))
        DarkField(text, onChange = { text = it }, placeholder = "Custom line text")
        Spacer(Modifier.height(6.dp))
        AddButton(enabled = text.isNotBlank()) {
            onAdd(
                Cue.Line(
                    id = Id(),
                    text = text.trim(),
                    character = character.trim().ifBlank { null }
                )
            )
            character = ""
            text = ""
        }
    }
}

private val SFX_NAMES = listOf("thunder", "door", "applause", "phone", "glass")

@Composable
private fun AddSfxRow(onAdd: (Cue.Sfx) -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .padding(12.dp)
    ) {
        SectionLabel("Add SFX")
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            SFX_NAMES.forEach { n ->
                Chip(text = n) { onAdd(Cue.Sfx(id = Id(), name = n)) }
            }
        }
    }
}

@Composable
private fun AddLightRow(onAdd: (Cue.Light) -> Unit) {
    var selectedColor by remember { mutableStateOf(LightColor.warm) }
    var intensity by remember { mutableStateOf(0.8f) }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .padding(12.dp)
    ) {
        SectionLabel("Add light")
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            LightColor.values().forEach { c ->
                val on = c == selectedColor
                Box(
                    Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (on) StageRed.copy(alpha = 0.7f)
                            else Color.White.copy(alpha = 0.08f)
                        )
                        .clickable { selectedColor = c }
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Text(c.name, color = WhiteText, fontSize = 12.sp)
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Text("Intensity: ${"%.2f".format(intensity)}", color = WhiteDim, fontSize = 11.sp)
        Slider(value = intensity, onValueChange = { intensity = it }, valueRange = 0f..1f)
        AddButton {
            onAdd(Cue.Light(id = Id(), color = selectedColor, intensity = intensity))
        }
    }
}

@Composable
private fun AddWaitRow(onAdd: (Cue.Wait) -> Unit) {
    var seconds by remember { mutableStateOf(1.0f) }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .padding(12.dp)
    ) {
        SectionLabel("Add hold")
        Spacer(Modifier.height(6.dp))
        Text("Seconds: ${"%.1f".format(seconds)}", color = WhiteDim, fontSize = 11.sp)
        Slider(value = seconds, onValueChange = { seconds = it }, valueRange = 0.5f..10f)
        AddButton { onAdd(Cue.Wait(id = Id(), seconds = seconds.toDouble())) }
    }
}

@Composable
private fun AddNoteRow(onAdd: (Cue.Note) -> Unit) {
    var text by remember { mutableStateOf("") }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .padding(12.dp)
    ) {
        SectionLabel("Add note")
        Spacer(Modifier.height(6.dp))
        DarkField(text, onChange = { text = it }, placeholder = "Note to self")
        Spacer(Modifier.height(6.dp))
        AddButton(enabled = text.isNotBlank()) {
            onAdd(Cue.Note(id = Id(), text = text.trim()))
            text = ""
        }
    }
}

@Composable
private fun Chip(text: String, onClick: () -> Unit) {
    Box(
        Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .clickable { onClick() }
            .padding(horizontal = 10.dp, vertical = 6.dp)
    ) {
        Text(text, color = WhiteText, fontSize = 12.sp)
    }
}

@Composable
private fun AddButton(enabled: Boolean = true, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(
            containerColor = StageRed,
            disabledContainerColor = Color.White.copy(alpha = 0.12f)
        )
    ) {
        Icon(Icons.Filled.Add, contentDescription = null, tint = WhiteText)
        Spacer(Modifier.width(4.dp))
        Text("Add", color = WhiteText, fontSize = 13.sp)
    }
}

@Composable
internal fun DarkField(
    value: String,
    onChange: (String) -> Unit,
    placeholder: String
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        placeholder = { Text(placeholder, color = WhiteDim) },
        singleLine = true,
        colors = TextFieldDefaults.colors(
            focusedTextColor = WhiteText,
            unfocusedTextColor = WhiteText,
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            cursorColor = WhiteText,
            focusedIndicatorColor = WhiteText,
            unfocusedIndicatorColor = WhiteDim
        ),
        modifier = Modifier.fillMaxWidth()
    )
}
