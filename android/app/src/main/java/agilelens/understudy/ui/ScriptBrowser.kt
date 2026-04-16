package agilelens.understudy.ui

import agilelens.understudy.model.Cue
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark
import agilelens.understudy.model.Pose
import agilelens.understudy.teleprompter.PlayScript
import agilelens.understudy.teleprompter.ScenePlacer
import agilelens.understudy.teleprompter.Scripts
import androidx.compose.foundation.background
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties

/**
 * Port of Swift's ScriptBrowser. Opens from Author mode's MarkEditor as a
 * full-screen dialog over the mark editor. Lists every line from the
 * selected play; tap to add (or remove) as a `.line` cue on the currently-
 * editing mark.
 *
 * Also supports "Drop whole scene" — one tap and ScenePlacer generates a
 * zig-zag walk of marks in front of the performer's current pose with all
 * the dialogue pre-populated.
 */
@Composable
fun ScriptBrowserDialog(
    currentMark: Mark,
    performerPose: Pose,
    existingMarks: List<Mark>,
    onMarkChange: (Mark) -> Unit,
    onMarksDrop: (List<Mark>) -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current

    var playRef by remember { mutableStateOf(Scripts.all.first()) }
    var script by remember { mutableStateOf<PlayScript?>(null) }
    var query by remember { mutableStateOf("") }
    var sceneFilter by remember { mutableStateOf<SceneFilter>(SceneFilter.All) }
    var showPlayMenu by remember { mutableStateOf(false) }
    var showSceneFilterMenu by remember { mutableStateOf(false) }
    var dropSceneConfirm by remember { mutableStateOf<PlayScript.Scene?>(null) }

    // Load the script whenever the play changes.
    LaunchedEffect(playRef) {
        script = Scripts.load(context, playRef.assetName)
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = Color.Black
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // Top bar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Filled.Close, "Close", tint = Color.White)
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            script?.title ?: playRef.displayName,
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            script?.author ?: playRef.author,
                            color = Color.White.copy(alpha = 0.55f),
                            fontSize = 11.sp,
                        )
                    }
                    IconButton(onClick = { showPlayMenu = true }) {
                        Icon(Icons.Filled.MenuBook, "Switch play", tint = Color.White)
                    }
                    DropdownMenu(
                        expanded = showPlayMenu,
                        onDismissRequest = { showPlayMenu = false },
                    ) {
                        for (p in Scripts.all) {
                            DropdownMenuItem(
                                text = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text("${p.displayName} — ${p.author}")
                                        if (p.assetName == playRef.assetName) {
                                            Spacer(Modifier.width(8.dp))
                                            Icon(Icons.Filled.CheckCircle, null,
                                                tint = Color(0xFF4CAF50),
                                                modifier = Modifier.size(16.dp))
                                        }
                                    }
                                },
                                onClick = {
                                    playRef = p
                                    sceneFilter = SceneFilter.All
                                    query = ""
                                    showPlayMenu = false
                                }
                            )
                        }
                    }
                    IconButton(onClick = { showSceneFilterMenu = true }) {
                        Icon(Icons.Filled.FilterList, "Filter scene", tint = Color.White)
                    }
                    SceneFilterMenu(
                        expanded = showSceneFilterMenu,
                        script = script,
                        current = sceneFilter,
                        onSelect = {
                            sceneFilter = it
                            showSceneFilterMenu = false
                        },
                        onDismiss = { showSceneFilterMenu = false }
                    )
                }

                // Search bar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 4.dp)
                        .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 10.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Filled.Search, null,
                        tint = Color.White.copy(alpha = 0.5f),
                        modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    BasicTextField(
                        value = query,
                        onValueChange = { query = it },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                        textStyle = TextStyle(color = Color.White, fontSize = 15.sp),
                        cursorBrush = SolidColor(Color.White),
                        decorationBox = { inner ->
                            if (query.isEmpty()) {
                                Text(
                                    "Find a line or character",
                                    color = Color.White.copy(alpha = 0.4f),
                                    fontSize = 15.sp
                                )
                            }
                            inner()
                        }
                    )
                    if (query.isNotEmpty()) {
                        IconButton(onClick = { query = "" }) {
                            Icon(Icons.Filled.Close, "Clear",
                                tint = Color.White.copy(alpha = 0.4f),
                                modifier = Modifier.size(16.dp))
                        }
                    }
                }

                // Counts row
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val filtered = script?.linesMatching(query)
                        ?.filter { matchesFilter(it, sceneFilter) }
                        ?: emptyList()
                    Text(
                        "${filtered.size} lines",
                        color = Color.White.copy(alpha = 0.5f),
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                        modifier = Modifier.weight(1f)
                    )
                    val lineCuesOnMark = currentMark.cues.count { it is Cue.Line }
                    Text(
                        "$lineCuesOnMark on this mark",
                        color = Color.White.copy(alpha = 0.5f),
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
                Divider(color = Color.White.copy(alpha = 0.1f), thickness = 1.dp)

                // List of lines
                LineList(
                    script = script,
                    query = query,
                    sceneFilter = sceneFilter,
                    currentMark = currentMark,
                    onLineToggle = { line ->
                        onMarkChange(toggleLine(currentMark, line))
                    },
                    onSceneDrop = { scene -> dropSceneConfirm = scene }
                )
            }
        }
    }

    dropSceneConfirm?.let { scene ->
        val marks = remember(scene, performerPose, existingMarks) {
            val nextIdx = (existingMarks.maxOfOrNull { it.sequenceIndex } ?: -1) + 1
            ScenePlacer.layout(
                scene = scene,
                origin = performerPose,
                sequenceOffset = nextIdx,
            )
        }
        AlertDialog(
            onDismissRequest = { dropSceneConfirm = null },
            title = { Text("Drop whole scene?") },
            text = {
                Text(
                    "Adds ${marks.size} marks in front of your current pose " +
                        "arranged in a zig-zag path, pre-populated with lines " +
                        "from \"${scene.location}\"."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    onMarksDrop(marks)
                    dropSceneConfirm = null
                    onDismiss()
                }) { Text("Drop ${marks.size} marks") }
            },
            dismissButton = {
                TextButton(onClick = { dropSceneConfirm = null }) { Text("Cancel") }
            }
        )
    }
}

