import 'dart:io';
import 'package:kyzen/services/zip/zip_handler_android.dart';
import 'package:kyzen/services/zip/zip_handler_desktop.dart';

class ZipHandler {
  static final _android = AndroidZipHandler();
  static final _desktop = DesktopZipHandler();

  static Future<void> extractToDirectory({
    required File zipFile,
    required Directory destinationDir,
  }) => Platform.isAndroid
      ? _android.extractToDirectory(
          zipFile: zipFile,
          destinationDir: destinationDir,
        )
      : _desktop.extractToDirectory(
          zipFile: zipFile,
          destinationDir: destinationDir,
        );

  static Future<String> createFromDirectory({
    required Directory sourceDir,
    required File zipFile,
  }) => Platform.isAndroid
      ? _android.createFromDirectory(sourceDir: sourceDir, zipFile: zipFile)
      : _desktop.createFromDirectory(sourceDir: sourceDir, zipFile: zipFile);

  static Future<String> createFromMultipleDirectories({
    required List<Directory> sourceDirs,
    required File zipFile,
  }) => Platform.isAndroid
      ? _android.createFromMultipleDirectories(
          sourceDirs: sourceDirs,
          zipFile: zipFile,
        )
      : _desktop.createFromMultipleDirectories(
          sourceDirs: sourceDirs,
          zipFile: zipFile,
        );
}
