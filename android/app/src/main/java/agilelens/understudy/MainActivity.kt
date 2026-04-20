package agilelens.understudy

import agilelens.understudy.ar.ArPoseProvider
import agilelens.understudy.model.Id
import agilelens.understudy.model.Mark
import agilelens.understudy.net.NetMessage
import agilelens.understudy.ui.AudienceScreen
import agilelens.understudy.ui.AuthorScreen
import agilelens.understudy.ui.MarkEditor
import agilelens.understudy.ui.ModePickerScreen
import agilelens.understudy.ui.PerformerScreen
import agilelens.understudy.ui.SettingsScreen
import agilelens.understudy.ui.SettingsState
import agilelens.understudy.ui.buildShareIntent
import agilelens.understudy.ui.parseBlockingJson
import agilelens.understudy.ui.readTextFromUri
import agilelens.understudy.ui.theme.UnderstudyTheme
import agilelens.understudy.ui.writeBlockingToShareableFile
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val app: UnderstudyApp
        get() = application as UnderstudyApp

    private lateinit var arProvider: ArPoseProvider

    // Pose send throttle
    private var lastSendEpochMs: Long = 0
    private val sendIntervalMs: Long = 100  // 10 Hz

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arProvider = ArPoseProvider(applicationContext)

        setContent {
            UnderstudyTheme {
                App()
            }
        }

        wireArToStoreAndTransport()
        wireIncomingEnvelopes()
    }

    override fun onResume() {
        super.onResume()
        if (hasCameraPermission()) {
            arProvider.resume(this)
        }
        lifecycleScope.launch {
            val name = app.prefs.displayName.first()
            val room = app.prefs.roomCode.first()
            val url  = app.prefs.relayUrl.first()
            app.store.updateLocalDisplayName(name)
            // Guard against rotation-induced duplicate connections: only
            // restart the socket when the destination or room has changed.
            if (!app.transport.isConnected(relayUrl = url, roomCode = room)) {
                app.transport.stop()
                app.transport.start(
                    relayUrl = url,
                    roomCode = room,
                    localID = app.localId,
                    displayName = name
                )
            }
            app.transport.send(NetMessage.Hello(app.store.localPerformer.value), app.localId)
        }
    }

    override fun onPause() {
        super.onPause()
        arProvider.pause()
        app.transport.stop()
    }

    override fun onDestroy() {
        super.onDestroy()
        arProvider.close()
        // Engine lives in UnderstudyApp, not the activity, so we don't shut it
        // down here — it needs to survive config changes (screen rotation etc).
    }

    // --- Composition ---

    @Composable
    private fun App() {
        val ctx = LocalContext.current
        val haveCamera = remember { mutableStateOf(hasCameraPermission()) }

        val permLauncher = rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission()
        ) { granted ->
            haveCamera.value = granted
            if (granted) arProvider.resume(this@MainActivity)
        }

        if (!haveCamera.value) {
            PermissionScreen(onRequest = { permLauncher.launch(Manifest.permission.CAMERA) })
            return
        }

        // Load all prefs up-front into composition state.
        val prefsState = remember { mutableStateOf<PrefsSnapshot?>(null) }
        LaunchedEffect(Unit) {
            prefsState.value = PrefsSnapshot(
                displayName = app.prefs.displayName.first(),
                roomCode = app.prefs.roomCode.first(),
                relayUrl = app.prefs.relayUrl.first(),
                appMode = app.prefs.appMode.first(),
                showArStage = app.prefs.showARStage.first(),
                showDepthOverlay = app.prefs.showDepthOverlay.first(),
                showFloatingScript = app.prefs.showFloatingScript.first(),
                autoAdvanceOnLastLine = app.prefs.autoAdvanceOnLastLine.first(),
            )
        }

        val snap = prefsState.value ?: return
        val scope = rememberCoroutineScope()

        // First-launch mode picker
        if (snap.appMode == AppMode.UNSET) {
            ModePickerScreen(onPick = { picked ->
                scope.launch {
                    app.prefs.setAppMode(picked)
                    prefsState.value = snap.copy(appMode = picked)
                }
            })
            return
        }

        var showSettings by remember { mutableStateOf(false) }
        var editingMarkId by remember { mutableStateOf<Id?>(null) }
        var showTeleprompter by remember { mutableStateOf(false) }

        if (showTeleprompter) {
            agilelens.understudy.teleprompter.TeleprompterScreen(
                store = app.store,
                onDismiss = { showTeleprompter = false },
                fx = app.fx,
                autoAdvanceOnLastLine = snap.autoAdvanceOnLastLine,
            )
            return
        }

        // Import launcher
        val openDocLauncher = rememberLauncherForActivityResult(
            ActivityResultContracts.OpenDocument()
        ) { uri ->
            if (uri != null) {
                val text = readTextFromUri(ctx, uri)
                val parsed = text?.let { parseBlockingJson(it) }
                if (parsed != null) {
                    app.store.replaceBlocking(parsed)
                    app.transport.send(NetMessage.BlockingSnapshot(parsed), app.localId)
                }
            }
        }

        if (showSettings) {
            SettingsScreen(
                initial = SettingsState(
                    displayName = snap.displayName,
                    roomCode = snap.roomCode,
                    relayUrl = snap.relayUrl,
                    appMode = snap.appMode,
                    showARStage = snap.showArStage,
                    showDepthOverlay = snap.showDepthOverlay,
                    showFloatingScript = snap.showFloatingScript,
                    autoAdvanceOnLastLine = snap.autoAdvanceOnLastLine,
                ),
                onSave = { saved ->
                    scope.launch {
                        app.prefs.setDisplayName(saved.displayName)
                        app.prefs.setRoomCode(saved.roomCode)
                        app.prefs.setRelayUrl(saved.relayUrl)
                        app.prefs.setAppMode(saved.appMode)
                        app.prefs.setShowARStage(saved.showARStage)
                        app.prefs.setShowDepthOverlay(saved.showDepthOverlay)
                        app.prefs.setShowFloatingScript(saved.showFloatingScript)
                        app.prefs.setAutoAdvanceOnLastLine(saved.autoAdvanceOnLastLine)
                        app.store.updateLocalDisplayName(saved.displayName)
                        prefsState.value = snap.copy(
                            displayName = saved.displayName,
                            roomCode = saved.roomCode,
                            relayUrl = saved.relayUrl,
                            appMode = saved.appMode,
                            showArStage = saved.showARStage,
                            showDepthOverlay = saved.showDepthOverlay,
                            showFloatingScript = saved.showFloatingScript,
                            autoAdvanceOnLastLine = saved.autoAdvanceOnLastLine,
                        )
                        // Reconnect with new settings
                        app.transport.stop()
                        app.transport.start(
                            relayUrl = saved.relayUrl,
                            roomCode = saved.roomCode,
                            localID = app.localId,
                            displayName = saved.displayName
                        )
                    }
                },
                onBack = { showSettings = false }
            )
            return
        }

        val blocking by app.store.blocking.collectAsState()
        val local by app.store.localPerformer.collectAsState()
        val peers by app.transport.peerCount.collectAsState()

        // Mark-editor sheet (full-screen)
        val editingMark: Mark? = editingMarkId?.let { id ->
            blocking.marks.firstOrNull { it.id == id }
        }
        if (editingMark != null) {
            MarkEditor(
                initial = editingMark,
                onChange = { updated ->
                    app.store.markUpdated(updated)
                    app.transport.send(NetMessage.MarkUpdated(updated), app.localId)
                },
                onDelete = {
                    app.store.markRemoved(editingMark.id)
                    app.transport.send(NetMessage.MarkRemoved(editingMark.id), app.localId)
                    editingMarkId = null
                },
                onBack = { editingMarkId = null },
                // v0.21 — Script Browser "Drop whole scene" feeds back through
                // these so a scene drop adds its marks and broadcasts each.
                performerPose = app.store.localPerformer.value.pose,
                existingMarks = blocking.marks,
                onMarksDrop = { newMarks ->
                    for (m in newMarks) {
                        app.store.markAdded(m)
                        app.transport.send(NetMessage.MarkAdded(m), app.localId)
                    }
                    editingMarkId = null
                },
            )
            return
        }

        when (snap.appMode) {
            AppMode.AUTHOR -> AuthorScreen(
                blocking = blocking,
                local = local,
                peerCount = peers,
                roomCode = snap.roomCode,
                onOpenTeleprompter = { showTeleprompter = true },
                onDropMarkHere = {
                    val pose = app.store.localPerformer.value.pose
                    val nextIndex = (blocking.marks.maxOfOrNull { it.sequenceIndex } ?: -1) + 1
                    val newMark = Mark(
                        id = Id(),
                        name = "Mark ${nextIndex + 1}",
                        pose = pose,
                        radius = 0.6f,
                        cues = emptyList(),
                        sequenceIndex = nextIndex
                    )
                    app.store.markAdded(newMark)
                    app.transport.send(NetMessage.MarkAdded(newMark), app.localId)
                    editingMarkId = newMark.id
                },
                onEditMark = { m -> editingMarkId = m.id },
                onExport = {
                    try {
                        val uri = writeBlockingToShareableFile(ctx, blocking)
                        val share = buildShareIntent(uri, blocking.title)
                        startActivity(Intent.createChooser(share, "Export blocking"))
                    } catch (_: Throwable) { /* swallow — can't realistically bubble to UI yet */ }
                },
                onImport = {
                    openDocLauncher.launch(arrayOf("application/json", "text/*", "*/*"))
                },
                onOpenSettings = { showSettings = true },
                // v0.22 — tap the AR stage to drop a mark at the tapped floor point.
                // Yaw inherits from the performer's facing so the new mark orients
                // naturally. If AR isn't on, onDropMarkAt is never called.
                arProvider = arProvider,
                showArStage = snap.showArStage,
                showDepthOverlay = snap.showDepthOverlay,
                onDropMarkAt = { worldX, worldZ ->
                    val localPose = app.store.localPerformer.value.pose
                    val nextIndex = (blocking.marks.maxOfOrNull { it.sequenceIndex } ?: -1) + 1
                    val newMark = Mark(
                        id = Id(),
                        name = "Mark ${nextIndex + 1}",
                        pose = agilelens.understudy.model.Pose(
                            x = worldX,
                            y = 0f,
                            z = worldZ,
                            yaw = localPose.yaw,
                        ),
                        radius = 0.6f,
                        cues = emptyList(),
                        sequenceIndex = nextIndex
                    )
                    app.store.markAdded(newMark)
                    app.transport.send(NetMessage.MarkAdded(newMark), app.localId)
                    editingMarkId = newMark.id
                },
            )
            AppMode.AUDIENCE -> AudienceScreen(
                blocking = blocking,
                local = local,
                peerCount = peers,
                roomCode = snap.roomCode,
                onOpenSettings = { showSettings = true },
                arProvider = arProvider,
                showArStage = snap.showArStage,
                fx = app.fx,
            )
            AppMode.PERFORM, AppMode.UNSET -> PerformerScreen(
                blocking = blocking,
                local = local,
                peerCount = peers,
                roomCode = snap.roomCode,
                onOpenSettings = { showSettings = true },
                arProvider = arProvider,
                showArStage = snap.showArStage,
                showDepthOverlay = snap.showDepthOverlay,
                showFloatingScript = snap.showFloatingScript,
                onOpenTeleprompter = { showTeleprompter = true },
                fx = app.fx,
            )
        }
    }

    @Composable
    private fun PermissionScreen(onRequest: () -> Unit) {
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.padding(24.dp)
            ) {
                Text("Understudy", color = Color.White, fontSize = 28.sp)
                Spacer(Modifier.height(8.dp))
                Text(
                    "Understudy needs your camera to track your position on the stage.",
                    color = Color.White.copy(alpha = 0.75f),
                    fontSize = 14.sp
                )
                Spacer(Modifier.height(16.dp))
                Button(
                    onClick = onRequest,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD2405A))
                ) { Text("Allow camera") }
            }
        }
    }

    // --- Wiring ---

    private fun wireArToStoreAndTransport() {
        arProvider.latest
            .onEach { sample ->
                sample ?: return@onEach
                val changed = app.store.updateLocalFromArSample(sample.pose, sample.quality)
                if (changed) haptic()

                val now = System.currentTimeMillis()
                if (now - lastSendEpochMs >= sendIntervalMs) {
                    lastSendEpochMs = now
                    app.transport.send(
                        NetMessage.PerformerUpdate(app.store.localPerformer.value),
                        app.localId
                    )
                }
            }
            .launchIn(lifecycleScope)
    }

    private fun wireIncomingEnvelopes() {
        app.transport.incoming
            .onEach { env ->
                when (val m = env.message) {
                    is NetMessage.BlockingSnapshot -> app.store.replaceBlocking(m.blocking)
                    is NetMessage.MarkAdded -> app.store.markAdded(m.mark)
                    is NetMessage.MarkUpdated -> app.store.markUpdated(m.mark)
                    is NetMessage.MarkRemoved -> app.store.markRemoved(m.id)
                    is NetMessage.Hello -> app.store.upsertPerformer(m.performer)
                    is NetMessage.PerformerUpdate -> app.store.upsertPerformer(m.performer)
                    is NetMessage.Goodbye -> app.store.removePerformer(m.id)
                    is NetMessage.CueFired -> {
                        // A peer (director) announced a cue fire — look up the
                        // cue on the named mark and fire it locally via the
                        // engine so every device in the room reacts in sync.
                        val mark = app.store.blocking.value.marks.firstOrNull { it.id == m.markID }
                        val cue = mark?.cues?.firstOrNull { it.id == m.cueID }
                        if (mark != null && cue != null) {
                            app.fx.preview(cue)
                        }
                    }
                    is NetMessage.PlaybackState -> { /* reserved */ }
                }
            }
            .launchIn(lifecycleScope)
    }

    // --- Permissions + haptics ---

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED

    private fun haptic() {
        val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        vibrator?.vibrate(
            VibrationEffect.createOneShot(60, VibrationEffect.DEFAULT_AMPLITUDE)
        )
    }
}

private data class PrefsSnapshot(
    val displayName: String,
    val roomCode: String,
    val relayUrl: String,
    val appMode: AppMode,
    val showArStage: Boolean,
    val showDepthOverlay: Boolean,
    val showFloatingScript: Boolean,
    val autoAdvanceOnLastLine: Boolean,
)
