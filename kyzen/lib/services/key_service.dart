import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io';
import 'package:material_ui/material_ui.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'http_client.dart';
import 'share_file.dart';
import 'settings_service.dart';
import 'app_version.dart';

class KeysService {
  static KeysService? _instance;
  final Set<String> _availableKeys = {};
  final Map<String, String> _keysMap = {};
  final Set<String> _mainManifestUuids = {};
  Set<String> get mainManifestUuids => _mainManifestUuids;
  String? _tsvContent;
  String? get mainTsvContent => _tsvContent;
  bool _isInitialized = false;
  bool _hasDownloadedOnce = false;
  Future<int>? _loadingFuture;

  static KeysService get instance {
    _instance ??= KeysService._internal();
    return _instance!;
  }

  KeysService._internal();

  /// Checks if an error is caused by network issues or restricted region
  static bool isNetworkOrRestrictedError(Object? error) {
    if (error == null) return false;
    if (error is KeyNetworkException) return true;
    final msg = error.toString().toLowerCase();
    return msg.contains('unable to reach the server') ||
        msg.contains('connection timed out') ||
        msg.contains('socketexception') ||
        msg.contains('network error') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('no route to host') ||
        msg.contains('network is unreachable');
  }

  bool isKeyAvailable(String dlcId) {
    return _availableKeys.contains(dlcId);
  }

  bool get isInitialized => _isInitialized;

  /// Invalidate keys to force reload (used when personal keys are updated)
  Future<void> invalidateKeys() async {
    _isInitialized = false;
    _availableKeys.clear();
    _keysMap.clear();
    _mainManifestUuids.clear();
    _tsvContent = null;
    _loadingFuture = null;

    try {
      await loadKeys();
    } catch (e) {
      debugPrint('Failed to reload keys after invalidation: $e');
    }
  }

  /// should be called once at app startup
  Future<int> initialize({bool download = false}) async {
    if (_isInitialized && !download) return 0;

    // If a load is already in progress, return the same future
    if (_loadingFuture != null) return _loadingFuture!;

    // Reset initialization state if forcing download
    if (download) {
      _isInitialized = false;
      _hasDownloadedOnce = false;
    }

    // Start initialization
    _loadingFuture = _initializeInternal();
    return _loadingFuture!;
  }

  Future<int> _initializeInternal() async {
    int newKeysCount = 0;
    String? tsvContent;
    String? personalTsvContent;
    Set<String> oldMainKeys = {};
    Object? caughtError;

    try {
      final localKeysFile = await _getLocalKeysFile();
      final etagFile = await _getEtagFile();

      if (!await localKeysFile.exists() && await etagFile.exists()) {
        try {
          await _deleteEtag();
          debugPrint(
            'keys.tsv is missing but etag.txt exists. Deleted stale etag.txt.',
          );
        } catch (e) {
          debugPrint('Failed to delete stale etag.txt: $e');
        }
      }

      final localContent = await _loadFromLocalFallback();
      final personalContent = await _loadPersonalKeys();

      if (localContent != null) {
        oldMainKeys = _parseKeysToSet(localContent);
      }

      if (!_hasDownloadedOnce) {
        final downloadedContent = await _downloadAndDecryptKeys();
        _hasDownloadedOnce = true;

        if (downloadedContent != null) {
          tsvContent = downloadedContent;
          final newMainKeys = _parseKeysToSet(tsvContent);

          newKeysCount = _countNewKeys(oldMainKeys, newMainKeys);
          await _saveToLocal(tsvContent);
        } else {
          // Content not modified (304), use existing local content
          tsvContent = localContent;
          debugPrint('Keys not modified, using cached content');
        }
      } else {
        tsvContent = localContent;
      }

      personalTsvContent = personalContent;
    } catch (e) {
      debugPrint('Download/decryption failed: $e');

      caughtError = e;
      tsvContent = await _loadFromLocalFallback();
      personalTsvContent = await _loadPersonalKeys();
    } finally {
      _loadingFuture = null;
    }

    if (tsvContent != null) {
      _tsvContent = tsvContent;

      _availableKeys.clear();
      _keysMap.clear();
      _mainManifestUuids.clear();

      _parseTsv(tsvContent, isMainTsv: true);
      if (personalTsvContent != null) {
        _parseTsv(personalTsvContent, isMainTsv: false);
      }

      _isInitialized = true;
    } else {
      debugPrint('Failed to load any key data.');
      _isInitialized = false;
    }

    if (caughtError != null) {
      throw caughtError;
    }

    return newKeysCount;
  }

  Future<int> loadKeys() async {
    // If already initialized, just return immediately
    if (_isInitialized) return 0;

    // If a load is already in progress, return the same future
    if (_loadingFuture != null) return _loadingFuture!;

    // Start a new load
    _loadingFuture = _loadKeysLocalOnly();
    return _loadingFuture!;
  }

