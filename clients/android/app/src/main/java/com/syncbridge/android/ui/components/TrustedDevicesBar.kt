package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Computer
import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.PhoneIphone
import androidx.compose.material.icons.outlined.Web
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.DeviceEntry
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun TrustedDevicesBar(
    api: ApiClient,
    peerDeviceIds: Set<String> = emptySet(),
    modifier: Modifier = Modifier,
) {
    var devices by remember { mutableStateOf<List<DeviceEntry>>(emptyList()) }

    LaunchedEffect(Unit) {
        runCatching { api.fetchDevices() }
            .onSuccess { list -> devices = list.filter { !it.isCurrent } }
    }

    val visible = devices.map { d ->
        d.copy(online = d.online || peerDeviceIds.contains(d.id))
    }
    if (visible.isEmpty()) return

    AppCard(modifier = modifier) {
        AppSectionTitle("Online devices")
        LazyRow(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
            items(visible, key = { it.id }) { device ->
                DevicePill(device)
            }
        }
    }
}

@Composable
private fun DevicePill(device: DeviceEntry) {
    Surface(
        shape = RoundedCornerShape(999.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        border = androidx.compose.foundation.BorderStroke(1.dp, AppSurfaces.cardBorder()),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = SyncTokens.Space4, vertical = SyncTokens.Space2),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(
                        if (device.online) SyncTokens.Success
                        else SyncTokens.SlateMuted.copy(0.5f),
                    ),
            )
            Icon(
                platformIcon(device.platform),
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = SyncTokens.SlateSecondary,
            )
            Text(
                device.name,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

private fun platformIcon(platform: String): ImageVector = when (platform) {
    "macos" -> Icons.Outlined.Computer
    "ios" -> Icons.Outlined.PhoneIphone
    "web" -> Icons.Outlined.Web
    else -> Icons.Outlined.PhoneAndroid
}
