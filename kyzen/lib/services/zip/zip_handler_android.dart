import 'dart:io';
import 'package:flutter/services.dart';
import 'package:kyzen/services/settings_service.dart';

class AndroidZipHandler {
  static const MethodChannel _channel = MethodChannel(
    'xyz.kyzendlc.app/import',
  );

  final SettingsService _settingsService = SettingsService.instance;

  Future<void> extractToDirectory({
    required File zipFile,
    required Directory destinationDir,
  }) async {
    try {
      final bool success = await _channel.invokeMethod('extractToDirectory', {
        'zipFilePath': zipFile.path,
        'destinationDirPath': destinationDir.path,
      });

      if (!success) {
        throw Exception('Failed to extract ZIP file');
      }
    } on PlatformException catch (e) {
      throw Exception('Platform error during ZIP extraction: ${e.message}');
    }
  }

  Future<bool> _shouldUseCompression() async {
    return await _settingsService.getCompression();
  }

  // regular dlc
  Future<String> createFromDirectory({
    required Directory sourceDir,
    required File zipFile,
  }) async {
    try {
      final useCompression = await _shouldUseCompression();

      final String actualPath = await _channel
          .invokeMethod('createFromDirectory', {
            'sourceDirPath': sourceDir.path,
            'zipFilePath': zipFile.path,
            'useCompression': useCompression,
          });

      return actualPath;
    } on PlatformException catch (e) {
      throw Exception('Platform error during ZIP creation: ${e.message}');
    }
  }

  // this is used for addons
  Future<String> createFromMultipleDirectories({
    required List<Directory> sourceDirs,
    required File zipFile,
  }) async {
    try {
      final useCompression = await _shouldUseCompression();
      final List<String> sourceDirPaths = sourceDirs
          .map((dir) => dir.path)
          .toList();

      final String actualPath = await _channel
          .invokeMethod('createFromMultipleDirectories', {
            'sourceDirPaths': sourceDirPaths,
            'zipFilePath': zipFile.path,
            'useCompression': useCompression,
          });

      return actualPath;
    } on PlatformException catch (e) {
      throw Exception('Platform error during ZIP creation: ${e.message}');
    }
  }
}
