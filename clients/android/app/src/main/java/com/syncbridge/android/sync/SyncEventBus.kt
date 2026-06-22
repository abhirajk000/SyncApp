package com.syncbridge.android.sync

import com.syncbridge.android.data.ClipboardEntry
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

object SyncEventBus {
    private val _clipboardNew = MutableSharedFlow<ClipboardEntry>(extraBufferCapacity = 16)
    val clipboardNew: SharedFlow<ClipboardEntry> = _clipboardNew.asSharedFlow()

    private val _connected = MutableStateFlow(false)
    val connected: StateFlow<Boolean> = _connected.asStateFlow()

    private val _nearbyAlert = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val nearbyAlert: SharedFlow<String> = _nearbyAlert.asSharedFlow()

    private val _filesUpdated = MutableSharedFlow<Unit>(extraBufferCapacity = 4)
    val filesUpdated: SharedFlow<Unit> = _filesUpdated.asSharedFlow()

    fun emitNearbyAlert(deviceId: String) {
        _nearbyAlert.tryEmit(deviceId)
    }

    fun emitFilesUpdated() {
        _filesUpdated.tryEmit(Unit)
    }

    fun emitClipboard(entry: ClipboardEntry) {
        _clipboardNew.tryEmit(entry)
    }

    fun setConnected(value: Boolean) {
        _connected.value = value
    }
}
