package com.syncbridge.android.ui

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.syncbridge.android.SyncBridgeApp
import com.syncbridge.android.data.ApiException
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.data.FileEntry
import com.syncbridge.android.data.UploadProgress
import com.syncbridge.android.sync.SyncClipboardService
import com.syncbridge.android.sync.SyncEventBus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AppUiState(
    val isAuthenticated: Boolean = false,
    val serverUrl: String = "",
    val connected: Boolean = false,
    val loading: Boolean = false,
    val error: String? = null,
    val clipboardHistory: List<ClipboardEntry> = emptyList(),
    val latestClipboard: ClipboardEntry? = null,
    val files: List<FileEntry> = emptyList(),
    val uploads: List<UploadProgress> = emptyList(),
    val darkMode: String = "system",
)

class AppViewModel(application: Application) : AndroidViewModel(application) {

    private val app = application as SyncBridgeApp
    private val api = app.api
    private val uploader = app.fileUploader

    private val _state = MutableStateFlow(
        AppUiState(
            isAuthenticated = api.isAuthenticated,
            serverUrl = api.serverUrl,
        ),
    )
    val state: StateFlow<AppUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            SyncEventBus.connected.collect { connected ->
                _state.update { it.copy(connected = connected) }
            }
        }
        viewModelScope.launch {
            SyncEventBus.clipboardNew.collect { entry ->
                _state.update { s ->
                    s.copy(
                        latestClipboard = entry,
                        clipboardHistory = listOf(entry) + s.clipboardHistory.filter { it.id != entry.id },
                    )
                }
            }
        }
        if (api.isAuthenticated) {
            refreshAll()
            SyncClipboardService.start(application)
        }
    }

    fun refreshAll() {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            try {
                val history = api.fetchClipboardHistory()
                val latest = runCatching { api.fetchCurrentClipboard() }.getOrNull()
                val files = api.listFiles()
                _state.update {
                    it.copy(
                        loading = false,
                        clipboardHistory = history,
                        latestClipboard = latest ?: history.firstOrNull(),
                        files = files,
                    )
                }
            } catch (e: Exception) {
                _state.update { it.copy(loading = false, error = e.message) }
            }
        }
    }

    fun unlock(pin: String, onSuccess: () -> Unit) {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            try {
                api.unlock(pin)
                SyncClipboardService.start(getApplication())
                _state.update { it.copy(isAuthenticated = true, loading = false) }
                refreshAll()
                onSuccess()
            } catch (e: ApiException) {
                _state.update { it.copy(loading = false, error = e.message) }
            } catch (e: Exception) {
                _state.update { it.copy(loading = false, error = e.message ?: "Unlock failed") }
            }
        }
    }

    fun logout() {
        api.logout()
        SyncClipboardService.stop(getApplication())
        _state.value = AppUiState(serverUrl = api.serverUrl)
    }

    fun setServerUrl(url: String) {
        api.serverUrl = url
        _state.update { it.copy(serverUrl = api.serverUrl) }
    }

    fun sendText(text: String) {
        val content = text.trim()
        if (content.isEmpty()) return
        viewModelScope.launch {
            try {
                val entry = api.syncClipboard(content)
                SyncEventBus.emitClipboard(entry)
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message) }
            }
        }
    }

    fun uploadUris(uris: List<Uri>) {
        if (uris.isEmpty()) return
        viewModelScope.launch {
            uploader.uploadUris(uris) { progress ->
                _state.update { s ->
                    val list = s.uploads.filter { it.name != progress.name } + progress
                    s.copy(uploads = list)
                }
            }
            refreshFiles()
            kotlinx.coroutines.delay(3000)
            _state.update { it.copy(uploads = it.uploads.filter { u -> u.status != com.syncbridge.android.data.UploadStatus.Success }) }
        }
    }

    fun refreshFiles() {
        viewModelScope.launch {
            try {
                val files = api.listFiles()
                _state.update { it.copy(files = files) }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message) }
            }
        }
    }

    fun togglePinClipboard(entry: ClipboardEntry) {
        viewModelScope.launch {
            try {
                api.pinClipboard(entry.id, !entry.pinned)
                refreshAll()
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message) }
            }
        }
    }

    fun togglePinFile(file: FileEntry) {
        viewModelScope.launch {
            try {
                api.pinFile(file.id, !file.isPinned)
                refreshFiles()
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message) }
            }
        }
    }

    fun handleShareText(text: String) = sendText(text)

    fun handleShareUris(uris: List<Uri>) = uploadUris(uris)

    fun clearError() = _state.update { it.copy(error = null) }
}
