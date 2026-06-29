package com.syncbridge.android.util

import android.graphics.Bitmap
import android.graphics.BitmapFactory

/** Decode image bytes scaled down for UI thumbnails — avoids full-res RAM spikes. */
fun decodeThumbnailBitmap(bytes: ByteArray, maxEdgePx: Int = 512): Bitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

    val sample = calculateInSampleSize(bounds.outWidth, bounds.outHeight, maxEdgePx)
    val opts = BitmapFactory.Options().apply {
        inSampleSize = sample
        inPreferredConfig = Bitmap.Config.RGB_565
    }
    return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
}

private fun calculateInSampleSize(width: Int, height: Int, maxEdge: Int): Int {
    var sample = 1
    var halfW = width / 2
    var halfH = height / 2
    while (halfW / sample >= maxEdge || halfH / sample >= maxEdge) {
        sample *= 2
    }
    return sample.coerceAtLeast(1)
}
