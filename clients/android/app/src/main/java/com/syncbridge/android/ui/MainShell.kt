package com.syncbridge.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
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
import com.syncbridge.android.ui.screens.FilesScreen
import com.syncbridge.android.ui.screens.HomeScreen
import com.syncbridge.android.ui.screens.PinnedScreen
import com.syncbridge.android.ui.screens.SendScreen
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

    LaunchedEffect(state.isAuthenticated) {
        if (!state.isAuthenticated) return@LaunchedEffect
        val app = context.applicationContext as com.syncbridge.android.SyncBridgeApp
        app.pendingShareText?.let { vm.sendText(it); app.pendingShareText = null }
        app.pendingShareUris?.let { vm.uploadUris(it); app.pendingShareUris = null }
    }

    Box(
        modifier = Modifier.background(
            Brush.verticalGradient(
                listOf(
                    SyncTokens.Teal.copy(0.04f),
                    MaterialTheme.colorScheme.background,
                ),
            ),
        ),
    ) {
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = {
                        Text("SyncBridge", style = MaterialTheme.typography.titleLarge)
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
                    ),
                    actions = {
                        if (state.connected) {
                            Box(
                                modifier = Modifier
                                    .padding(end = 16.dp)
                                    .clip(RoundedCornerShape(SyncTokens.RadiusSm))
                                    .background(SyncTokens.Teal.copy(0.12f))
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                            ) {
                                Text(
                                    "Live",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = SyncTokens.Teal,
                                )
                            }
                        }
                    },
                )
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
            MainNavHost(nav = nav, vm = vm, modifier = Modifier.padding(padding))
        }
    }
}

@Composable
private fun MainNavHost(nav: NavHostController, vm: AppViewModel, modifier: Modifier = Modifier) {
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
            SettingsScreen(
                connected = state.connected,
                onLogout = vm::logout,
            )
        }
    }
}
