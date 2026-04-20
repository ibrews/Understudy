package agilelens.understudy

import agilelens.understudy.cuefx.CueFXEngine
import agilelens.understudy.model.Id
import agilelens.understudy.net.WebSocketTransport
import agilelens.understudy.store.BlockingStore
import android.app.Application
import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

/**
 * Application holder — owns singletons shared across the Activity lifecycle
 * (transport, store, preferences).
 */
class UnderstudyApp : Application() {
    val appScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val _ready = CompletableDeferred<Unit>()
    /**
     * Await before accessing store, fx, or localId. Completes once DataStore
     * reads finish on IO thread; avoids blocking Application.onCreate (ANR risk).
     */
    val ready: Deferred<Unit> get() = _ready

    lateinit var prefs: PrefsRepo
        private set

    // transport can be created immediately — it needs no DataStore reads.
    lateinit var transport: WebSocketTransport
        private set

    lateinit var store: BlockingStore
        private set

    /**
     * Cue firing engine — owns the audio/flash/hold reactions to the store's
     * cueQueue. Attached once at bootstrap; every screen that needs to observe
     * flashState/holdState collects the engine's flows directly.
     */
    lateinit var fx: CueFXEngine
        private set

    lateinit var localId: Id
        private set

    override fun onCreate() {
        super.onCreate()
        prefs = PrefsRepo(this)
        transport = WebSocketTransport(appScope)

        // Read prefs on IO thread; complete `ready` when store + fx are live.
        // MainActivity awaits `ready` before calling transport.start() or
        // accessing store/fx, so the happens-before from CompletableDeferred
        // makes the lateinit assignments visible on the main thread.
        appScope.launch(Dispatchers.IO) {
            val raw = prefs.loadOrInitLocalId()
            val name = prefs.displayName.first()
            localId = Id(raw)
            val newStore = BlockingStore(localID = localId, localDisplayName = name)
            withContext(Dispatchers.Main) {
                store = newStore
                fx = CueFXEngine(context = this@UnderstudyApp).also { it.attach(store) }
                _ready.complete(Unit)
            }
        }
    }

    override fun onTerminate() {
        // Unit tests never hit this; Android process death runs it best-effort.
        super.onTerminate()
        try { fx.shutdown() } catch (_: Throwable) { /* ignore */ }
    }
}

// --- Preferences ---

private val Context.dataStore by preferencesDataStore(name = "understudy_prefs")

/**
 * App-wide mode — matches the iOS author/performer/audience cards.
 *
 * AUDIENCE turns the phone into a self-paced audio tour. The audience walks
 * between recorded marks and the next cue card fires when they step into the
 * target mark's radius (proximity alone — no wall-clock timing).
 */
enum class AppMode { UNSET, PERFORM, AUTHOR, AUDIENCE }

class PrefsRepo(private val context: Context) {
    private val KEY_LOCAL_ID = stringPreferencesKey("local_id")
    private val KEY_DISPLAY_NAME = stringPreferencesKey("display_name")
    private val KEY_ROOM = stringPreferencesKey("room_code")
    private val KEY_RELAY = stringPreferencesKey("relay_url")
    private val KEY_APP_MODE = stringPreferencesKey("app_mode")
    private val KEY_SHOW_AR_STAGE = stringPreferencesKey("show_ar_stage")
    private val KEY_SHOW_DEPTH_OVERLAY = stringPreferencesKey("show_depth_overlay")
    private val KEY_SHOW_FLOATING_SCRIPT = stringPreferencesKey("show_floating_script")
    private val KEY_AUTO_ADVANCE_ON_LAST_LINE = stringPreferencesKey("auto_advance_on_last_line")

    val displayName: kotlinx.coroutines.flow.Flow<String> =
        context.dataStore.data.map { it[KEY_DISPLAY_NAME] ?: defaultDisplayName() }

    val roomCode: kotlinx.coroutines.flow.Flow<String> =
        context.dataStore.data.map { it[KEY_ROOM] ?: "rehearsal" }

    val relayUrl: kotlinx.coroutines.flow.Flow<String> =
        context.dataStore.data.map { it[KEY_RELAY] ?: "ws://192.168.1.1:8765" }

    val appMode: kotlinx.coroutines.flow.Flow<AppMode> =
        context.dataStore.data.map {
            when (it[KEY_APP_MODE]) {
                "perform" -> AppMode.PERFORM
                "author" -> AppMode.AUTHOR
                "audience" -> AppMode.AUDIENCE
                else -> AppMode.UNSET
            }
        }

    val showARStage: kotlinx.coroutines.flow.Flow<Boolean> =
        context.dataStore.data.map { (it[KEY_SHOW_AR_STAGE] ?: "true") == "true" }

    val showDepthOverlay: kotlinx.coroutines.flow.Flow<Boolean> =
        context.dataStore.data.map { (it[KEY_SHOW_DEPTH_OVERLAY] ?: "false") == "true" }

    val showFloatingScript: kotlinx.coroutines.flow.Flow<Boolean> =
        context.dataStore.data.map { (it[KEY_SHOW_FLOATING_SCRIPT] ?: "false") == "true" }

    /**
     * When ON, crossing the last `Cue.Line` of a mark in voice mode pre-advances
     * `currentMarkID` to the next mark by `sequenceIndex` — the teleprompter
     * scrolls and the next mark's cues become voice-firable without waiting
     * for the performer to physically cross into the next mark's radius.
     * Default OFF to match existing behavior.
     */
    val autoAdvanceOnLastLine: kotlinx.coroutines.flow.Flow<Boolean> =
        context.dataStore.data.map { (it[KEY_AUTO_ADVANCE_ON_LAST_LINE] ?: "false") == "true" }

    suspend fun loadOrInitLocalId(): String {
        val existing = context.dataStore.data.map { it[KEY_LOCAL_ID] }.first()
        if (existing != null) return existing
        val fresh = UUID.randomUUID().toString()
        context.dataStore.edit { it[KEY_LOCAL_ID] = fresh }
        return fresh
    }

    suspend fun setDisplayName(v: String) {
        context.dataStore.edit { it[KEY_DISPLAY_NAME] = v }
    }
    suspend fun setRoomCode(v: String) {
        context.dataStore.edit { it[KEY_ROOM] = v }
    }
    suspend fun setRelayUrl(v: String) {
        context.dataStore.edit { it[KEY_RELAY] = v }
    }
    suspend fun setAppMode(v: AppMode) {
        context.dataStore.edit {
            it[KEY_APP_MODE] = when (v) {
                AppMode.PERFORM -> "perform"
                AppMode.AUTHOR -> "author"
                AppMode.AUDIENCE -> "audience"
                AppMode.UNSET -> ""
            }
        }
    }
    suspend fun setShowARStage(v: Boolean) {
        context.dataStore.edit { it[KEY_SHOW_AR_STAGE] = if (v) "true" else "false" }
    }
    suspend fun setShowDepthOverlay(v: Boolean) {
        context.dataStore.edit { it[KEY_SHOW_DEPTH_OVERLAY] = if (v) "true" else "false" }
    }
    suspend fun setShowFloatingScript(v: Boolean) {
        context.dataStore.edit { it[KEY_SHOW_FLOATING_SCRIPT] = if (v) "true" else "false" }
    }
    suspend fun setAutoAdvanceOnLastLine(v: Boolean) {
        context.dataStore.edit { it[KEY_AUTO_ADVANCE_ON_LAST_LINE] = if (v) "true" else "false" }
    }

    private fun defaultDisplayName(): String = android.os.Build.MODEL ?: "Android"
}
