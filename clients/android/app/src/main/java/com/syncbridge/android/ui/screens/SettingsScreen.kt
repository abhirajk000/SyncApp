package com.syncbridge.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun SettingsScreen(
    serverUrl: String,
    connected: Boolean,
    onServerUrlChange: (String) -> Unit,
    onSaveServer: () -> Unit,
    onLogout: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        AppSectionTitle("Server")
        AppCard {
            OutlinedTextField(
                value = serverUrl,
                onValueChange = onServerUrlChange,
                label = { Text("API URL") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            Spacer(Modifier.height(SyncTokens.Space3))
            Button(onClick = onSaveServer, modifier = Modifier.fillMaxWidth()) { Text("Save") }
        }

        AppSectionTitle("Connection")
        AppCard {
            Text(
                if (connected) "Connected — WebSocket live" else "Offline — reconnecting…",
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
                "SyncBridge — instant clipboard sync across your devices.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