sealed class SceneFilter {
    object All : SceneFilter()
    data class OneScene(val actNum: Int, val sceneNum: Int) : SceneFilter()
}

private fun matchesFilter(line: PlayScript.LocatedLine, filter: SceneFilter): Boolean {
    return when (filter) {
        is SceneFilter.All -> true
        is SceneFilter.OneScene -> {
            val parts = line.lineID.split(".")
            parts.size == 3 &&
                parts[0].toIntOrNull() == filter.actNum &&
                parts[1].toIntOrNull() == filter.sceneNum
        }
    }
}

@Composable
private fun SceneFilterMenu(
    expanded: Boolean,
    script: PlayScript?,
    current: SceneFilter,
    onSelect: (SceneFilter) -> Unit,
    onDismiss: () -> Unit,
) {
    DropdownMenu(expanded = expanded, onDismissRequest = onDismiss) {
        DropdownMenuItem(
            text = { Text("All scenes") },
            onClick = { onSelect(SceneFilter.All) }
        )
        script?.acts?.forEach { act ->
            for (scene in act.scenes) {
                DropdownMenuItem(
                    text = {
                        Text(
                            "Act ${act.roman}, Scene ${scene.roman} — ${scene.location.take(40)}",
                            fontSize = 12.sp
                        )
                    },
                    onClick = {
                        onSelect(SceneFilter.OneScene(act.number, scene.number))
                    }
                )
            }
        }
    }
}

