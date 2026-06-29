package com.syncbridge.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.components.AppBackground
import com.syncbridge.android.ui.components.GhostButton
import com.syncbridge.android.ui.components.LoginHero
import com.syncbridge.android.ui.components.PrimaryButton
import com.syncbridge.android.ui.components.SurfaceCard
import com.syncbridge.android.ui.theme.SyncTokens

/** Native connect — no PIN UI (web-only). */
@Composable
fun ConnectingScreen(
    loading: Boolean,
    error: String?,
    onConnect: () -> Unit,
) {
    Box(Modifier.fillMaxSize()) {
        AppBackground()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(SyncTokens.Space6),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            SurfaceCard(
                modifier = Modifier
                    .widthIn(max = 400.dp)
                    .fillMaxWidth()
                    .shadow(24.dp, RoundedCornerShape(SyncTokens.RadiusCard), clip = false),
                shape = RoundedCornerShape(SyncTokens.RadiusCard),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = SyncTokens.Space6, vertical = SyncTokens.Space8),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(SyncTokens.Space5),
                ) {
                    LoginHero(modifier = Modifier.padding(bottom = SyncTokens.Space3))
                    if (loading) {
                        CircularProgressIndicator(color = SyncTokens.Teal)
                        Text(
                            "Connecting to sync.abhiraj.xyz…",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else if (error != null) {
                        Text(
                            error,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error,
                        )
                        PrimaryButton(text = "Retry", onClick = onConnect)
                    } else {
                        GhostButton(text = "Connect", onClick = onConnect)
                    }
                }
            }
        }
    }
}
