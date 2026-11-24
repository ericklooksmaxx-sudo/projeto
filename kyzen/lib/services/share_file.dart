import 'package:material_ui/material_ui.dart' show debugPrint;
import 'package:flutter/services.dart';

class ShareFile {
  static const MethodChannel _channel = MethodChannel(
    'xyz.kyzendlc.app/import',
  );

  static Future<String?> shareFile({
    required String filePath,
    String mimeType = '*/*',
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('shareFile', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Failed to share file: ${e.message}');
      throw Exception('Failed to share file: ${e.message}');
    }
  }
}
