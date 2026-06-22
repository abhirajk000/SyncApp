package com.syncbridge.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.DeviceEntry
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.launch
import java.time.Instant

@Composable
fun DevicesScreen(
    api: ApiClient,
    onBack: () -> Unit,
) {
    var devices by remember { mutableStateOf<List<DeviceEntry>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var renameTarget by remember { mutableStateOf<DeviceEntry?>(null) }
    var renameValue by remember { mutableStateOf("") }
    var saving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    fun reload() {
        scope.launch {
            loading = true
            try {
                devices = api.fetchDevices()
            } catch (_: Exception) {
            } finally {
                loading = false
            }
        }
    }

    LaunchedEffect(Unit) { reload() }

    val current = devices.find { it.isCurrent }
    val others = devices.filter { !it.isCurrent }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
            Text("Devices", style = MaterialTheme.typography.titleLarge)
        }

        if (loading) {
            CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
        }

        current?.let { device ->
            AppSectionTitle("This device")
            DeviceCard(
                device = device,
                onRename = {
                    renameTarget = device
                    renameValue = device.name
                },
            )
        }

        AppSectionTitle("Trusted devices")
        if (others.isEmpty()) {
            AppCard {
                Text(
                    "No other devices yet. Pair from your Mac or web settings.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else {
            others.forEach { device ->
                DeviceCard(
                    device = device,
                    onRename = {
                        renameTarget = device
                        renameValue = device.name
                    },
                    onTrust = if (!isTrusted(device)) {{ scope.launch { api.trustDevice(device.id); reload() } }} else null,
                    onRemove = { scope.launch { api.revokeDevice(device.id); reload() } },
                )
            }
        }
    }

    if (renameTarget != null) {
        AlertDialog(
            onDismissRequest = { renameTarget = null },
            title = { Text("Rename device") },
            text = {
                OutlinedTextField(
                    value = renameValue,
                    onValueChange = { renameValue = it },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val target = renameTarget ?: return@TextButton
                        saving = true
                        scope.launch {
                            try {
                                api.renameDevice(target.id, renameValue.trim())
                                renameTarget = null
                                reload()
                            } catch (_: Exception) {
                            } finally {
                                saving = false
                            }
                        }
                    },
                    enabled = !saving && renameValue.isNotBlank(),
                ) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { renameTarget = null }) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun DeviceCard(
    device: DeviceEntry,
    onRename: () -> Unit,
    onTrust: (() -> Unit)? = null,
    onRemove: (() -> Unit)? = null,
) {
    AppCard {
        Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space3)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(if (device.online) SyncTokens.Teal else Color.Gray),
                )
                Text(device.name, fontWeight = FontWeight.SemiBold)
            }
            Text(
                "${platformLabel(device.platform)}${if (device.isCurrent) " · This device" else ""}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                device.lastSeenAt?.let { relativeTime(it) } ?: "Never seen",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                OutlinedButton(onClick = onRename) { Text("Rename") }
                onTrust?.let { OutlinedButton(onClick = it) { Text("Trust") } }
                onRemove?.let { OutlinedButton(onClick = it) { Text("Remove") } }
            }
        }
    }
}

private fun isTrusted(device: DeviceEntry): Boolean {
    val until = device.trustedUntil ?: return false
    return try {
        Instant.parse(until).isAfter(Instant.now())
    } catch (_: Exception) {
        false
    }
}

private fun platformLabel(platform: String): String = when (platform) {
    "macos" -> "macOS"
    "android" -> "Android"
    "ios" -> "iOS"
    "web" -> "Web"
    else -> platform.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
}
