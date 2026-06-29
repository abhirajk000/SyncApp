package com.syncbridge.android.util

import java.util.concurrent.atomic.AtomicBoolean

/** Tracks whether the main UI is in the foreground (between onStart/onStop). */
object AppForeground {
    private val foreground = AtomicBoolean(true)

    fun setForeground(value: Boolean) {
        foreground.set(value)
    }

    fun isForeground(): Boolean = foreground.get()
}