  Future<int> _loadKeysLocalOnly() async {
    String? tsvContent;
    String? personalTsvContent;
    Object? caughtError;

    try {
      tsvContent = await _loadFromLocalFallback();
      personalTsvContent = await _loadPersonalKeys();
    } catch (e) {
      debugPrint('Failed to load local keys: $e');
      caughtError = e;
    } finally {
      _loadingFuture = null;
    }

    if (tsvContent != null) {
      _tsvContent = tsvContent;

      _availableKeys.clear();
      _keysMap.clear();
      _mainManifestUuids.clear();

      _parseTsv(tsvContent, isMainTsv: true);
      if (personalTsvContent != null) {
        _parseTsv(personalTsvContent, isMainTsv: false);
      }

      _isInitialized = true;
    } else {
      debugPrint('Failed to load any key data.');
      _isInitialized = false;
    }

    if (caughtError != null) {
      throw caughtError;
    }

    return 0;
  }

  Future<String?> _loadPersonalKeys() async {
    List<String> allLines = [];
    String? header;
    bool hasAnyContent = false;

    try {
      final dir = await getApplicationDocumentsDirectory();

      final filesToLoad = [
        KeysFileType.personal,
        KeysFileType.receipt,
        KeysFileType.entitlement,
      ];

      for (final fileType in filesToLoad) {
        final file = File('${dir.path}/${fileType.fileName}');
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isNotEmpty) {
            final lines = content.split('\n');
            if (lines.isNotEmpty) {
              // Use first file's header
              if (header == null && lines[0].trim().isNotEmpty) {
                header = lines[0];
              }
              // Add data rows (skip header)
              for (int i = 1; i < lines.length; i++) {
                if (lines[i].trim().isNotEmpty) {
                  allLines.add(lines[i]);
                }
              }
              hasAnyContent = true;
            }
          }
        }
      }

      if (!hasAnyContent || header == null) {
        return null;
      }

