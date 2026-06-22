package com.syncbridge.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import com.syncbridge.android.sync.SyncEventBus
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.flow.collectLatest
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.syncbridge.android.ui.components.DockBottomBar
import com.syncbridge.android.ui.components.LiquidBackground
import com.syncbridge.android.ui.screens.FilesScreen
import com.syncbridge.android.ui.screens.HomeScreen
import com.syncbridge.android.ui.screens.PinnedScreen
import com.syncbridge.android.ui.screens.SendScreen
import com.syncbridge.android.ui.screens.DevicesScreen
import com.syncbridge.android.ui.screens.SettingsScreen
import com.syncbridge.android.ui.theme.SyncTokens

enum class MainTab(val route: String, val label: String) {
    Clipboard("clipboard", "Clipboard"),
    Pinned("pinned", "Pinned"),
    Send("send", "Send"),
    Files("files", "Files"),
    Settings("settings", "Settings"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainShell(vm: AppViewModel = viewModel()) {
    val state by vm.state.collectAsState()
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route ?: MainTab.Clipboard.route
    val currentTab = MainTab.entries.firstOrNull { it.route == currentRoute } ?: MainTab.Clipboard
    val context = LocalContext.current
    var settingsSubpage by remember { mutableStateOf("main") }

    val app = context.applicationContext as com.syncbridge.android.SyncBridgeApp
    val net by app.networkManager.state.collectAsState()
    var showConnMenu by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        // Nearby peer toasts de-emphasized — clipboard sync is cloud relay.
    }

    LaunchedEffect(currentTab) {
        if (currentTab != MainTab.Settings) settingsSubpage = "main"
    }

    LaunchedEffect(state.isAuthenticated) {
        if (!state.isAuthenticated) return@LaunchedEffect
        val app = context.applicationContext as com.syncbridge.android.SyncBridgeApp
        app.pendingShareText?.let { vm.sendText(it); app.pendingShareText = null }
        app.pendingShareUris?.let { uris ->
            if (uris.size == 1) {
                vm.shareUri(uris.first())
            } else {
                vm.uploadUris(uris)
            }
            app.pendingShareUris = null
        }
    }

    Box(Modifier.fillMaxSize()) {
        LiquidBackground()
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                androidx.compose.material3.Surface(
                    color = com.syncbridge.android.ui.components.GlassColors.surface(),
                    shadowElevation = 4.dp,
                    tonalElevation = 0.dp,
                ) {
                    TopAppBar(
                        title = {
                            Text("SyncBridge", style = MaterialTheme.typography.titleLarge)
                        },
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = Color.Transparent,
                        ),
                    actions = {
                        Box {
                            Row(
                                modifier = Modifier
                                    .padding(end = 16.dp)
                                    .clip(RoundedCornerShape(SyncTokens.RadiusSm))
                                    .background(
                                        if (state.connected) SyncTokens.Teal.copy(0.12f)
                                        else MaterialTheme.colorScheme.errorContainer.copy(0.4f),
                                    )
                                    .clickable { showConnMenu = true }
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(
                                            if (state.connected) SyncTokens.Teal
                                            else MaterialTheme.colorScheme.error,
                                        ),
                                )
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    if (state.connected) "Connected" else "Offline",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = if (state.connected) SyncTokens.Teal else MaterialTheme.colorScheme.error,
                                )
                            }
                            DropdownMenu(expanded = showConnMenu, onDismissRequest = { showConnMenu = false }) {
                                DropdownMenuItem(
                                    text = { Text("Server: ${if (net.diagnostics != null) "Online" else "—"}") },
                                    onClick = { showConnMenu = false },
                                    enabled = false,
                                )
                                DropdownMenuItem(
                                    text = { Text("Peers: ${net.peers.size}") },
                                    onClick = { showConnMenu = false },
                                    enabled = false,
                                )
                                DropdownMenuItem(
                                    text = { Text("Transfer: ${net.currentTransferMode}") },
                                    onClick = { showConnMenu = false },
                                    enabled = false,
                                )
                                DropdownMenuItem(
                                    text = {
                                        Text("Latency: ${net.latencyMs?.let { "${it} ms" } ?: "—"}")
                                    },
                                    onClick = { showConnMenu = false },
                                    enabled = false,
                                )
                                DropdownMenuItem(
                                    text = {
                                        Text("Last sync: ${net.lastSyncAt?.let { relativeTime(it) } ?: "—"}")
                                    },
                                    onClick = { showConnMenu = false },
                                    enabled = false,
                                )
                            }
                        }
                    },
                    )
                }
            },
            bottomBar = {
                DockBottomBar(
                    current = currentTab,
                    onNavigate = { tab ->
                        nav.navigate(tab.route) {
                            launchSingleTop = true
                            popUpTo(MainTab.Clipboard.route) { saveState = true }
                            restoreState = true
                        }
                    },
                )
            },
        ) { padding ->
            MainNavHost(
                nav = nav,
                vm = vm,
                settingsSubpage = settingsSubpage,
                onSettingsSubpage = { settingsSubpage = it },
                modifier = Modifier.padding(padding),
            )
        }
    }
}

@Composable
private fun MainNavHost(
    nav: NavHostController,
    vm: AppViewModel,
    settingsSubpage: String,
    onSettingsSubpage: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by vm.state.collectAsState()
    val app = LocalContext.current.applicationContext as com.syncbridge.android.SyncBridgeApp

    NavHost(navController = nav, startDestination = MainTab.Clipboard.route, modifier = modifier) {
        composable(MainTab.Clipboard.route) {
            HomeScreen(
                history = state.clipboardHistory,
                files = state.files,
                onNavigate = { tab ->
                    nav.navigate(tab.route) {
                        launchSingleTop = true
                    }
                },
            )
        }
        composable(MainTab.Pinned.route) {
            PinnedScreen(entries = state.clipboardHistory, onUnpin = vm::togglePinClipboard)
        }
        composable(MainTab.Send.route) {
            SendScreen(
                uploads = state.uploads,
                onSendText = vm::sendText,
                onUploadUris = vm::uploadUris,
            )
        }
        composable(MainTab.Files.route) {
            FilesScreen(
                files = state.files,
                api = app.api,
                onTogglePin = vm::togglePinFile,
            )
        }
        composable(MainTab.Settings.route) {
            val app = LocalContext.current.applicationContext as com.syncbridge.android.SyncBridgeApp
            when (settingsSubpage) {
                "devices" -> DevicesScreen(api = app.api, onBack = { onSettingsSubpage("main") })
                else -> SettingsScreen(
                    connected = state.connected,
                    onLogout = vm::logout,
                    onOpenDevices = { onSettingsSubpage("devices") },
                )
            }
        }
    }
}
