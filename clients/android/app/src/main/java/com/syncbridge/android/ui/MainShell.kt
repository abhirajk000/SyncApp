package com.syncbridge.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.rememberNavController
import com.syncbridge.android.ui.components.AppShell
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import com.syncbridge.android.ui.components.PremiumIconButton
import com.syncbridge.android.ui.components.LatestClipboardDialog
import com.syncbridge.android.ui.screens.ClipboardScreen
import com.syncbridge.android.ui.screens.DevicesScreen
import com.syncbridge.android.ui.screens.FilesScreen
import com.syncbridge.android.ui.screens.LocalSendScreen
import com.syncbridge.android.ui.screens.PinnedScreen
import com.syncbridge.android.ui.components.SegmentedTabs
import com.syncbridge.android.ui.screens.SendScreen
import com.syncbridge.android.ui.screens.SettingsScreen
import com.syncbridge.android.ui.theme.SyncTokens

enum class MainTab(val route: String, val label: String) {
    CloudSend("cloud_send", "Cloud Send"),
    LocalSend("local_send", "Local Send"),
    Clipboard("clipboard", "Clipboard"),
    Files("files", "Files"),
    Settings("settings", "Settings"),
}

private enum class ClipboardSection { History, Pinned }

@Composable
fun MainShell(vm: AppViewModel = viewModel()) {
    val state by vm.state.collectAsState()
    rememberNavController() // kept for deep-link parity
    val context = LocalContext.current
    var currentTab by remember { mutableStateOf(MainTab.Clipboard) }
    var settingsSubpage by remember { mutableStateOf("main") }
    var clipboardSection by remember { mutableStateOf(ClipboardSection.History) }
    var insertingClipboardId by remember { mutableStateOf<String?>(null) }
    var lastSeenHeadId by remember { mutableStateOf<String?>(null) }

    val app = context.applicationContext as com.syncbridge.android.SyncBridgeApp
    val net by app.networkManager.state.collectAsState()
    val peerIds = remember(net.peers) { net.peers.map { it.deviceId }.toSet() }

    LaunchedEffect(currentTab) {
        if (currentTab != MainTab.Settings) settingsSubpage = "main"
    }

    LaunchedEffect(state.isAuthenticated) {
        if (!state.isAuthenticated) return@LaunchedEffect
        app.pendingShareText?.let { vm.sendText(it); app.pendingShareText = null }
        app.pendingShareUris?.let { uris ->
            if (uris.size == 1) vm.shareUri(uris.first()) else vm.uploadUris(uris)
            app.pendingShareUris = null
        }
    }

    val latestEntryId = state.clipboardHistory.firstOrNull()?.id
    LaunchedEffect(latestEntryId) {
        if (latestEntryId != null && latestEntryId != lastSeenHeadId && lastSeenHeadId != null) {
            insertingClipboardId = latestEntryId
            kotlinx.coroutines.delay(600)
            insertingClipboardId = null
        }
        lastSeenHeadId = latestEntryId
    }

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, state.isAuthenticated) {
        if (!state.isAuthenticated) return@DisposableEffect onDispose { }
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> {
                    vm.resetClipboardPopupSession()
                    vm.presentLatestClipboardPopupIfNeeded()
                }
                Lifecycle.Event.ON_RESUME -> vm.onAppResumed()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    state.latestClipboardPopup?.let { popup ->
        LatestClipboardDialog(
            entry = popup,
            api = app.api,
            onDismiss = vm::dismissLatestClipboardPopup,
        )
    }

    AppShell(
        currentTab = currentTab,
        connected = state.connected,
        refreshing = state.isRefreshing,
        onRefresh = vm::refreshHome,
        network = net,
        onNavigate = { currentTab = it },
    ) { tab ->
        when (tab) {
            MainTab.Clipboard -> Column(Modifier.fillMaxSize()) {
                SegmentedTabs(
                    options = listOf("Clipboard", "Pinned"),
                    selectedIndex = if (clipboardSection == ClipboardSection.History) 0 else 1,
                    onSelect = { clipboardSection = if (it == 0) ClipboardSection.History else ClipboardSection.Pinned },
                    modifier = Modifier.padding(
                        start = SyncTokens.Space4,
                        end = SyncTokens.Space4,
                        top = SyncTokens.Space4,
                    ),
                )
                when (clipboardSection) {
                    ClipboardSection.History -> ClipboardScreen(
                        history = state.clipboardHistory,
                        api = app.api,
                        devices = net.devices,
                        peerDeviceIds = peerIds,
                        onTogglePin = vm::togglePinClipboard,
                        onDelete = vm::deleteClipboard,
                        insertingEntryId = insertingClipboardId,
                        embedded = true,
                    )
                    ClipboardSection.Pinned -> PinnedScreen(
                        entries = state.clipboardHistory,
                        api = app.api,
                        peerDeviceIds = peerIds,
                        onUnpin = vm::togglePinClipboard,
                        onDelete = vm::deleteClipboard,
                        embedded = true,
                    )
                }
            }
            MainTab.CloudSend -> SendScreen(
                uploads = state.uploads,
                onSendText = vm::sendText,
                onUploadUris = vm::uploadUris,
            )
            MainTab.LocalSend -> LocalSendScreen(
                manager = app.localSendManager,
                onBack = null,
            )
            MainTab.Files -> {
                LaunchedEffect(Unit) { vm.refreshFiles() }
                FilesScreen(
                    files = state.files,
                    api = app.api,
                    onTogglePin = vm::togglePinFile,
                    onDelete = vm::deleteFile,
                )
            }
            MainTab.Settings -> when (settingsSubpage) {
                "devices" -> DevicesScreen(api = app.api, onBack = { settingsSubpage = "main" })
                else -> SettingsScreen(
                    connected = state.connected,
                    clipboardSettings = app.clipboardSettings,
                    onLogout = vm::logout,
                    onOpenDevices = { settingsSubpage = "devices" },
                )
            }
        }
    }
}
