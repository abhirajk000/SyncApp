package com.syncbridge.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Devices
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun SettingsScreen(
    connected: Boolean,
    onLogout: () -> Unit,
    onOpenDevices: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        AppSectionTitle("Devices")
        AppCard {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onOpenDevices),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
            ) {
                Icon(Icons.Outlined.Devices, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                Column(Modifier.weight(1f)) {
                    Text("Trusted devices", fontWeight = FontWeight.SemiBold)
                    Text(
                        "Pair, rename, trust, or remove devices",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
            }
        }

        AppSectionTitle("Connection")
        AppCard {
            Text(
                if (connected) "Connected — clipboard sync active" else "Offline — reconnecting…",
                color = if (connected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        AppSectionTitle("Account")
        AppCard {
            OutlinedButton(onClick = onLogout, modifier = Modifier.fillMaxWidth()) {
                Text("Sign out", color = MaterialTheme.colorScheme.error)
            }
        }

        AppSectionTitle("About")
        AppCard {
            Text(
                "SyncBridge — universal clipboard and file sharing across your devices.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
