package com.syncbridge.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.outlined.Devices
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Switch
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.syncbridge.android.sync.ClipboardSettings
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.SettingsLinkRow
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun SettingsScreen(
    connected: Boolean,
    clipboardSettings: ClipboardSettings,
    onLogout: () -> Unit,
    onOpenDevices: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space6),
    ) {
        Column(
            modifier = Modifier.padding(top = SyncTokens.Space4, bottom = SyncTokens.Space10 + SyncTokens.DockHeight),
            verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
        ) {
            AppSectionTitle("Devices")
            AppCard {
                SettingsLinkRow(
                    icon = Icons.Outlined.Devices,
                    title = "Trusted devices",
                    subtitle = "Pair, rename, trust, or remove devices",
                    onClick = onOpenDevices,
                )
            }

            AppSectionTitle("Clipboard")
            AppCard {
                var autoSync by remember { mutableStateOf(clipboardSettings.autoSyncClipboard) }
                var autoApply by remember { mutableStateOf(clipboardSettings.autoApplyRemoteClipboard) }
                var autoImages by remember { mutableStateOf(clipboardSettings.autoSyncImages) }
                var showNotifications by remember { mutableStateOf(clipboardSettings.showClipboardNotifications) }

                ClipboardSettingToggle(
                    title = "Auto sync clipboard",
                    subtitle = "Upload copies from this device automatically",
                    checked = autoSync,
                    onCheckedChange = {
                        autoSync = it
                        clipboardSettings.autoSyncClipboard = it
                    },
                )
                ClipboardSettingToggle(
                    title = "Auto apply remote clipboard",
                    subtitle = "Paste synced content without opening SyncBridge",
                    checked = autoApply,
                    onCheckedChange = {
                        autoApply = it
                        clipboardSettings.autoApplyRemoteClipboard = it
                    },
                )
                ClipboardSettingToggle(
                    title = "Auto sync images",
                    subtitle = "Include photos, screenshots, and copied images",
                    checked = autoImages,
                    onCheckedChange = {
                        autoImages = it
                        clipboardSettings.autoSyncImages = it
                    },
                )
                ClipboardSettingToggle(
                    title = "Show clipboard notifications",
                    subtitle = "Notify when clipboard updates from another device",
                    checked = showNotifications,
                    onCheckedChange = {
                        showNotifications = it
                        clipboardSettings.showClipboardNotifications = it
                    },
                )
            }

            AppSectionTitle("Connection")
            AppCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (connected) SyncTokens.Success else SyncTokens.SlateMuted),
                    )
                    Text(
                        if (connected) "Live sync — instant clipboard push" else "Reconnecting live sync…",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            AppSectionTitle("About")
            AppCard {
                Text("SyncBridge", fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text(
                    "Instant clipboard sync across your devices.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = SyncTokens.Space2),
                )
                Text(
                    "Version ${com.syncbridge.android.BuildConfig.VERSION_NAME}",
                    style = MaterialTheme.typography.labelMedium,
                    color = SyncTokens.SlateMuted,
                    modifier = Modifier.padding(top = SyncTokens.Space3),
                )
            }

            AppSectionTitle("Account")
            AppCard {
                Button(
                    onClick = onLogout,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(SyncTokens.RadiusMd),
                ) {
                    Icon(
                        Icons.AutoMirrored.Outlined.Logout,
                        contentDescription = null,
                        modifier = Modifier.padding(end = SyncTokens.Space2),
                    )
                    Text("Log out")
                }
            }
        }
    }
}

@Composable
private fun ClipboardSettingToggle(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = SyncTokens.Space2),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyLarge)
            Text(
                subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
