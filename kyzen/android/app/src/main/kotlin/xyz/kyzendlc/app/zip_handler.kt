package xyz.kyzendlc.app

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import androidx.documentfile.provider.DocumentFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.*
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import java.util.zip.Deflater
import androidx.core.net.toUri

class ZipHandler {

    suspend fun extractToDirectory(zipFilePath: String, destinationDirPath: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val zipFile = File(zipFilePath)
            val destinationDir = File(destinationDirPath)
            if (!zipFile.exists()) {
                throw FileNotFoundException("ZIP file not found: $zipFilePath")
            }
            if (!destinationDir.exists()) {
                destinationDir.mkdirs()
            }
            ZipInputStream(BufferedInputStream(FileInputStream(zipFile))).use { zipInputStream ->
                var entry: ZipEntry? = zipInputStream.nextEntry
                while (entry != null) {
                    val entryFile = File(destinationDir, entry.name)
                    if (!entryFile.canonicalPath.startsWith(destinationDir.canonicalPath)) {
                        zipInputStream.closeEntry()
                        entry = zipInputStream.nextEntry
                        continue
                    }
                    if (entry.isDirectory) {
                        entryFile.mkdirs()
                    } else {
                        entryFile.parentFile?.mkdirs()
                        BufferedOutputStream(FileOutputStream(entryFile)).use { outputStream ->
                            val buffer = ByteArray(8192)
                            var bytesRead: Int
                            while (zipInputStream.read(buffer).also { bytesRead = it } != -1) {
                                outputStream.write(buffer, 0, bytesRead)
                            }
                        }
                    }
                    zipInputStream.closeEntry()
                    entry = zipInputStream.nextEntry
                }
            }
            true
        } catch (e: Exception) {
            println("Error extracting ZIP file: ${e.message}")
            throw e // Re-throw the exception instead of returning false
        }
    }

    private fun createZipOutputStream(outputStream: OutputStream, useCompression: Boolean): ZipOutputStream {
        val zos = ZipOutputStream(BufferedOutputStream(outputStream))
        zos.setLevel(if (useCompression) Deflater.DEFAULT_COMPRESSION else Deflater.NO_COMPRESSION)
        return zos
    }

    private fun isContentUri(path: String): Boolean {
        return path.startsWith("content://")
    }

    suspend fun createFromDirectoryLegacy(sourceDirPath: String, zipFilePath: String, useCompression: Boolean = true): String? = withContext(Dispatchers.IO) {
        try {
            val sourceDir = File(sourceDirPath)
            val zipFile = File(zipFilePath)

            if (!sourceDir.exists() || !sourceDir.isDirectory) return@withContext null
            zipFile.parentFile?.mkdirs()

            // Get the absolute path of the source directory to use for string clipping
            val sourceAbsolutePath = sourceDir.absolutePath.let {
                if (it.endsWith(File.separator)) it else it + File.separator
            }

            createZipOutputStream(FileOutputStream(zipFile), useCompression).use { zos ->
                val allFiles = sourceDir.walkTopDown()
                    .filter { it.isFile }

                for (file in allFiles) {
                    // Manually calculate relative path for API 24 compatibility, api 24 is kinda ancient but its just in case
                    val relativePath = file.absolutePath
                        .substring(sourceAbsolutePath.length)
                        .replace('\\', '/') // Ensure ZIP-standard forward slashes

                    val entry = ZipEntry(relativePath).apply { time = file.lastModified() }
                    zos.putNextEntry(entry)

                    FileInputStream(file).use { input ->
                        input.copyTo(zos, 8192)
                    }
                    zos.closeEntry()
                }
            }
            zipFilePath
        } catch (e: Exception) {
            println("Legacy ZIP Error: ${e.message}")
            e.printStackTrace()
            null
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    suspend fun createFromDirectoryModern(
        context: Context,
        sourceDirPath: String,
        outputFilePathOrName: String,
        useCompression: Boolean = true
    ): String? = withContext(Dispatchers.IO) {
        try {
            val sourceDir = File(sourceDirPath)
            if (!sourceDir.exists() || !sourceDir.isDirectory) return@withContext null

            // Check if outputFilePathOrName is a full path or just a filename
            val outputFile = File(outputFilePathOrName)
            val isFullPath = outputFile.parent != null && outputFile.parent != "."

            // Determine if this is the default Downloads/Kyzen path
            val downloadPath = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath
            val defaultKyzenPath = "$downloadPath/Kyzen"
            val isDefaultPath = outputFilePathOrName.startsWith(defaultKyzenPath)
            val isContentUri = isContentUri(outputFilePathOrName)

            if (isDefaultPath || !isFullPath) {
                // Use MediaStore for default Downloads/Kyzen path
                val resolver = context.contentResolver
                val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

                val rawName = if (isFullPath) outputFile.name else outputFilePathOrName
                val uniqueName = resolveUniqueMediaStoreName(resolver, collection, rawName)

                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, uniqueName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Kyzen")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val uri = resolver.insert(collection, contentValues) ?: return@withContext null

                resolver.openOutputStream(uri)?.use { outputStream ->
                    val zos = createZipOutputStream(outputStream, useCompression)
                    val allFiles = sourceDir.walkTopDown().filter { it.isFile }
                    for (file in allFiles) {
                        val relativePath = sourceDir.toPath().relativize(file.toPath()).toString().replace('\\', '/')
                        val entry = ZipEntry(relativePath).apply { time = file.lastModified() }
                        zos.putNextEntry(entry)
                        BufferedInputStream(FileInputStream(file)).use { input -> input.copyTo(zos, 8192) }
                        zos.closeEntry()
                    }
                    zos.finish()
                    zos.close()
                }

                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)

                val actualPath = resolver.query(
                    uri,
                    arrayOf(MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.RELATIVE_PATH),
                    null, null, null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val name = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME))
                        val rel = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH))
                        "${Environment.getExternalStorageDirectory()}/$rel$name"
                    } else null
                } ?: return@withContext null

                actualPath
            } else if (isContentUri) {
                // SAF URI for custom external paths
                val fileName = outputFile.name
                val treeUri = outputFilePathOrName.substringBeforeLast('/').toUri()
                val documentFile = DocumentFile.fromTreeUri(context, treeUri) ?: return@withContext null

                val newFile = documentFile.createFile("application/octet-stream", fileName) ?: return@withContext null

                context.contentResolver.openOutputStream(newFile.uri)?.use { stream ->
                    val zos = createZipOutputStream(stream, useCompression)

                    val allFiles = sourceDir.walkTopDown().filter { it.isFile }

                    for (file in allFiles) {
                        val relativePath = sourceDir.toPath().relativize(file.toPath()).toString().replace('\\', '/')
                        val entry = ZipEntry(relativePath).apply { time = file.lastModified() }
                        zos.putNextEntry(entry)
                        BufferedInputStream(FileInputStream(file)).use { input ->
                            input.copyTo(zos, 8192)
                        }
                        zos.closeEntry()
                    }

                    zos.finish()
                    zos.close()
                } ?: return@withContext null

                newFile.uri.toString()
            } else {
                // just incase if some user still have saved the old path format
                createFromDirectoryLegacy(sourceDirPath, outputFilePathOrName, useCompression)
            }
        } catch (e: Exception) {
            println("Scoped ZIP Error: ${e.message}")
            e.printStackTrace()
            null
        }
    }

    suspend fun createFromMultipleDirectoriesLegacy(sourceDirPaths: List<String>, zipFilePath: String, useCompression: Boolean = true): String? = withContext(Dispatchers.IO) {
        try {
            val zipFile = File(zipFilePath)
            zipFile.parentFile?.mkdirs()

            createZipOutputStream(FileOutputStream(zipFile), useCompression).use { zos ->
                for (dirPath in sourceDirPaths) {
                    val dir = File(dirPath)
                    if (dir.exists() && dir.isDirectory) {
                        addDirToZip(dir, dir.name, zos)
                    }
                }
            }

            zipFilePath
        } catch (e: Exception) {
            println("Legacy Multi-ZIP Error: ${e.message}")
            e.printStackTrace()
            null
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    suspend fun createFromMultipleDirectoriesModern(
        context: Context,
        sourceDirPaths: List<String>,
        outputFilePathOrName: String,
        useCompression: Boolean = true
    ): String? = withContext(Dispatchers.IO) {
        try {
            val outputFile = File(outputFilePathOrName)
            val isFullPath = outputFile.parent != null && outputFile.parent != "."

            val downloadPath = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath
            val defaultKyzenPath = "$downloadPath/Kyzen"
            val isDefaultPath = outputFilePathOrName.startsWith(defaultKyzenPath)
            val isContentUri = isContentUri(outputFilePathOrName)

            if (isDefaultPath || !isFullPath) {
                val resolver = context.contentResolver
                val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

                val rawName = if (isFullPath) outputFile.name else outputFilePathOrName
                val uniqueName = resolveUniqueMediaStoreName(resolver, collection, rawName)

                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, uniqueName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Kyzen")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val uri = resolver.insert(collection, contentValues) ?: return@withContext null

                resolver.openOutputStream(uri)?.use { outputStream ->
                    val zos = createZipOutputStream(outputStream, useCompression)

                    for (dirPath in sourceDirPaths) {
                        val dir = File(dirPath)
                        if (dir.exists() && dir.isDirectory) {
                            addDirToZip(dir, dir.name, zos)
                        }
                    }
                    
                    zos.finish()
                    zos.close()
                }

                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)

                val actualPath = resolver.query(
                    uri,
                    arrayOf(MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.RELATIVE_PATH),
                    null, null, null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val name = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME))
                        val rel = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH))
                        "${Environment.getExternalStorageDirectory()}/$rel$name"
                    } else null
                } ?: return@withContext null

                actualPath
            } else if (isContentUri) {
                val fileName = outputFile.name
                val treeUri = outputFilePathOrName.substringBeforeLast('/').toUri()
                val documentFile = DocumentFile.fromTreeUri(context, treeUri) ?: return@withContext null

                val newFile = documentFile.createFile("application/octet-stream", fileName) ?: return@withContext null

                context.contentResolver.openOutputStream(newFile.uri)?.use { stream ->
                    val zos = createZipOutputStream(stream, useCompression)

                    for (dirPath in sourceDirPaths) {
                        val dir = File(dirPath)
                        if (dir.exists() && dir.isDirectory) {
                            addDirToZip(dir, dir.name, zos)
                        }
                    }

                    zos.finish()
                    zos.close()
                } ?: return@withContext null

                newFile.uri.toString()
            } else {
                createFromMultipleDirectoriesLegacy(sourceDirPaths, outputFilePathOrName, useCompression)
            }
        } catch (e: Exception) {
            println("Scoped Multi-ZIP Error: ${e.message}")
            e.printStackTrace()
            null
        }
    }

    suspend fun createFromDirectory(context: Context, sourceDirPath: String, zipFileNameOrPath: String, useCompression: Boolean = true): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            createFromDirectoryModern(context, sourceDirPath, zipFileNameOrPath, useCompression)
        } else {
            createFromDirectoryLegacy(sourceDirPath, zipFileNameOrPath, useCompression)
        }
    }

    suspend fun createFromMultipleDirectories(context: Context, sourceDirPaths: List<String>, zipFileNameOrPath: String, useCompression: Boolean = true): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            createFromMultipleDirectoriesModern(context, sourceDirPaths, zipFileNameOrPath, useCompression)
        } else {
            createFromMultipleDirectoriesLegacy(sourceDirPaths, zipFileNameOrPath, useCompression)
        }
    }

    private fun addDirToZip(dir: File, basePath: String, zos: ZipOutputStream) {
        val files = dir.listFiles() ?: return

        for (file in files) {
            val entryName = "$basePath/${file.name}".replace('\\', '/')

            if (file.isDirectory) {
                addDirToZip(file, entryName, zos)
            } else {
                val entry = ZipEntry(entryName).apply { time = file.lastModified() }
                zos.putNextEntry(entry)

                BufferedInputStream(FileInputStream(file)).use { input ->
                    input.copyTo(zos, 8192)
                }

                zos.closeEntry()
            }
        }
    }


    // used for appending the number on the file name
    private fun resolveUniqueMediaStoreName(
        resolver: android.content.ContentResolver,
        collection: android.net.Uri,
        desiredName: String,
        relativePath: String = Environment.DIRECTORY_DOWNLOADS + "/Kyzen"
    ): String {
        val base = File(desiredName).nameWithoutExtension
        val ext = File(desiredName).extension.let { if (it.isNotEmpty()) ".$it" else "" }

        var candidate = desiredName
        var counter = 1

        while (true) {
            val exists = resolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH}=?",
                arrayOf(candidate, "$relativePath/"),
                null
            )?.use { it.count > 0 } ?: false

            if (!exists) return candidate
            candidate = "$base($counter)$ext"
            counter++
        }
    }
}