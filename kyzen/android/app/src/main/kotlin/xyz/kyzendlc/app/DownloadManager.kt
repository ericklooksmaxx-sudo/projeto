package xyz.kyzendlc.app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import okhttp3.*
import okio.buffer
import okio.sink
import java.io.File
import java.security.MessageDigest
import java.util.Base64

class DownloadManager {
    private val client = OkHttpClient.Builder()
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    private val mainHandler = Handler(Looper.getMainLooper())

    fun downloadFile(
        requestId: String,
        url: String,
        savePath: String,
        expectedMd5: String?,
        channel: MethodChannel
    ) {
        Thread {
            try {
                val request = Request.Builder()
                    .url(url)
                    .header("User-Agent", "libhttpclient/1.0.0.0")
                    .header("Accept-Encoding", "gzip, deflate, br")
                    .header("Connection", "Keep-Alive")
                    .build()

                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        sendError(channel, requestId, "Download failed with status: ${response.code}")
                        return@Thread
                    }

                    val body = response.body
                    val contentLength = body.contentLength()
                    val contentMd5 = response.header("content-md5")
                    val file = File(savePath)

                    file.parentFile?.mkdirs()

                    val needsMd5Validation = !contentMd5.isNullOrEmpty() || !expectedMd5.isNullOrEmpty()
                    val md5Digest = if (needsMd5Validation) MessageDigest.getInstance("MD5") else null

                    var receivedBytes = 0L
                    var lastPercent = -1

                    file.sink().buffer().use { sink ->
                        val source = body.source()
                        val buffer = ByteArray(8192)
                        var bytesRead: Int

                        while (source.read(buffer).also { bytesRead = it } != -1) {
                            sink.write(buffer, 0, bytesRead)
                            md5Digest?.update(buffer, 0, bytesRead)
                            receivedBytes += bytesRead

                            if (contentLength > 0) {
                                val progressPercent = ((receivedBytes * 100) / contentLength).toInt()

                                if (progressPercent != lastPercent) {
                                    lastPercent = progressPercent
                                    val progress = progressPercent / 100.0
                                    val statusMessage = "${formatMB(receivedBytes)}MB/${formatMB(contentLength)}MB"

                                    sendProgress(channel, requestId, progress, statusMessage)
                                }
                            }
                        }
                    }

                    if (needsMd5Validation && md5Digest != null) {
                        val actualMd5 = Base64.getEncoder().encodeToString(md5Digest.digest())
                        val expectedChecksum = contentMd5 ?: expectedMd5

                        if (expectedChecksum != actualMd5) {
                            file.delete()
                            sendError(channel, requestId, "MD5 checksum mismatch. File may be corrupted.")
                            return@Thread
                        }
                    }

                    // Success
                    sendComplete(channel, requestId, savePath, receivedBytes)
                }
            } catch (e: Exception) {
                sendError(channel, requestId, e.message ?: "Unknown error")
            }
        }.start()
    }

    private fun sendProgress(channel: MethodChannel, requestId: String, progress: Double, status: String) {
        mainHandler.post {
            channel.invokeMethod(
                "onProgress",
                mapOf(
                    "requestId" to requestId,
                    "progress" to progress,
                    "status" to status
                )
            )
        }
    }

    private fun sendComplete(channel: MethodChannel, requestId: String, path: String, bytes: Long) {
        mainHandler.post {
            channel.invokeMethod(
                "onComplete",
                mapOf(
                    "requestId" to requestId,
                    "result" to mapOf(
                        "success" to true,
                        "path" to path,
                        "bytes" to bytes
                    )
                )
            )
        }
    }

    private fun sendError(channel: MethodChannel, requestId: String, error: String) {
        mainHandler.post {
            channel.invokeMethod(
                "onError",
                mapOf(
                    "requestId" to requestId,
                    "error" to error
                )
            )
        }
    }

    private fun formatMB(bytes: Long): String {
        return (bytes / (1024.0 * 1024.0)).toInt().toString()
    }

    fun cancelDownloads() {
        client.dispatcher.cancelAll()
    }
}