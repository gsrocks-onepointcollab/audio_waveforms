package com.simform.audio_waveforms

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment

class AudioDownloader(context: Context) {
    private val downloadManger =
        context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    fun downloadFile(url: String): Long {
        val uri = Uri.parse(url)
        val request = DownloadManager.Request(uri)
            .setMimeType("audio/wav")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setTitle(uri.lastPathSegment)
            .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, uri.lastPathSegment)

        return downloadManger.enqueue(request)
    }
}