@Composable
private fun LineList(
    script: PlayScript?,
    query: String,
    sceneFilter: SceneFilter,
    currentMark: Mark,
    onLineToggle: (PlayScript.LocatedLine) -> Unit,
    onSceneDrop: (PlayScript.Scene) -> Unit,
) {
    if (script == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = Color.White.copy(alpha = 0.6f))
        }
        return
    }
    val filtered = script.linesMatching(query).filter { matchesFilter(it, sceneFilter) }
    if (filtered.isEmpty()) {
        Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
            Text(
                "No matches. Try a shorter query or clear the filter.",
                color = Color.White.copy(alpha = 0.55f),
                fontSize = 14.sp
            )
        }
        return
    }

    val sceneLookup = remember(script) {
        buildMap<String, PlayScript.Scene> {
            for (act in script.acts) {
                for (scene in act.scenes) {
                    put("${act.roman}.${scene.roman}", scene)
                }
            }
        }
    }

    // Group by scene, preserving reading order.
    val grouped: List<Pair<String, List<PlayScript.LocatedLine>>> =
        buildList<Pair<String, MutableList<PlayScript.LocatedLine>>> {
            for (line in filtered) {
                val key = "${line.actRoman}.${line.sceneRoman}"
                if (isEmpty() || last().first != key) {
                    add(key to mutableListOf(line))
                } else {
                    last().second.add(line)
                }
            }
        }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 60.dp)
    ) {
        for ((key, lines) in grouped) {
            val sample = lines.first()
            item(key = "header-$key") {
                SceneHeader(
                    actRoman = sample.actRoman,
                    sceneRoman = sample.sceneRoman,
                    location = sample.location,
                    onDropScene = {
                        val scene = sceneLookup[key] ?: return@SceneHeader
                        onSceneDrop(scene)
                    }
                )
            }
            items(lines, key = { it.lineID }) { line ->
                ScriptLineRow(
                    line = line,
                    isOnMark = lineOnMark(line, currentMark),
                    onTap = { onLineToggle(line) }
                )
            }
        }
    }
}

@Composable
private fun SceneHeader(
    actRoman: String,
    sceneRoman: String,
    location: String,
    onDropScene: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.Black)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "Act $actRoman  •  Scene $sceneRoman",
                color = Color.White.copy(alpha = 0.65f),
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold
            )
            Text(
                location,
                color = Color.White.copy(alpha = 0.4f),
                fontSize = 11.sp,
            )
        }
        Surface(
            color = Color.Red.copy(alpha = 0.75f),
            shape = CircleShape,
        ) {
            Row(
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Color.Red.copy(alpha = 0.75f))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(
                    onClick = onDropScene,
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp)
                ) {
                    Text("Drop scene",
                        color = Color.White,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun ScriptLineRow(
    line: PlayScript.LocatedLine,
    isOnMark: Boolean,
    onTap: () -> Unit,
) {
    Surface(
        color = Color.Black,
        onClick = onTap,
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.Top
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    line.character,
                    color = Color.Red.copy(alpha = 0.85f),
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(3.dp))
                Text(
                    line.text,
                    color = Color.White.copy(alpha = 0.92f),
                    fontSize = 15.sp,
                    fontFamily = FontFamily.Serif,
                )
            }
            Spacer(Modifier.width(10.dp))
            Icon(
                if (isOnMark) Icons.Filled.CheckCircle else Icons.Filled.Add,
                contentDescription = if (isOnMark) "Remove from mark" else "Add to mark",
                tint = if (isOnMark) Color(0xFF4CAF50) else Color.White.copy(alpha = 0.4f),
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

private fun lineOnMark(line: PlayScript.LocatedLine, mark: Mark): Boolean =
    mark.cues.any { cue ->
        cue is Cue.Line &&
            cue.text == line.text &&
            cue.character == line.character
    }

private fun toggleLine(mark: Mark, line: PlayScript.LocatedLine): Mark {
    val matchIdx = mark.cues.indexOfFirst { cue ->
        cue is Cue.Line && cue.text == line.text && cue.character == line.character
    }
    return if (matchIdx >= 0) {
        mark.copy(cues = mark.cues.toMutableList().also { it.removeAt(matchIdx) })
    } else {
        mark.copy(cues = mark.cues + Cue.Line(
            id = Id(),
            text = line.text,
            character = line.character
        ))
    }
}

