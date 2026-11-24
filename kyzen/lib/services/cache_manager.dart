import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class SmallCacheManager {
  static Future<double> clearCache() async {
    int totalBytes = 0;
    final tempDir = await getTemporaryDirectory();

    // Measure CE cache before wiping
    final ceCache = Directory('${tempDir.path}/cached_network_image_ce');
    if (await ceCache.exists()) {
      for (final entity in ceCache.listSync(recursive: true)) {
        if (entity is File) totalBytes += await entity.length();
      }
      try {
        await DefaultCacheManager().emptyCache();
      } catch (e) {
        debugPrint('Failed to empty CE cache: $e');
      }
    }

    for (final dir in [
      // old dirs
      Directory('${tempDir.path}/smallImageCache'),
      Directory('${tempDir.path}/libCachedImageData'),
      Directory('${tempDir.path}/file_picker'),
    ]) {
      if (await dir.exists()) {
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File) totalBytes += await entity.length();
        }
        try {
          await dir.delete(recursive: true);
        } catch (e) {
          debugPrint('Failed to delete ${dir.path}: $e');
        }
      }
    }

    // Clean up mcpack temporary directories
    for (final entity in tempDir.listSync()) {
      if (entity is Directory &&
          path.basename(entity.path).startsWith('mcpack_process_')) {
        for (final file in entity.listSync(recursive: true)) {
          if (file is File) totalBytes += await file.length();
        }
        try {
          await entity.delete(recursive: true);
        } catch (e) {
          debugPrint('Failed to delete mcpack directory: ${entity.path}, $e');
        }
      }
    }

    return totalBytes / (1024 * 1024);
  }
}
