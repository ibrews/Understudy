package agilelens.understudy.net

import agilelens.understudy.model.Id
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import kotlin.math.min

/**
 * WebSocket transport matching the iOS `Transport` protocol.
 *
 * URL format:
 *   ws://<host>:<port>/?room=<code>&id=<uuid>&name=<label>
 *
 * Auto-reconnect with exponential backoff (1s → 15s cap).
 */
class WebSocketTransport(
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
) {
    private val tag = "UnderstudyWS"

    enum class Status { Disconnected, Connecting, Connected }

    private val _status = MutableStateFlow(Status.Disconnected)
    val status: StateFlow<Status> = _status.asStateFlow()

    private val _peerCount = MutableStateFlow(0)
    val peerCount: StateFlow<Int> = _peerCount.asStateFlow()

    private val _incoming = MutableSharedFlow<Envelope>(
        replay = 0, extraBufferCapacity = 64
    )
    val incoming: SharedFlow<Envelope> = _incoming.asSharedFlow()

    private val client: OkHttpClient = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)  // no read timeout for WS
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    private var ws: WebSocket? = null
    private var reconnectJob: Job? = null
    private var shouldReconnect: Boolean = false
    private var backoffSec: Long = 1
    private var currentUrl: String? = null

    fun start(relayUrl: String, roomCode: String, localID: Id, displayName: String) {
        val url = buildUrl(relayUrl, roomCode, localID.raw, displayName)
        currentUrl = url
        shouldReconnect = true
        backoffSec = 1
        openSocket(url)
    }

    fun stop() {
        shouldReconnect = false
        reconnectJob?.cancel()
        reconnectJob = null
        try {
            ws?.close(1000, "client stop")
        } catch (_: Throwable) {}
        ws = null
        _status.value = Status.Disconnected
    }

    fun send(message: NetMessage, senderID: Id): Boolean {
        val env = Envelope(senderID = senderID, message = message)
        val text = try {
            Wire.encodeToString(Envelope.serializer(), env)
        } catch (t: Throwable) {
            Log.w(tag, "encode failed: $t")
            return false
        }
        val sock = ws ?: return false
        return sock.send(text)
    }

    fun dispose() {
        stop()
        scope.cancel()
    }

    // --- internals ---

    private fun openSocket(url: String) {
        _status.value = Status.Connecting
        val req = Request.Builder().url(url).build()
        ws = client.newWebSocket(req, Listener())
    }

    private fun scheduleReconnect() {
        if (!shouldReconnect) return
        reconnectJob?.cancel()
        val delay = backoffSec
        backoffSec = min(15, backoffSec * 2)
        Log.i(tag, "reconnect in ${delay}s")
        reconnectJob = scope.launch {
            delay(delay * 1000L)
            val url = currentUrl
            if (shouldReconnect && url != null) openSocket(url)
        }
    }

    private fun buildUrl(base: String, room: String, id: String, name: String): String {
        val sep = if (base.contains('?')) "&" else "?"
        return base.trimEnd('/') +
            sep +
            "room=${enc(room)}&id=${enc(id)}&name=${enc(name)}"
    }

    private fun enc(s: String): String = URLEncoder.encode(s, "UTF-8")

    private inner class Listener : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            Log.i(tag, "connected")
            _status.value = Status.Connected
            backoffSec = 1
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            // Relay welcome? {"_relay":"welcome","room":"..","peers":N}
            try {
                val el = Json.parseToJsonElement(text)
                if (el is JsonObject) {
                    val relayKind = el["_relay"]?.jsonPrimitive?.content
                    if (relayKind != null) {
                        val peers = el["peers"]?.jsonPrimitive?.int ?: 0
                        _peerCount.value = peers
                        return
                    }
                }
            } catch (_: Throwable) { /* fall through to envelope */ }

            // Normal envelope
            try {
                val env = Wire.decodeFromString(Envelope.serializer(), text)
                if (env.version != Envelope.CURRENT_VERSION) {
                    Log.w(tag, "drop envelope version=${env.version}")
                    return
                }
                _incoming.tryEmit(env)
            } catch (t: Throwable) {
                Log.w(tag, "bad envelope: ${t.message}")
            }
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            webSocket.close(1000, null)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            Log.i(tag, "closed code=$code reason=$reason")
            _status.value = Status.Disconnected
            ws = null
            if (shouldReconnect) scheduleReconnect()
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            Log.w(tag, "failure: ${t.message}")
            _status.value = Status.Disconnected
            ws = null
            if (shouldReconnect) scheduleReconnect()
        }
    }
}
