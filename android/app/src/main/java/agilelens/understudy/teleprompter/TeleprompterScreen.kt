package agilelens.understudy.teleprompter

import agilelens.understudy.store.BlockingStore
import android.Manifest
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min

/**
 * Cross-platform-equivalent of the Swift TeleprompterView. Four scroll inputs:
 * manual drag, auto-scroll timer, voice mode, mark-follow.
 *
 * Karaoke rendering is the 3-color same as iOS — past at 35% gray, 30-char
 * active window in cyan, future in white.
 */
@Composable
fun TeleprompterScreen(store: BlockingStore, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var document by remember { mutableStateOf(TeleprompterDocument.from(store.blocking.value)) }
    var scrollProgress by rememberSaveable { mutableStateOf(0.0) }
    var textSize by rememberSaveable { mutableStateOf(28) }
    var speed by rememberSaveable { mutableStateOf(14) }  // cps
    var isAutoScrolling by remember { mutableStateOf(false) }
    var isVoiceMode by remember { mutableStateOf(false) }
    // Auto-fire lives behind a CueFXEngine-equivalent port to Kotlin — not
    // yet wired. When Android gets its own cue queue, this toggle + the
    // auto-fire branch below come alive. For now, voice mode just scrolls.
    val isAutoFire = false
    var lastHeard by remember { mutableStateOf("") }
    val fireFlashCount = 0
    val fireFlashAt = 0L

    val speech = remember { SpeechRecognitionDriver(context) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            isVoiceMode = true
            speech.start()
        }
    }

    // Rebuild document when the blocking mutates.
    LaunchedEffect(Unit) {
        store.blocking.collectLatest { b ->
            document = TeleprompterDocument.from(b)
        }
    }

    // Mark-follow — snap scroll when performer walks into a new mark.
    LaunchedEffect(Unit) {
        store.localPerformer.collectLatest { p ->
            val markId = p?.currentMarkID ?: return@collectLatest
            val target = document.progressForMark(markId) ?: return@collectLatest
            // Only snap if user hasn't been manually interacting in the last
            // 3 seconds. We approximate that here by always following — the
            // iOS version has a real timestamp check; Android keeps it simple.
            scrollProgress = target
        }
    }

    // Auto-scroll timer.
    LaunchedEffect(isAutoScrolling, speed) {
        if (!isAutoScrolling) return@LaunchedEffect
        val totalLen = document.text.length
        if (totalLen == 0) { isAutoScrolling = false; return@LaunchedEffect }
        val handler = Handler(Looper.getMainLooper())
        val runnable = object : Runnable {
            override fun run() {
                if (!isAutoScrolling) return
                val charsPerFrame = speed / 30.0
                val progressStep = charsPerFrame / totalLen.toDouble()
                val newP = (scrollProgress + progressStep).coerceIn(0.0, 1.0)
                scrollProgress = newP
                if (newP >= 1.0) isAutoScrolling = false
                else handler.postDelayed(this, 33)
            }
        }
        handler.post(runnable)
    }

    // Wire speech → voice matcher → scroll + auto-fire.
    LaunchedEffect(isVoiceMode) {
        if (!isVoiceMode) return@LaunchedEffect
        speech.onHeard = { transcript ->
            lastHeard = transcript.takeLast(64)
            val matched = VoiceMatcher.nextProgress(
                spoken = transcript,
                document = document,
                currentProgress = scrollProgress
            )
            if (matched != null && matched > scrollProgress) {
                scrollProgress = matched.coerceIn(0.0, 1.0)
                // Auto-fire branch lives here in Swift — Kotlin port pending
                // once Android's BlockingStore grows a cue queue + CueFXEngine.
            }
        }
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = Color.Black
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(Unit) {
                        detectVerticalDragGestures { _, dragAmount ->
                            val delta = -dragAmount / 1200f
                            scrollProgress = (scrollProgress + delta).coerceIn(0.0, 1.0)
                            isAutoScrolling = false
                        }
                    }
            ) {
                ScrollingText(
                    document = document,
                    scrollProgress = scrollProgress,
                    textSize = textSize
                )
                Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
                    TopBar(
                        title = store.blocking.value.title,
                        currentMark = document.markAt(scrollProgress)?.name,
                        onClose = onDismiss
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Controls(
                        isAutoScrolling = isAutoScrolling,
                        isVoiceMode = isVoiceMode,
                        isAutoFire = isAutoFire,
                        lastHeard = lastHeard,
                        speed = speed,
                        textSize = textSize,
                        fireFlashCount = fireFlashCount,
                        fireFlashAt = fireFlashAt,
                        onResetTop = {
                            scrollProgress = 0.0
                        },
                        onPlayPause = { isAutoScrolling = !isAutoScrolling },
                        onSpeedChange = { speed = it },
                        onTextSizeChange = { textSize = it },
                        onVoiceToggle = {
                            if (isVoiceMode) {
                                isVoiceMode = false
                                speech.stop()
                            } else if (speech.hasAudioPermission()) {
                                isVoiceMode = true
                                speech.start()
                            } else {
                                permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                            }
                        },
                        onAutoFireToggle = { /* pending Android CueFXEngine port */ }
                    )
                }
            }
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            speech.stop()
        }
    }
}

