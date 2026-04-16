package agilelens.understudy

import agilelens.understudy.model.Id
import agilelens.understudy.net.WebSocketTransport
import agilelens.understudy.store.BlockingStore
import android.app.Application
import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.util.UUID

/**
 * Application holder — owns singletons shared across the Activity lifecycle
 * (transport, store, preferences).
 */
class UnderstudyApp : Application() {
    val appScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    lateinit var prefs: PrefsRepo
        private set

    lateinit var transport: WebSocketTransport
        private set

    lateinit var store: BlockingStore
        private set

    lateinit var localId: Id
        private set

    override fun onCreate() {
        super.onCreate()
        prefs = PrefsRepo(this)

        // Bootstrap local identity
        val raw = runBlocking { prefs.loadOrInitLocalId() }
        localId = Id(raw)
        val name = runBlocking { prefs.displayName.first() }

        store = BlockingStore(localID = localId, localDisplayName = name)
        transport = WebSocketTransport(appScope)
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

    private fun defaultDisplayName(): String = android.os.Build.MODEL ?: "Android"
}
