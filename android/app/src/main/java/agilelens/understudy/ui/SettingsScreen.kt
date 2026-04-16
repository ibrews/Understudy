package agilelens.understudy.ui

import agilelens.understudy.BuildConfig
import agilelens.understudy.ui.theme.CurtainBlack
import agilelens.understudy.ui.theme.CurtainRed
import agilelens.understudy.ui.theme.WhiteDim
import agilelens.understudy.ui.theme.WhiteText
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val CurtainGradient = Brush.verticalGradient(colors = listOf(CurtainRed, CurtainBlack))

data class SettingsState(
    val displayName: String,
    val roomCode: String,
    val relayUrl: String
)

@Composable
fun SettingsScreen(
    initial: SettingsState,
    onSave: (SettingsState) -> Unit,
    onBack: () -> Unit
) {
    var displayName by remember { mutableStateOf(initial.displayName) }
    var roomCode by remember { mutableStateOf(initial.roomCode) }
    var relayUrl by remember { mutableStateOf(initial.relayUrl) }

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
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = {
                    onSave(SettingsState(displayName.trim(), roomCode.trim(), relayUrl.trim()))
                    onBack()
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = WhiteText)
                }
                Spacer(Modifier.height(8.dp))
                Text("Settings", color = WhiteText, fontSize = 22.sp)
            }
            Spacer(Modifier.height(12.dp))

            SectionTitle("Identity")
            Field(
                label = "Display name",
                value = displayName,
                onChange = { displayName = it },
                autocap = true
            )

            Spacer(Modifier.height(16.dp))
            SectionTitle("Room")
            Field(
                label = "Room code",
                value = roomCode,
                onChange = { roomCode = it },
                autocap = false
            )

            Spacer(Modifier.height(16.dp))
            SectionTitle("Transport")
            Text(
                text = "Android is WebSocket-only. Enter the host's LAN IP running /relay/server.py, e.g. ws://192.168.1.42:8765",
                color = WhiteDim,
                fontSize = 12.sp
            )
            Spacer(Modifier.height(8.dp))
            Field(
                label = "Relay URL",
                value = relayUrl,
                onChange = { relayUrl = it },
                keyboardType = KeyboardType.Uri,
                autocap = false
            )

            Spacer(Modifier.height(24.dp))
            SectionTitle("About")
            Text(
                text = "Version ${BuildConfig.APP_VERSION} (${BuildConfig.APP_BUILD})",
                color = WhiteText,
                fontSize = 14.sp
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text.uppercase(),
        color = WhiteDim,
        fontSize = 11.sp
    )
    Spacer(Modifier.height(6.dp))
}

@Composable
private fun Field(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    keyboardType: KeyboardType = KeyboardType.Text,
    autocap: Boolean = true
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label, color = WhiteDim) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = keyboardType,
            capitalization = if (autocap) KeyboardCapitalization.Words else KeyboardCapitalization.None
        ),
        colors = TextFieldDefaults.colors(
            focusedTextColor = WhiteText,
            unfocusedTextColor = WhiteText,
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            cursorColor = WhiteText,
            focusedIndicatorColor = WhiteText,
            unfocusedIndicatorColor = WhiteDim,
            focusedLabelColor = WhiteDim,
            unfocusedLabelColor = WhiteDim
        ),
        modifier = Modifier.fillMaxWidth()
    )
}
