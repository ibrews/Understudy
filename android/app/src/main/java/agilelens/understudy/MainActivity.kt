package agilelens.understudy

import agilelens.understudy.ar.ArPoseProvider
import agilelens.understudy.model.Id
import agilelens.understudy.net.NetMessage
import agilelens.understudy.net.WebSocketTransport
import agilelens.understudy.ui.PerformerScreen
import agilelens.understudy.ui.SettingsScreen
import agilelens.understudy.ui.SettingsState
import agilelens.understudy.ui.theme.UnderstudyTheme
import android.Manifest
import android.content.Context
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
        // (Re)start transport with the latest prefs each time we resume.
        lifecycleScope.launch {
            val name = app.prefs.displayName.first()
            val room = app.prefs.roomCode.first()
            val url  = app.prefs.relayUrl.first()
            app.store.updateLocalDisplayName(name)
            app.transport.stop()
            app.transport.start(
                relayUrl = url,
                roomCode = room,
                localID = app.localId,
                displayName = name
            )
            // Introduce ourselves
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
    }

    // --- Composition ---

    @Composable
    private fun App() {
        val ctx = LocalContext.current
        val haveCamera = remember { mutableStateOf(hasCameraPermission()) }
        var showSettings by remember { mutableStateOf(false) }

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

        if (showSettings) {
            val state = remember { mutableStateOf<SettingsState?>(null) }
            LaunchedEffect(Unit) {
                val name = app.prefs.displayName.first()
                val room = app.prefs.roomCode.first()
                val url = app.prefs.relayUrl.first()
                state.value = SettingsState(name, room, url)
            }
            state.value?.let { s ->
                val scope = rememberCoroutineScope()
                SettingsScreen(
                    initial = s,
                    onSave = { saved ->
                        scope.launch {
                            app.prefs.setDisplayName(saved.displayName)
                            app.prefs.setRoomCode(saved.roomCode)
                            app.prefs.setRelayUrl(saved.relayUrl)
                            app.store.updateLocalDisplayName(saved.displayName)
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
            }
            return
        }

        val blocking by app.store.blocking.collectAsState()
        val local by app.store.localPerformer.collectAsState()
        val peers by app.transport.peerCount.collectAsState()
        val roomCode = remember { mutableStateOf("rehearsal") }
        LaunchedEffect(Unit) { roomCode.value = app.prefs.roomCode.first() }

        PerformerScreen(
            blocking = blocking,
            local = local,
            peerCount = peers,
            roomCode = roomCode.value,
            onOpenSettings = { showSettings = true }
        )
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
                    is NetMessage.CueFired -> { /* director-side; no-op on performer */ }
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