@Composable
private fun ScrollingText(
    document: TeleprompterDocument,
    scrollProgress: Double,
    textSize: Int
) {
    val text = document.text
    if (text.isEmpty()) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                "No lines on this blocking yet.\nAuthor mode → tap a mark → Pick from Hamlet…",
                color = Color.White.copy(alpha = 0.55f),
                textAlign = TextAlign.Center
            )
        }
        return
    }
    val totalLen = text.length
    val cursor = (totalLen * scrollProgress).toInt().coerceIn(0, totalLen - 1)
    val activeEnd = min(cursor + 30, totalLen)

    val annotated = buildAnnotatedString {
        withStyle(SpanStyle(color = Color.White.copy(alpha = 0.35f))) {
            append(text.substring(0, cursor))
        }
        withStyle(SpanStyle(color = Color.Cyan)) {
            append(text.substring(cursor, activeEnd))
        }
        withStyle(SpanStyle(color = Color.White)) {
            append(text.substring(activeEnd))
        }
    }

    val estimatedLineHeight = textSize * 1.4
    val estimatedContentHeight = (totalLen / 60.0) * estimatedLineHeight
    val scrollState = rememberScrollState()

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp)
                .verticalScroll(scrollState),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height((estimatedContentHeight.toInt()).dp * 0 + 180.dp))
            Text(
                annotated,
                fontSize = textSize.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Serif,
                lineHeight = (textSize * 1.4).sp,
                textAlign = TextAlign.Center,
                color = Color.Unspecified
            )
            Spacer(modifier = Modifier.height(600.dp))
        }
    }

    // Best-effort auto-center: scroll by progress * contentHeight. We don't
    // have TextLayoutResult per-line control as iOS lacks it too; good
    // enough for theatrical pacing.
    LaunchedEffect(scrollProgress) {
        val target = (scrollProgress * max(1, scrollState.maxValue)).toInt()
        scrollState.animateScrollTo(target)
    }
}

@Composable
private fun TopBar(title: String, currentMark: String?, onClose: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onClose) {
            Icon(Icons.Filled.Close, contentDescription = "Close", tint = Color.White)
        }
        Spacer(Modifier.weight(1f))
        Text(title, color = Color.White, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.weight(1f))
        if (currentMark != null) {
            Surface(
                color = Color.White.copy(alpha = 0.12f),
                shape = RoundedCornerShape(16.dp),
            ) {
                Text(
                    currentMark,
                    color = Color.White,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp
                )
            }
        }
    }
}

@Composable
private fun Controls(
    isAutoScrolling: Boolean,
    isVoiceMode: Boolean,
    isAutoFire: Boolean,
    lastHeard: String,
    speed: Int,
    textSize: Int,
    fireFlashCount: Int,
    fireFlashAt: Long,
    onResetTop: () -> Unit,
    onPlayPause: () -> Unit,
    onSpeedChange: (Int) -> Unit,
    onTextSizeChange: (Int) -> Unit,
    onVoiceToggle: () -> Unit,
    onAutoFireToggle: () -> Unit,
) {
    val flashVisible = (System.currentTimeMillis() - fireFlashAt) < 2000L
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        if (flashVisible && fireFlashCount > 0) {
            Surface(color = Color(0xFFFF9800).copy(alpha = 0.9f),
                    shape = RoundedCornerShape(16.dp)) {
                Text(
                    "🔥 $fireFlashCount cue${if (fireFlashCount == 1) "" else "s"} fired",
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                    color = Color.Black,
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp
                )
            }
            Spacer(Modifier.height(6.dp))
        }
        if (lastHeard.isNotEmpty() && isVoiceMode) {
            Text(
                "heard: $lastHeard",
                color = Color.Cyan.copy(alpha = 0.75f),
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
                maxLines = 1
            )
            Spacer(Modifier.height(6.dp))
        }
        Surface(
            color = Color.Black.copy(alpha = 0.75f),
            shape = RoundedCornerShape(16.dp),
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onResetTop) {
                    Icon(Icons.Filled.SkipPrevious, "Back to top", tint = Color.White)
                }
                IconButton(
                    onClick = onPlayPause,
                    modifier = Modifier.background(
                        if (isAutoScrolling) Color(0xFFFF9800) else Color.White.copy(alpha = 0.2f),
                        CircleShape
                    )
                ) {
                    Icon(
                        if (isAutoScrolling) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        contentDescription = "Play/pause",
                        tint = Color.White
                    )
                }
                Column(modifier = Modifier.padding(horizontal = 10.dp)) {
                    Text("Speed $speed cps", color = Color.White.copy(alpha = 0.75f),
                         fontSize = 10.sp, fontFamily = FontFamily.Monospace)
                    Slider(
                        value = speed.toFloat(),
                        onValueChange = { onSpeedChange(it.toInt()) },
                        valueRange = 4f..40f,
                        modifier = Modifier.width(120.dp)
                    )
                }
                Column(modifier = Modifier.padding(horizontal = 6.dp)) {
                    Text("Size", color = Color.White.copy(alpha = 0.75f), fontSize = 10.sp)
                    Slider(
                        value = textSize.toFloat(),
                        onValueChange = { onTextSizeChange(it.toInt()) },
                        valueRange = 18f..56f,
                        modifier = Modifier.width(80.dp)
                    )
                }
                IconButton(
                    onClick = onVoiceToggle,
                    modifier = Modifier.background(
                        if (isVoiceMode) Color.Red else Color.White.copy(alpha = 0.2f),
                        CircleShape
                    )
                ) {
                    Icon(
                        if (isVoiceMode) Icons.Filled.Mic else Icons.Filled.MicOff,
                        contentDescription = "Voice",
                        tint = Color.White
                    )
                }
                IconButton(
                    onClick = onAutoFireToggle,
                    enabled = isVoiceMode,
                    modifier = Modifier.background(
                        if (isAutoFire && isVoiceMode) Color(0xFFFF9800)
                        else Color.White.copy(alpha = 0.2f),
                        CircleShape
                    )
                ) {
                    Icon(
                        Icons.Filled.Whatshot,
                        contentDescription = "Auto-fire",
                        tint = Color.White
                    )
                }
            }
        }
    }
}
