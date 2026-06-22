package com.syncbridge.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
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
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.screens.ClipboardScreen
import com.syncbridge.android.ui.screens.FilesScreen
import com.syncbridge.android.ui.screens.PinnedScreen
import com.syncbridge.android.ui.screens.SettingsScreen
import com.syncbridge.android.ui.theme.SyncTokens

enum class MainTab(val route: String, val label: String) {
    Clipboard("clipboard", "Clipboard"),
    Pinned("pinned", "Pinned"),
    Files("files", "Files"),
    Images("images", "Images"),
    Settings("settings", "Settings"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainShell(vm: AppViewModel = viewModel()) {
    val state by vm.state.collectAsState()
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val current = backStack?.destination?.route ?: MainTab.Clipboard.route
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
                        Text(
                            "SyncBridge",
                            style = MaterialTheme.typography.titleLarge,
                        )
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
                NavigationBar(
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
                    tonalElevation = 0.dp,
                ) {
                    MainTab.entries.forEach { tab ->
                        NavigationBarItem(
                            selected = current == tab.route,
                            onClick = { nav.navigate(tab.route) { launchSingleTop = true } },
                            icon = {
                                Icon(
                                    when (tab) {
                                        MainTab.Clipboard -> Icons.Outlined.ContentPaste
                                        MainTab.Pinned -> Icons.Outlined.PushPin
                                        MainTab.Files -> Icons.Outlined.InsertDriveFile
                                        MainTab.Images -> Icons.Outlined.Image
                                        MainTab.Settings -> Icons.Outlined.Settings
                                    },
                                    contentDescription = tab.label,
                                )
                            },
                            label = { Text(tab.label) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = SyncTokens.Teal,
                                selectedTextColor = SyncTokens.Teal,
                                indicatorColor = SyncTokens.Teal.copy(0.12f),
                            ),
                        )
                    }
                }
            },
        ) { padding ->
            MainNavHost(nav = nav, vm = vm, modifier = Modifier.padding(padding))
        }
    }
}

@Composable
private fun MainNavHost(nav: NavHostController, vm: AppViewModel, modifier: Modifier = Modifier) {
    val state by vm.state.collectAsState()

    NavHost(navController = nav, startDestination = MainTab.Clipboard.route, modifier = modifier) {
        composable(MainTab.Clipboard.route) {
            ClipboardScreen(
                latest = state.latestClipboard,
                history = state.clipboardHistory,
                uploads = state.uploads,
                onSendText = vm::sendText,
                onUploadUris = vm::uploadUris,
                onPin = vm::togglePinClipboard,
            )
        }
        composable(MainTab.Pinned.route) {
            PinnedScreen(entries = state.clipboardHistory, onUnpin = vm::togglePinClipboard)
        }
        composable(MainTab.Files.route) {
            FilesScreen(files = state.files, pinnedOnly = false, onTogglePin = vm::togglePinFile)
        }
        composable(MainTab.Images.route) {
            val images = state.files.filter { it.mimeType.startsWith("image/") }
            if (images.isEmpty()) {
                AppEmptyState(
                    icon = Icons.Outlined.Image,
                    title = "No images",
                    description = "Photos and screenshots from your devices appear here.",
                )
            } else {
                FilesScreen(files = images, pinnedOnly = false, onTogglePin = vm::togglePinFile)
            }
        }
        composable(MainTab.Settings.route) {
            SettingsScreen(
                connected = state.connected,
                onLogout = vm::logout,
            )
        }
    }
}
