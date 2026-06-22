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

    fun emitClipboard(entry: ClipboardEntry) {
        _clipboardNew.tryEmit(entry)
    }

    fun setConnected(value: Boolean) {
        _connected.value = value
    }
}
