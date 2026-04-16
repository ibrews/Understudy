package agilelens.understudy.teleprompter

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat

/**
 * Android SpeechRecognizer wrapper that feeds recognized text into
 * VoiceMatcher. Matches the Swift SpeechRecognitionDriver API so the
 * compose UI can call start/stop symmetrically.
 *
 * Uses continuous recognition by auto-restarting on onResults / onError
 * (same trick your Gemini-Live-ToDo teleprompter uses — stock Android
 * SpeechRecognizer is session-based, not continuous).
 */
class SpeechRecognitionDriver(private val context: Context) {

    var isRunning: Boolean = false
        private set
    var onHeard: ((String) -> Unit)? = null

    private var recognizer: SpeechRecognizer? = null
    private var intent: Intent? = null
    private var wantsRunning: Boolean = false

    fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun start() {
        if (isRunning) return
        if (!SpeechRecognizer.isRecognitionAvailable(context)) return
        if (!hasAudioPermission()) return

        val r = SpeechRecognizer.createSpeechRecognizer(context)
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                     RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
        }
        r.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                matches?.firstOrNull()?.let { onHeard?.invoke(it) }
                // Auto-restart for continuous listening.
                if (wantsRunning) r.startListening(i)
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                matches?.firstOrNull()?.let { onHeard?.invoke(it) }
            }
            override fun onError(error: Int) {
                if (wantsRunning) r.startListening(i)
            }

            // Required but unused.
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        recognizer = r
        intent = i
        wantsRunning = true
        isRunning = true
        r.startListening(i)
    }

    fun stop() {
        wantsRunning = false
        isRunning = false
        try {
            recognizer?.stopListening()
            recognizer?.destroy()
        } catch (_: Exception) { /* ignore */ }
        recognizer = null
        intent = null
    }
}
