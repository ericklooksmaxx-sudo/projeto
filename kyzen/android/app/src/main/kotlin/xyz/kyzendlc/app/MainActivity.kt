package xyz.kyzendlc.app

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.net.toUri
import androidx.documentfile.provider.DocumentFile
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.withContext
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.util.Base64
import androidx.core.graphics.createBitmap
import androidx.core.graphics.scale
import android.graphics.Color
import android.view.View
import android.view.WindowManager
import androidx.core.view.WindowCompat
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "xyz.kyzendlc.app/import"
    private val DEEP_LINK_CHANNEL = "xyz.kyzendlc.app/deeplink"
    private val DOWNLOAD_CHANNEL = "xyz.kyzendlc.app/download"
    private val STORAGE = "xyz.kyzendlc.app/storage"
    private val PICK_FOLDER_REQUEST = 1001
    private var folderPickerResult: MethodChannel.Result? = null

    private val zipHandler = ZipHandler()
    private var deepLinkMethodChannel: MethodChannel? = null

    // Deep links that land before the Dart handler is registered (cold start).
    private var pendingUuid: String? = null
    private var pendingUnlockCode: String? = null
    private lateinit var downloadManager: DownloadManager
    private lateinit var downloadMethodChannel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)


    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        applyEdgeToEdge()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyEdgeToEdge()
        }
    }

    @Suppress("DEPRECATION")
    private fun applyEdgeToEdge() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                window.decorView.systemUiVisibility
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
        window.statusBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.navigationBarColor = Color.TRANSPARENT
        } else {
            window.navigationBarColor = Color.BLACK
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        downloadManager = DownloadManager()

        downloadMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOAD_CHANNEL
        )

        // This is mainly when the user select a custom path... Android only allows using the download folder without the need to rely on uri permissions
        // Everything else it needs SAF
        // Also dart cant use at all android uri so we are forced to do all file operations here
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STORAGE
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "pickFolder" -> {
                    folderPickerResult = result
                    pickFolder()
                }

                "listFiles" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("INVALID_ARGUMENT", "URI is required", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        try {
                            val files = listFilesInUri(uriString)
                            withContext(Dispatchers.Main) {
                                result.success(files)
                            }
                        } catch (e: Exception) {
                            Log.e("Storage", "listFiles failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("LIST_FAILED", e.message, null)
                            }
                        }
                    }
                }

                "writeFile" -> {
                    val uriString = call.argument<String>("uri")
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")

                    if (uriString == null || fileName == null || content == null) {
                        result.error("INVALID_ARGUMENT", "URI, fileName, and content are required", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        try {
                            val fileUri = writeFileToUri(uriString, fileName, content)
                            withContext(Dispatchers.Main) {
                                if (fileUri != null) {
                                    result.success(fileUri)
                                } else {
                                    result.error("WRITE_ERROR", "Failed to write file", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("Storage", "writeFile failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("WRITE_ERROR", e.message, null)
                            }
                        }
                    }
                }

                "writeFileBytes" -> {
                    val uriString = call.argument<String>("uri")
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")

                    if (uriString == null || fileName == null || bytes == null) {
                        result.error("INVALID_ARGUMENT", "URI, fileName, and bytes are required", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        try {
                            val fileUri = writeFileBytesToUri(uriString, fileName, bytes)
                            withContext(Dispatchers.Main) {
                                if (fileUri != null) {
                                    result.success(fileUri)
                                } else {
                                    result.error("WRITE_ERROR", "Failed to write file", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("Storage", "writeFileBytes failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("WRITE_ERROR", e.message, null)
                            }
                        }
                    }
                }

                "deleteFile" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("INVALID_ARGUMENT", "URI is required", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        try {
                            val deleted = deleteFileByUri(uriString)
                            withContext(Dispatchers.Main) {
                                result.success(deleted)
                            }
                        } catch (e: Exception) {
                            Log.e("Storage", "deleteFile failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("DELETE_FAILED", e.message, null)
                            }
                        }
                    }
                }

                "checkUriPermission" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("INVALID_ARGUMENT", "URI is required", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        try {
                            val uri = uriString.toUri()

                            val hasPersistedPermission = contentResolver.persistedUriPermissions.any { perm ->
                                perm.uri == uri && perm.isReadPermission && perm.isWritePermission
                            }
                            if (!hasPersistedPermission) {
                                withContext(Dispatchers.Main) { result.success(false) }
                                return@launch
                            }
                            val documentFile = DocumentFile.fromTreeUri(this@MainActivity, uri)
                            val accessible = documentFile != null && documentFile.exists() && documentFile.canRead()
                            withContext(Dispatchers.Main) { result.success(accessible) }
                        } catch (e: Exception) {
                            Log.e("Storage", "checkUriPermission failed", e)
                            withContext(Dispatchers.Main) { result.success(false) }
                        }
                    }
                }

                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }

                    ioScope.launch {
                        try {
                            val uri: Uri = if (filePath.startsWith("content://")) {
                                filePath.toUri()
                            } else {
                                val file = File(filePath)
                                FileProvider.getUriForFile(
                                    this@MainActivity,
                                    "${packageName}.fileprovider",
                                    file
                                )
                            }

                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
                            }

                            startActivity(intent)
                            withContext(Dispatchers.Main) {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            Log.e("Storage", "installApk failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("INSTALL_FAILED", e.message, null)
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getContentUri" -> {
                    val filePath = call.argument<String>("filePath")
                    val packageName = call.argument<String>("packageName") ?: "com.mojang.minecraftpe"
                    
                    if (filePath != null) {
                        try {
                            val uri: Uri = if (filePath.startsWith("content://")) {
                                filePath.toUri()
                            } else {
                                // Regular file path
                                val file = File(filePath)
                                FileProvider.getUriForFile(
                                    this,
                                    "xyz.kyzendlc.app.fileprovider",
                                    file
                                )
                            }

                            // Grant permission to Minecraft to read this URI
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "*/*")
                                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
                                setPackage(packageName)
                            }

                            startActivity(intent)
                            result.success("success")
                        } catch (e: Exception) {
                            println("Launch Minecraft error: ${e.message}")
                            e.printStackTrace()
                            result.error("LAUNCH_ERROR", "Could not launch Minecraft: ${e.message}", null)
                        }
                    } else {
                        result.error("NULL_PATH", "File path is null", null)
                    }
                }
                "getInstalledApps" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val pm = packageManager
                            // Android 11+ requires QUERY_ALL_PACKAGES permission or intent-based filtering
                            val apps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                val intent = Intent(Intent.ACTION_MAIN)
                                pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
                                    .map { it.activityInfo.applicationInfo }
                                    .distinctBy { it.packageName }
                            } else {
                                @SuppressLint("QueryPermissionsNeeded")
                                pm.getInstalledApplications(PackageManager.GET_META_DATA)
                            }

                            val appList = apps.map { appInfo ->
                                mapOf(
                                    "packageName" to appInfo.packageName,
                                    "appName" to pm.getApplicationLabel(appInfo).toString(),
                                )
                            }.sortedBy { it["appName"] as String }

                            withContext(Dispatchers.Main) {
                                result.success(appList)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("APPS_ERROR", "Could not fetch installed apps: ${e.message}", null)
                            }
                        }
                    }
                }

                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val pm = packageManager
                                val icon = pm.getApplicationIcon(packageName)
                                val bitmap = if (icon is BitmapDrawable) {
                                    icon.bitmap
                                } else {
                                    createBitmap(
                                        icon.intrinsicWidth.coerceAtLeast(1),
                                        icon.intrinsicHeight.coerceAtLeast(1),
                                    ).also { bmp ->
                                        val canvas = Canvas(bmp)
                                        icon.setBounds(0, 0, canvas.width, canvas.height)
                                        icon.draw(canvas)
                                    }
                                }

                                val scaled = bitmap.scale(96, 96)
                                val stream = ByteArrayOutputStream()
                                scaled.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                val iconBase64 = Base64.encodeToString(
                                    stream.toByteArray(),
                                    Base64.NO_WRAP,
                                )

                                withContext(Dispatchers.Main) {
                                    result.success(iconBase64)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("ICON_ERROR", "Could not fetch icon: ${e.message}", null)
                                }
                            }
                        }
                    } else {
                        result.error("NULL_PKG", "Package name is null", null)
                    }
                }
                "openMinecraftUri" -> {
                    val uriString = call.argument<String>("uri")

                    if (uriString != null) {
                        try {
                            val uri = uriString.toUri()
                            val intent = Intent(Intent.ACTION_VIEW, uri)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

                            val packageManager = context.packageManager
                            val resolveInfos = packageManager.queryIntentActivities(intent, 0)

                            val externalApps = resolveInfos.filterNot {
                                it.activityInfo.packageName == context.packageName
                            }

                            if (externalApps.isNotEmpty()) {
                                // Build a chooser excluding the kyzen app
                                // this is done to exclude the kyzen app as an option when clicking the "open in minecraft" button
                                // since on the android manifest i registered the same uri scheme as minecraft to be able to open store links
                                val targetIntents = externalApps.map {
                                    Intent(Intent.ACTION_VIEW, uri).apply {
                                        `package` = it.activityInfo.packageName
                                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                    }
                                }

                                val chooserIntent = Intent.createChooser(targetIntents.first(), "Open in Minecraft")
                                chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, targetIntents.drop(1).toTypedArray())

                                startActivity(chooserIntent)
                                result.success("success")
                            } else {
                                result.error("NO_TARGET_APP", "No external app found to handle the URI", null)
                            }
                        } catch (e: ActivityNotFoundException) {
                            Log.e("MinecraftURI", "Minecraft not found", e)
                            result.error("MINECRAFT_NOT_FOUND", "Minecraft app not found", e.message ?: "Unknown error")
                        } catch (e: Exception) {
                            Log.e("MinecraftURI", "Error opening URI", e)
                            result.error("URI_ERROR", "Could not open Minecraft URI", e.message ?: "Unknown error")
                        }
                    } else {
                        result.error("INVALID_ARGS", "uri is required", null)
                    }
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"

                    if (filePath != null) {
                        try {
                            val uri: Uri = if (filePath.startsWith("content://")) {
                                filePath.toUri()
                            } else {
                                val file = File(filePath)
                                FileProvider.getUriForFile(
                                    this,
                                    "xyz.kyzendlc.app.fileprovider",
                                    file
                                )
                            }

                            val shareIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                putExtra(Intent.EXTRA_STREAM, uri)
                                type = mimeType
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }

                            startActivity(Intent.createChooser(shareIntent, "Share via"))
                            result.success("success")
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", "Could not share file: ${e.message}", null)
                        }
                    } else {
                        result.error("NULL_PATH", "File path is null", null)
                    }
                }
                
                "extractToDirectory" -> {
                    val zipFilePath = call.argument<String>("zipFilePath")
                    val destinationDirPath = call.argument<String>("destinationDirPath")
                    
                    if (zipFilePath != null && destinationDirPath != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val success = zipHandler.extractToDirectory(zipFilePath, destinationDirPath)
                                mainHandler.post {
                                    if (success) result.success(true)
                                    else result.error("EXTRACTION_ERROR", "Failed to extract ZIP", null)
                                }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("EXTRACTION_ERROR", e.message ?: "Unknown error during extraction", null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "zipFilePath and destinationDirPath are required", null)
                    }
                }

                "createFromDirectory" -> {
                    val sourceDirPath = call.argument<String>("sourceDirPath")
                    val outputFile = call.argument<String>("zipFilePath")
                    val useCompression = call.argument<Boolean>("useCompression") ?: true

                    if (sourceDirPath != null && outputFile != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            val actualPath = zipHandler.createFromDirectory(this@MainActivity, sourceDirPath, outputFile, useCompression)
                            mainHandler.post {
                                if (actualPath != null) result.success(actualPath)
                                else result.error("COMPRESSION_ERROR", "Failed to create ZIP file", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "sourceDirPath and zipFilePath are required", null)
                    }
                }

                "createFromMultipleDirectories" -> {
                    val sourceDirPaths = call.argument<List<String>>("sourceDirPaths")
                    val outputFile = call.argument<String>("zipFilePath")
                    val useCompression = call.argument<Boolean>("useCompression") ?: true

                    if (sourceDirPaths != null && outputFile != null) {
                        CoroutineScope(Dispatchers.IO).launch {
                            val actualPath = zipHandler.createFromMultipleDirectories(this@MainActivity, sourceDirPaths, outputFile, useCompression)
                            mainHandler.post {
                                if (actualPath != null) result.success(actualPath)
                                else result.error("COMPRESSION_ERROR", "Failed to create ZIP from multiple directories", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "sourceDirPaths and zipFilePath are required", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        downloadMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadFile" -> {
                    val requestId = call.argument<String>("requestId")
                    val url = call.argument<String>("url")
                    val savePath = call.argument<String>("savePath")
                    val expectedMd5 = call.argument<String?>("expectedMd5")

                    if (requestId != null && url != null && savePath != null) {
                        downloadManager.downloadFile(
                            requestId = requestId,
                            url = url,
                            savePath = savePath,
                            expectedMd5 = expectedMd5,
                            channel = downloadMethodChannel
                        )

                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "RequestID, URL and savePath required", null)
                    }
                }

                "cancelDownloads" -> {
                    downloadManager.cancelDownloads()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        deepLinkMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
        deepLinkMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart asks for whatever arrived before its handler was ready.
                "consumePending" -> {
                    val pending = mapOf("uuid" to pendingUuid, "code" to pendingUnlockCode)
                    pendingUuid = null
                    pendingUnlockCode = null
                    result.success(pending)
                }

                else -> result.notImplemented()
            }
        }

        // Handle initial deep link if app was launched via deep link
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }



    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == PICK_FOLDER_REQUEST) {
            if (resultCode == RESULT_OK && data != null) {
                val treeUri = data.data

                if (treeUri != null) {
                    // Take persistable permissions so we can use this URI later
                    contentResolver.takePersistableUriPermission(
                        treeUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )

                    // Return the content URI as a string
                    folderPickerResult?.success(treeUri.toString())
                } else {
                    folderPickerResult?.success(null)
                }
            } else {
                folderPickerResult?.success(null)
            }
            folderPickerResult = null
        }
    }

    private fun pickFolder() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        }
        startActivityForResult(intent, PICK_FOLDER_REQUEST)
    }

    private fun listFilesInUri(uriString: String): List<Map<String, Any?>> {
        try {
            val uri = uriString.toUri()
            val documentFile = DocumentFile.fromTreeUri(this, uri) ?: return emptyList()

            val files = mutableListOf<Map<String, Any?>>()
            documentFile.listFiles().forEach { file ->
                if (file.isFile) {
                    files.add(mapOf(
                        "name" to file.name,
                        "uri" to file.uri.toString(),
                        "size" to file.length(),
                        "lastModified" to file.lastModified(),
                        "mimeType" to file.type
                    ))
                }
            }
            return files
        } catch (e: Exception) {
            println("Error listing files: ${e.message}")
            return emptyList()
        }
    }

    // This used for image saving/apk installing
    private fun writeFileBytesToUri(uriString: String, fileName: String, bytes: ByteArray): String? {
        try {
            val treeUri = uriString.toUri()
            var documentFile = DocumentFile.fromTreeUri(this, treeUri) ?: return null

            val pathParts = fileName.split("/")
            val actualFileName = pathParts.last()
            val subdirectories = pathParts.dropLast(1)

            for (dirName in subdirectories) {
                var subDir = documentFile.listFiles().find {
                    it.isDirectory && it.name == dirName
                }

                if (subDir == null) {
                    subDir = documentFile.createDirectory(dirName)
                }

                if (subDir == null) {
                    println("Failed to create/find directory: $dirName")
                    return null
                }

                documentFile = subDir
            }

            documentFile.listFiles().find { it.name == actualFileName }?.delete()

            val mimeType = when {
                actualFileName.endsWith(".png", ignoreCase = true) -> "image/png"
                actualFileName.endsWith(".jpg", ignoreCase = true) ||
                        actualFileName.endsWith(".jpeg", ignoreCase = true) -> "image/jpeg"
                actualFileName.endsWith(".apk", ignoreCase = true) -> "application/vnd.android.package-archive"
                actualFileName.endsWith(".zip", ignoreCase = true) -> "application/zip"
                actualFileName.endsWith(".tar.gz", ignoreCase = true) ||
                        actualFileName.endsWith(".tgz", ignoreCase = true) -> "application/gzip"
                else -> "application/octet-stream"
            }

            val newFile = documentFile.createFile(mimeType, actualFileName) ?: return null

            contentResolver.openOutputStream(newFile.uri)?.use { outputStream ->
                outputStream.write(bytes)
            }

            return newFile.uri.toString()
        } catch (e: Exception) {
            println("Error writing bytes to URI: ${e.message}")
            e.printStackTrace()
            return null
        }
    }
    // for saving text
    private fun writeFileToUri(uriString: String, fileName: String, content: String): String? {
        try {
            val treeUri = uriString.toUri()
            val documentFile = DocumentFile.fromTreeUri(this, treeUri) ?: return null

            documentFile.listFiles().find { it.name == fileName }?.delete()

            val mimeType = when {
                fileName.endsWith(".txt", ignoreCase = true) -> "text/plain"
                fileName.endsWith(".log", ignoreCase = true) -> "text/plain"
                fileName.endsWith(".json", ignoreCase = true) -> "application/json"
                else -> "text/plain"
            }

            val newFile = documentFile.createFile(mimeType, fileName) ?: return null

            contentResolver.openOutputStream(newFile.uri)?.use { outputStream ->
                outputStream.write(content.toByteArray())
            }

            return newFile.uri.toString()
        } catch (e: Exception) {
            println("Error writing file to URI: ${e.message}")
            e.printStackTrace()
            return null
        }
    }
    private fun deleteFileByUri(uriString: String): Boolean {
        try {
            val uri = uriString.toUri()
            val documentFile = DocumentFile.fromSingleUri(this, uri) ?: return false
            return documentFile.delete()
        } catch (e: Exception) {
            println("Error deleting file: ${e.message}")
            return false
        }
    }

    private fun handleIntent(intent: Intent?) {
        val data: Uri? = intent?.data

        // Gate return from the browser: kyzen://unlock?c=<code>
        if (data != null && data.scheme == "kyzen" && data.host == "unlock") {
            val raw = data.getQueryParameter("c")
            val code = if (raw != null && raw.length <= 2000 && raw.matches(Regex("[A-Za-z0-9_.-]+"))) raw else ""
            pendingUnlockCode = code
            deepLinkMethodChannel?.invokeMethod("onUnlock", mapOf("code" to code))
            return
        }

        if (data != null && data.scheme == "minecraft") {
            val uuid = when (data.host) {
                "openStore" -> data.getQueryParameter("showStoreOffer")
                "showDressingRoomOffer" -> data.getQueryParameter("offerID")
                "domain" -> data.getQueryParameter("showStoreOffer")
                else -> null
            }

            if (uuid != null) {
                pendingUuid = uuid
                deepLinkMethodChannel?.invokeMethod("onDeepLink", mapOf("uuid" to uuid))
            }
        }
    }
}