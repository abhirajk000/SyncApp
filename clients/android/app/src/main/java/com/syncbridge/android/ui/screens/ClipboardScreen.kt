package com.syncbridge.android.ui.screens

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.data.DeviceEntry
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSurfaces
import com.syncbridge.android.ui.components.ChipVariant
import com.syncbridge.android.ui.components.ClipboardCard
import androidx.compose.material3.HorizontalDivider
import com.syncbridge.android.ui.components.ContainerGroup
import com.syncbridge.android.ui.components.ClipboardImageThumb
import com.syncbridge.android.ui.components.EmptyArt
import com.syncbridge.android.ui.components.PremiumBottomSheet
import com.syncbridge.android.ui.components.PremiumChip
import com.syncbridge.android.ui.components.PrimaryButton
import com.syncbridge.android.ui.components.SearchField
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.clipboardDisplayText
import com.syncbridge.android.util.copyEntryToClipboard
import com.syncbridge.android.util.isImageContentType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

private enum class ClipboardFilter(val label: String) {
    All("All"), Text("Text"), Images("Images")
}

private data class DayGroup(val label: String, val items: List<ClipboardEntry>)

@Composable
fun ClipboardScreen(
    history: List<ClipboardEntry>,
    api: ApiClient,
    devices: List<DeviceEntry> = emptyList(),
    peerDeviceIds: Set<String> = emptySet(),
    onTogglePin: (ClipboardEntry) -> Unit,
    onDelete: (ClipboardEntry) -> Unit,
    insertingEntryId: String? = null,
    embedded: Boolean = false,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var search by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf(ClipboardFilter.All) }
    var copiedId by remember { mutableStateOf<String?>(null) }
    var preview by remember { mutableStateOf<ClipboardEntry?>(null) }

    LaunchedEffect(copiedId) {
        if (copiedId != null) {
            delay(850)
            copiedId = null
        }
    }

    fun copyEntry(entry: ClipboardEntry) {
        scope.launch {
            runCatching { copyEntryToClipboard(context, api, entry) }
                .onSuccess {
                    copiedId = entry.id
                    val msg = if (isImageContentType(entry.contentType)) "Image copied" else "Copied"
                    Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                }
                .onFailure { Toast.makeText(context, "Could not copy", Toast.LENGTH_SHORT).show() }
        }
    }

    val deviceNames = remember(devices) { devices.associate { it.id to it.name } }

    val sorted = remember(history) {
        history.sortedByDescending { parseInstant(it.createdAt) }
    }

    val filtered = remember(sorted, search, filter) {
        sorted.filter { entry ->
            matchesFilter(entry, filter) && matchesSearch(entry, search)
        }
    }

    val groups = remember(filtered) { groupByDay(filtered) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = SyncTokens.Space4),
    ) {
        Column(
            modifier = Modifier.padding(
                top = if (embedded) SyncTokens.Space2 else SyncTokens.Space4,
                bottom = SyncTokens.Space3,
            ),
            verticalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
        ) {
            SearchField(
                value = search,
                onValueChange = { search = it },
                placeholder = "Search clipboard…",
            )
            Row(
                horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
                modifier = Modifier.fillMaxWidth(),
            ) {
                ClipboardFilter.entries.forEach { item ->
                    Box(modifier = Modifier.clickable { filter = item }) {
                        PremiumChip(
                            label = item.label,
                            variant = if (filter == item) ChipVariant.Primary else ChipVariant.Neutral,
                        )
                    }
                }
            }
        }

        if (filtered.isEmpty()) {
            AppEmptyState(
                title = if (search.isNotBlank()) "No matches" else "No clipboard items",
                description = if (search.isNotBlank()) {
                    "Try a different search or filter."
                } else {
                    "Copy text or an image on any device — it appears here instantly."
                },
                illustration = EmptyArt.Clipboard,
            )
        } else {
            LazyColumn(
                contentPadding = PaddingValues(bottom = SyncTokens.DockScrollPadding),
                verticalArrangement = Arrangement.spacedBy(SyncTokens.Space6),
            ) {
                groups.forEach { group ->
                    item(key = "hdr-${group.label}") {
                        Text(
                            group.label.uppercase(),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 1.2.sp,
                            color = SyncTokens.SlateMuted,
                            modifier = Modifier.padding(bottom = SyncTokens.Space2),
                        )
                    }
                    item(key = "grp-${group.label}") {
                        ContainerGroup {
                            group.items.forEachIndexed { index, entry ->
                                val isInserting = entry.id == insertingEntryId
                                AnimatedVisibility(
                                    visible = true,
                                    enter = if (isInserting) {
                                        fadeIn(tween(450)) + slideInVertically(tween(450)) { -it / 3 }
                                    } else {
                                        fadeIn()
                                    },
                                ) {
                                    ClipboardCard(
                                        entry = entry,
                                        api = api,
                                        deviceName = deviceNames[entry.sourceDeviceId],
                                        transferMode = clipboardTransferMode(entry, peerDeviceIds),
                                        copied = copiedId == entry.id,
                                        embeddedInGroup = true,
                                        onCopy = { copyEntry(entry) },
                                        onDelete = { onDelete(entry) },
                                        onPin = { onTogglePin(entry) },
                                        onPreview = { preview = entry },
                                    )
                                }
                                if (index < group.items.lastIndex) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(horizontal = SyncTokens.Space5),
                                        color = AppSurfaces.cardStroke(),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PremiumBottomSheet(
        visible = preview != null,
        title = "Preview",
        onDismiss = { preview = null },
    ) {
        val entry = preview ?: return@PremiumBottomSheet
        if (isImageContentType(entry.contentType)) {
            ClipboardImageThumb(
                entry = entry,
                api = api,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(280.dp)
                    .clip(RoundedCornerShape(SyncTokens.RadiusLg)),
                contentDescription = "Clipboard preview",
            )
        } else {
            Text(
                clipboardDisplayText(entry.content, 4000),
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(320.dp),
            )
        }
        PrimaryButton(
            text = if (isImageContentType(entry.contentType)) "Copy image" else "Copy",
            onClick = {
                copyEntry(entry)
                preview = null
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = SyncTokens.Space4),
        )
    }
}

private fun clipboardTransferMode(entry: ClipboardEntry, peerDeviceIds: Set<String>): String =
    if (peerDeviceIds.contains(entry.sourceDeviceId)) "direct_lan" else "relay"

private fun matchesFilter(entry: ClipboardEntry, filter: ClipboardFilter): Boolean = when (filter) {
    ClipboardFilter.All -> true
    ClipboardFilter.Images -> isImageContentType(entry.contentType)
    ClipboardFilter.Text -> !isImageContentType(entry.contentType)
}

private fun matchesSearch(entry: ClipboardEntry, query: String): Boolean {
    val q = query.trim().lowercase()
    if (q.isEmpty()) return true
    if (isImageContentType(entry.contentType)) return "image".contains(q)
    return entry.content.lowercase().contains(q)
}

private fun parseInstant(iso: String): Instant =
    runCatching { Instant.parse(iso) }.getOrDefault(Instant.EPOCH)

private fun groupByDay(entries: List<ClipboardEntry>): List<DayGroup> {
    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val linked = linkedMapOf<String, MutableList<ClipboardEntry>>()
    for (entry in entries) {
        val date = parseInstant(entry.createdAt).atZone(zone).toLocalDate()
        val label = when {
            date == today -> "Today"
            date == today.minusDays(1) -> "Yesterday"
            today.toEpochDay() - date.toEpochDay() < 7 ->
                date.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
            else -> "${date.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())} ${date.dayOfMonth}, ${date.year}"
        }
        linked.getOrPut(label) { mutableListOf() }.add(entry)
    }
    return linked.map { DayGroup(it.key, it.value) }
}
