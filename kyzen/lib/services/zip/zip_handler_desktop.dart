import 'dart:io';
import 'package:native_zip/native_zip.dart';
import 'package:path/path.dart' as p;
import 'package:kyzen/services/settings_service.dart';

class DesktopZipHandler {
  final SettingsService _settingsService = SettingsService.instance;

  Future<void> extractToDirectory({
    required File zipFile,
    required Directory destinationDir,
  }) async {
    try {
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      final future = NativeZip.unzipToDir(zipFile.path, destinationDir.path);
      await future;
    } on Exception catch (e) {
      throw Exception('Exception occured during ZIP extraction: $e');
    }
  }

  // this check if a file already exists, if it does it appends a number to the file name
  // this prevents the "Zip file already exists" exception thrown by native_zip lib
  File _getUniqueZipFile(File originalFile) {
    if (!originalFile.existsSync()) {
      return originalFile;
    }

    final dir = originalFile.parent;
    final nameWithoutExtension = p.basenameWithoutExtension(originalFile.path);
    final extension = p.extension(originalFile.path);

    int counter = 1;
    File newFile;

    do {
      final newName = '$nameWithoutExtension ($counter)$extension';
      newFile = File(p.join(dir.path, newName));
      counter++;
    } while (newFile.existsSync());

    return newFile;
  }

  Future<int> _getCompressionLevel() async {
    final normalCompression = await _settingsService.getCompression();
    return normalCompression
        ? 5
        : 0; // Default 5 if normal compression, 0 if disabled
  }

  // regular dlc
  Future<String> createFromDirectory({
    required Directory sourceDir,
    required File zipFile,
  }) async {
    try {
      await zipFile.parent.create(recursive: true);
      final uniqueZipFile = _getUniqueZipFile(zipFile);
      final compressionLevel = await _getCompressionLevel();
      await NativeZip.zipDir(
        sourceDir.path,
        uniqueZipFile.path,
        skipTopLevel: true,
        compressLevel: compressionLevel,
      );
      return uniqueZipFile.path;
    } on Exception catch (e) {
      throw Exception('Exception occured during ZIP creation: $e');
    }
  }

  // this is used for addons
  Future<String> createFromMultipleDirectories({
    required List<Directory> sourceDirs,
    required File zipFile,
  }) async {
    try {
      await zipFile.parent.create(recursive: true);
      final uniqueZipFile = _getUniqueZipFile(zipFile);
      final compressionLevel = await _getCompressionLevel();
      final zip = NativeZip.openZipFile(uniqueZipFile.path);
      try {
        for (final dir in sourceDirs) {
          if (!await dir.exists()) continue;
          final baseName = '${p.basename(dir.path)}/';
          await zip.addFiles(
            [dir.path],
            baseName,
            skipTopLevel: true,
            compressLevel: compressionLevel,
          );
        }
      } finally {
        zip.close();
      }
      return uniqueZipFile.path;
    } on Exception catch (e) {
      throw Exception('Exception occured during ZIP creation: $e');
    }
  }
}