      final result = '$header\n${allLines.join('\n')}';
      return result;
    } catch (e) {
      debugPrint('Error reading personal keys: $e');
      return null;
    }
  }

  /// Get the decryption key for a specific UUID
  Future<String?> getKeyForUuid(String uuid) async {
    if (!_isInitialized) {
      await loadKeys();
    }
    return _keysMap[uuid];
  }

  void _parseTsv(String tsvData, {required bool isMainTsv}) {
    final lines = tsvData.split('\n');
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final fields = line.split('\t');
      if (fields.length >= 4) {
        final marketUuid = fields[0].trim();
        final manifestUuid = fields[1].trim();
        final key = fields[3].trim();

        if (marketUuid.isNotEmpty) {
          _availableKeys.add(marketUuid);
        }
        if (manifestUuid.isNotEmpty) {
          _keysMap[manifestUuid] = key;
          if (isMainTsv) {
            _mainManifestUuids.add(manifestUuid);
          }
        }
      } else if (fields.isNotEmpty) {
        final marketUuid = fields[0].trim();
        if (marketUuid.isNotEmpty) {
          _availableKeys.add(marketUuid);
        }
      }
    }
  }

  Set<String> _parseKeysToSet(String tsvData) {
    final keys = <String>{};
    final lines = tsvData.split('\n');
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final fields = line.split('\t');
      if (fields.isNotEmpty) {
        final uuid = fields[0].trim();
        if (uuid.isNotEmpty) {
          keys.add(uuid);
        }
      }
    }
    return keys;
  }

  int _countNewKeys(Set<String> oldKeys, Set<String> newKeys) {
    if (oldKeys.isEmpty) return newKeys.length;

    final uniqueNewKeys = newKeys.difference(oldKeys);
    return uniqueNewKeys.length;
  }

  Future<int> getKeysCount(KeysFileType fileType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${fileType.fileName}');

      if (!await file.exists()) {
        return 0;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return 0;
      }

      final lines = content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (lines.length <= 1) {
        return 0;
      }

      // Skip header
      final dataLines = lines.sublist(1);

      int count = 0;

      for (final line in dataLines) {
        final parts = line.trim().split('\t');
        if (parts.length == 4) {
          count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('Error reading ${fileType.fileName} count: $e');
      return 0;
    }
  }

  Future<String> formatKeysForSharing(KeysFileType fileType) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final filePath = '${documentsDir.path}/${fileType.fileName}';
      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception('File ${fileType.fileName} not found');
      }

      final content = await file.readAsString();
      final lines = content.split('\n');

      final dataLines = lines.skip(1).where((line) => line.trim().isNotEmpty);

      List<String> filteredLines = dataLines.toList();

      final onlyNewKeys = await SettingsService.instance.getKeyExport();

      if (onlyNewKeys) {
        // Filter out existing keys
        filteredLines = dataLines.where((line) {
          final columns = line.split('\t');
          if (columns.length >= 4) {
            final manifestUUID = columns[1].trim();
            final key = columns[3].trim();

            if (key == 's5s5ejuDru4uchuF2drUFuthaspAbepE') return false;

            return !_mainManifestUuids.contains(manifestUUID);
          }
          return false;
        }).toList();
      }

      final formattedLines = <String>[];

      for (final line in filteredLines) {
        final columns = line.split('\t');
        if (columns.length >= 4) {
          final manifestUUID = columns[1].trim(); // ManifestUUID column
          final key = columns[3].trim(); // Key column

          if (manifestUUID.isNotEmpty && key.isNotEmpty) {
            formattedLines.add('$manifestUUID=$key');
          }
        }
      }

      return formattedLines.join('\n');
    } catch (e) {
      throw Exception('Failed to format keys: $e');
    }
  }

  /// Creates a temporary file with formatted keys and shares it
  Future<void> shareKeys(KeysFileType fileType, String formattedContent) async {
    try {
      if (formattedContent.isEmpty) {
        throw Exception('No keys found to share');
      }

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFileName = '${fileType.name}_keys_$timestamp.db';
      final tempFilePath = '${tempDir.path}/$tempFileName';

      final tempFile = File(tempFilePath);
      await tempFile.writeAsString(formattedContent);

      // Share the file
      await ShareFile.shareFile(filePath: tempFilePath, mimeType: 'text/plain');
    } catch (e) {
      throw Exception('Failed to share keys: $e');
    }
  }

  Future<void> saveKeys(KeysFileType fileType, String formattedContent) async {
    try {
      if (formattedContent.isEmpty) {
        throw Exception('No keys found to save');
      }

      final folderPath = await SettingsService.instance.getDownloadPath();
      final fileName =
          '${fileType.name}_keys_${DateTime.now().millisecondsSinceEpoch}.db';
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      await file.writeAsString(formattedContent);

      debugPrint('Keys saved to: $filePath');
    } catch (e) {
      throw Exception('Failed to save keys: $e');
    }
  }

  /// Gets formatted keys as string (for clipboard copying)
  Future<String> getFormattedKeysAsString(KeysFileType fileType) async {
    return await formatKeysForSharing(fileType);
  }

  /// Copies formatted keys to clipboard
  Future<void> copyKeysToClipboard(String formattedContent) async {
    try {
      if (formattedContent.isEmpty) {
        throw Exception('No keys found to copy');
      }
      await Clipboard.setData(ClipboardData(text: formattedContent));
    } catch (e) {
      throw Exception('Failed to copy keys: $e');
    }
  }

  Future<String?> _loadFromLocalFallback() async {
    try {
      final localFile = await _getLocalKeysFile();
      if (await localFile.exists()) {
        return await localFile.readAsString();
      } else {
        // Fallback
        return await rootBundle.loadString('assets/keys.tsv');
      }
    } catch (e) {
      debugPrint('Error reading local or asset fallback: $e');
      return null;
    }
  }

  String _sanitizeError(Object error) {
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

  Future<File> _getLocalKeysFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/keys.tsv');
  }

  Future<File> _getEtagFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/etag.txt');
  }

  Future<void> _saveToLocal(String tsv) async {
    final file = await _getLocalKeysFile();
    await file.writeAsString(tsv);
  }

  Future<String?> _downloadAndDecryptKeys() async {
    const url = String.fromEnvironment('KEYS_URL');
    const rawDecryptionKey = String.fromEnvironment('KEYS_DECRYPTION_KEY');

    if (url.isEmpty) {
      debugPrint(
        'KEYS_URL is not set. Build with --dart-define-from-file=.env.json',
      );
      throw Exception(
        'KEYS_URL is not set. Build with --dart-define-from-file=.env.json',
      );
    }
    if (rawDecryptionKey.isEmpty) {
      debugPrint(
        'KEYS_DECRYPTION_KEY is not set. Build with --dart-define-from-file=.env.json',
      );
      throw Exception(
        'KEYS_DECRYPTION_KEY is not set. Build with --dart-define-from-file=.env.json',
      );
    }

    try {
      final localKeysFile = await _getLocalKeysFile();
      final localKeysExist = await localKeysFile.exists();

      final currentEtag = await _readEtag();
      final headers = {'User-Agent': AppVersion.userAgent};

      // If we have an ETag and local keys.tsv exists, HEAD request first
      if (currentEtag != null && localKeysExist) {
        headers['If-None-Match'] = currentEtag;
        try {
          final headResponse = await AppHttpClient.instance
              .head(Uri.parse(url), headers: headers)
              .timeout(const Duration(seconds: 15));

          if (headResponse.statusCode == 304) {
            return null; // Not modified
          }
        } catch (e) {
          // Ignore HEAD failures, proceed with GET request
          debugPrint("HEAD request failed: ${_sanitizeError(e)}");
        }
      }

      // Do GET request (either no ETag or content was modified)
      if (currentEtag != null && localKeysExist) {
        headers['If-None-Match'] = currentEtag;
      }

      final response = await AppHttpClient.instance
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 304) {
        return null; // Not modified
      }

      if (response.statusCode != 200) {
        throw HttpException('Server returned ${response.statusCode}');
      }

      // Save new ETag
      final newEtag = response.headers['etag'];
      if (newEtag != null) {
        await _saveEtag(newEtag);
      }

      debugPrint("Keys downloaded");
      final rawData = response.bodyBytes;
      Uint8List decryptionKey = Uint8List.fromList(rawDecryptionKey.codeUnits);

      if (decryptionKey.length != 32) {
        final padded = Uint8List(32)..setAll(0, decryptionKey);
        decryptionKey = padded;
      }
      return _decryptOrParseTsv(rawData, decryptionKey);
    } on TimeoutException {
      throw const KeyNetworkException(
        "Connection timed out. Please try again.",
      );
    } on SocketException {
      throw const KeyNetworkException(
        "Network error: Unable to reach the server.",
      );
    } catch (e) {
      if (e is KeyNetworkException) rethrow;
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        throw Exception(
          "SSL Certificate error. Please check:\n"
          "• System date/time is correct\n"
          "• Windows is up to date\n"
          "• Antivirus isn't blocking connections\n"
          "• Ur not using networks inspectors tools (faggot)\n"
          "• Try a different network",
        );
      }
      final errLower = e.toString().toLowerCase();
      if (errLower.contains('failed host lookup') ||
          errLower.contains('connection refused') ||
          errLower.contains('connection reset') ||
          errLower.contains('no route to host') ||
          errLower.contains('network is unreachable') ||
          errLower.contains('clientexception') ||
          errLower.contains('unable to reach the server')) {
        throw KeyNetworkException(
          "Network error: Unable to reach the server: ${_sanitizeError(e)}",
        );
      }
      throw Exception("Failed to download key file: ${_sanitizeError(e)}");
    }
  }

  Future<void> _saveEtag(String etag) async {
    final file = await _getEtagFile();
    await file.writeAsString(etag.trim());
  }

  Future<void> _deleteEtag() async {
    try {
      final file = await _getEtagFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<String?> _readEtag() async {
    try {
      final keysFile = await _getLocalKeysFile();
      if (!await keysFile.exists()) {
        await _deleteEtag();
        return null;
      }

      final file = await _getEtagFile(); // dont touch the etag
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.trim().isNotEmpty ? content.trim() : null;
      }
    } catch (_) {}
    return null;
  }

  String _decryptOrParseTsv(Uint8List rawData, Uint8List key) {
    try {
      final decrypted = _decryptTsv(rawData, key);
      if (_isValidTsv(decrypted)) return decrypted;
    } catch (_) {}

    try {
      final plain = utf8.decode(rawData);
      if (_isValidTsv(plain)) return plain;
    } catch (_) {}

    throw Exception('Content is neither valid encrypted nor plaintext TSV');
  }

  bool _isValidTsv(String content) {
    const expectedHeader = 'MarketUUID\tManifestUUID\tTypePack\tKey';
    return content.startsWith(expectedHeader);
  }

  String _decryptTsv(Uint8List rawData, Uint8List key) {
    final iv = rawData.sublist(0, 16);
    final ciphertext = rawData.sublist(16);

    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));

    final output = Uint8List(ciphertext.length);
    final blockSize = cipher.blockSize;
    int offset = 0;

    for (int i = 0; i < ciphertext.length - blockSize; i += blockSize) {
      cipher.processBlock(ciphertext, i, output, offset);
      offset += blockSize;
    }

    final lastBlockStart = ciphertext.length - blockSize;
    cipher.processBlock(ciphertext, lastBlockStart, output, offset);

    final paddingSize = output.last;
    final unpadded = (paddingSize > 0 && paddingSize <= blockSize)
        ? output.sublist(0, output.length - paddingSize)
        : output;

    return utf8.decode(unpadded);
  }
}

enum KeysFileType {
  personal('personal_keys.tsv'), // from custom db
  receipt('receipt.tsv'), // from auth login
  entitlement('entitlement.tsv'); // from entitlement (.ent files)

  const KeysFileType(this.fileName);
  final String fileName;
}

class KeyNetworkException implements Exception {
  final String message;
  final bool isConnectionError;

  const KeyNetworkException(this.message, {this.isConnectionError = true});

  @override
  String toString() => message;
}
