import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import '../api/environment_service.dart';
import 'key_service.dart';
import 'http_client.dart';

class UploadKeysService {
  static const List<String> _blacklistedKeys = [
    's5s5ejuDru4uchuF2drUFuthaspAbepE',
  ];

  static String _getUploadUrl() {
    const url = String.fromEnvironment('UPLOAD_KEYS_URL');
    if (url.isEmpty) {
      debugPrint(
        'UPLOAD_KEYS_URL is not set. Build with --dart-define-from-file=.env.json',
      );
      throw Exception(
        'UPLOAD_KEYS_URL is not set. Build with --dart-define-from-file=.env.json',
      );
    }
    return url;
  }

  static Map<String, String> _filterBlacklistedKeys(
    Map<String, String> keysData,
  ) {
    final filteredData = <String, String>{};

    for (final entry in keysData.entries) {
      if (!_blacklistedKeys.contains(entry.value)) {
        filteredData[entry.key] = entry.value;
      }
    }

    return filteredData;
  }

  /// Filters out keys that are already present in the main keys.tsv file
  static Future<Map<String, String>> _filterExistingKeys(
    Map<String, String> keysData,
  ) async {
    try {
      final keysService = KeysService.instance;

      if (!keysService.isInitialized) {
        await keysService.loadKeys();
      }

      // Get the main TSV content (excludes personal keys)
      final mainTsvContent = keysService.mainTsvContent;

      if (mainTsvContent == null || mainTsvContent.isEmpty) {
        return keysData;
      }

      final existingKeys = _parseKeysFromTsv(mainTsvContent);

      final newKeysData = <String, String>{};

      for (final entry in keysData.entries) {
        final manifestUuid = entry.key;
        final contentKey = entry.value;

        // Check if this key already exists in main TSV
        if (!existingKeys.containsKey(manifestUuid) ||
            existingKeys[manifestUuid] != contentKey) {
          newKeysData[manifestUuid] = contentKey;
        }
      }

      return newKeysData;
    } catch (e) {
      debugPrint('Error filtering existing keys: $e');
      return keysData;
    }
  }

  static Map<String, String> _parseKeysFromTsv(String tsvContent) {
    final keys = <String, String>{};
    final lines = tsvContent.split('\n');

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = line.split('\t');
      if (fields.length >= 4) {
        final manifestUuid = fields[1].trim();
        final contentKey = fields[3].trim();

        if (manifestUuid.isNotEmpty && contentKey.isNotEmpty) {
          keys[manifestUuid] = contentKey;
        }
      }
    }

    return keys;
  }

  static Future<bool> uploadKeysWithRetry(
    Map<String, String> keysData, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    if (!EnvironmentService.shouldUploadKeys) return true;

    final filteredKeysData = _filterBlacklistedKeys(keysData);
    final newKeysData = await _filterExistingKeys(filteredKeysData);

    if (newKeysData.isEmpty) {
      return true;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final success = await _uploadKeysInternal(newKeysData);
      if (success) {
        return true;
      }

      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    debugPrint('All upload attempts failed');
    return false;
  }

  static Future<bool> _uploadKeysInternal(Map<String, String> keysData) async {
    try {
      final url = _getUploadUrl();

      final jsonData = keysData.entries
          .map((entry) => {'friendlyid': entry.key, 'contentkey': entry.value})
          .toList();

      final response = await AppHttpClient.instance.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Upload failed with status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading keys: ${_sanitizeError(e)}');
      return false;
    }
  }

  static String _sanitizeError(Object error) {
    final message = error.toString();

    var sanitized = message.replaceAll(
      RegExp(r'https?:\/\/[^\s)]+'),
      '[REDACTED_URL]',
    );

    sanitized = sanitized.replaceAll(
      RegExp(
        r"'[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}'",
      ),
      "'[REDACTED_HOST]'",
    );

    sanitized = sanitized.replaceAll(
      RegExp(
        r'\b[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}\b',
      ),
      '[REDACTED_HOST]',
    );

    return sanitized;
  }
}
