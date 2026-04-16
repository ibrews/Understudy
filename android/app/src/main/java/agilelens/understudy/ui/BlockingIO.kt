package agilelens.understudy.ui

import agilelens.understudy.model.Blocking
import agilelens.understudy.net.Wire
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Pretty-print a Blocking to JSON using the wire-compatible serializer.
 */
private val PrettyWire = Json(from = Wire) { prettyPrint = true }

fun Blocking.toPrettyJson(): String =
    PrettyWire.encodeToString(Blocking.serializer(), this)

fun parseBlockingJson(text: String): Blocking? = try {
    Wire.decodeFromString(Blocking.serializer(), text)
} catch (_: Throwable) {
    null
}

/**
 * Write the JSON to a file under cacheDir/exports and return a FileProvider URI
 * that can be passed to an ACTION_SEND intent.
 */
fun writeBlockingToShareableFile(context: Context, blocking: Blocking): Uri {
    val dir = File(context.cacheDir, "exports").apply { mkdirs() }
    val safeTitle = blocking.title
        .replace(Regex("[^A-Za-z0-9_\\-]"), "_")
        .ifBlank { "blocking" }
    val file = File(dir, "$safeTitle.json")
    file.writeText(blocking.toPrettyJson())
    val authority = "${context.packageName}.fileprovider"
    return FileProvider.getUriForFile(context, authority, file)
}

fun buildShareIntent(uri: Uri, title: String): Intent {
    return Intent(Intent.ACTION_SEND).apply {
        type = "application/json"
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_SUBJECT, title)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
}

/** Read the full text of a content:// URI returned by ACTION_OPEN_DOCUMENT. */
fun readTextFromUri(context: Context, uri: Uri): String? = try {
    context.contentResolver.openInputStream(uri)?.use { it.bufferedReader().readText() }
} catch (_: Throwable) {
    null
}
