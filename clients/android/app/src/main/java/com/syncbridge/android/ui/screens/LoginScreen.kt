package com.syncbridge.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.components.AppBackground
import com.syncbridge.android.ui.components.LoginHero
import com.syncbridge.android.ui.components.LoginPinField
import com.syncbridge.android.ui.components.PrimaryButton
import com.syncbridge.android.ui.components.SurfaceCard
import com.syncbridge.android.ui.theme.SyncTokens

/** Web LoginPage parity — centered glass card, hero + PIN + Unlock only. */
@Composable
fun LoginScreen(
    loading: Boolean,
    error: String?,
    onUnlock: (String) -> Unit,
) {
    var pin by remember { mutableStateOf("") }

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
                    .shadow(24.dp, RoundedCornerShape(SyncTokens.RadiusLg), clip = false),
                shape = RoundedCornerShape(SyncTokens.RadiusLg),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = SyncTokens.Space6, vertical = SyncTokens.Space8),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(SyncTokens.Space5),
                ) {
                    LoginHero(modifier = Modifier.padding(bottom = SyncTokens.Space3))
                    LoginPinField(
                        value = pin,
                        onValueChange = { pin = it },
                        error = error,
                    )
                    PrimaryButton(
                        text = if (loading) "Unlocking…" else "Unlock",
                        onClick = { onUnlock(pin) },
                        enabled = pin.isNotBlank(),
                        loading = loading,
                    )
                }
            }
        }
    }
}
