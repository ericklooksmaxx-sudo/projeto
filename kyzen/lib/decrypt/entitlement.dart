import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dlc_dec.dart';
import 'receipt_keys.dart';
import '../services/upload_keys.dart';
import '../models/entitlement_models.dart';

class Entitlement {
  static const _entXorKey = "X(nG*ejm&E8)m+8c;-SkLTjF)*QdN6_Y";
  static final Map<String, String> _pathPairs = {};
  static EntitlementResult? _lastResult;

  static Future<EntitlementResult?> getLastResult() async {
    return _lastResult;
  }

  static Future<EntitlementResult> run() async {
    final errors = <String>[];
    final successfulFiles = <ProcessedFile>[];
    final failedFiles = <FailedFile>[];
    final keysToUpload = <String, String>{};
    final tsvLines = <String>{};
    tsvLines.add('MarketUUID\tManifestUUID\tTypePack\tKey');

    // Initialize paths
    try {
      await _initializePaths();
    } catch (e) {
      errors.add(e.toString());
      _lastResult = EntitlementResult(
        successfulFiles: [],
        failedFiles: [],
        errors: errors,
        totalKeysExtracted: 0,
      );
      return _lastResult!;
    }

    try {
      for (final entry in _pathPairs.entries) {
        final entPath = entry.key;
        final optionsPath = entry.value;

        final titleAccountId = await _getTitleAccountId(optionsPath);
        if (titleAccountId == null || titleAccountId.isEmpty) {
          errors.add('No title account ID found in: $optionsPath');
          continue;
        }

        final entKey = _getEntKey(titleAccountId);
        final dir = Directory(entPath);
        if (!await dir.exists()) continue;

        final entFiles = dir.listSync().whereType<File>().where(
          (f) => f.path.toLowerCase().endsWith(".ent"),
        );

        for (final entFile in entFiles) {
          int keysExtractedFromFile = 0;

          try {
            final fileBytes = await entFile.readAsBytes();
            final content = latin1.decode(fileBytes);

            if (!content.startsWith("Version2")) {
              failedFiles.add(
                FailedFile(
                  filePath: entFile.path,
                  reason:
                      'Invalid file format (not Version2), report this error.',
                ),
              );
              continue;
            }

            final contentAfterHeader = fileBytes.sublist(8);
            late Uint8List cipherBytes;
            try {
              cipherBytes = base64.decode(latin1.decode(contentAfterHeader));
            } catch (e) {
              failedFiles.add(
                FailedFile(
                  filePath: entFile.path,
                  reason: 'Failed to decode base64 content',
                ),
              );
              continue;
            }

            final String keyHex = entKey
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join();
            final decryptedBytes = await Decryptor.instance.decryptBytes(
              data: cipherBytes,
              key: keyHex,
            );

            final decryptedStr = utf8.decode(
              decryptedBytes,
              allowMalformed: true,
            );

            late Map<String, dynamic> mainJson;
            try {
              mainJson = json.decode(decryptedStr);
            } catch (e) {
              failedFiles.add(
                FailedFile(
                  filePath: entFile.path,
                  reason: 'Failed to parse decrypted JSON',
                ),
              );
              continue;
            }

            final encodedReceipt = mainJson["receipt"];
            if (encodedReceipt == null) {
              failedFiles.add(
                FailedFile(
                  filePath: entFile.path,
                  reason: 'No receipt data found',
                ),
              );
              continue;
            }

            late String decodedReceipt;
            try {
              decodedReceipt = utf8.decode(base64.decode(encodedReceipt));
            } catch (e) {
              failedFiles.add(
                FailedFile(
                  filePath: entFile.path,
                  reason: 'Failed to decode receipt',
                ),
              );
              continue;
            }

            late Map<String, dynamic> receiptJson;
            try {
              receiptJson = json.decode(decodedReceipt);
            } catch (e) {
              failedFiles.add(
                FailedFile(
                  filePath: entFile.path,
                  reason: 'Failed to parse receipt JSON',
                ),
              );
              continue;
            }

            final deviceId = receiptJson["ReceiptData"]?["DeviceId"] ?? "";
            final entityId = receiptJson["EntityId"] ?? "";

            final userKey = ReceiptProcessor.deriveUserKey(deviceId, entityId);

            final entitlementReceipts =
                receiptJson["EntitlementReceipts"] as List<dynamic>? ?? [];

            for (final receipt in entitlementReceipts) {
              final packId = receipt["PackId"];
              final contentKey = receipt["ContentKey"];
              final offerIds = receipt["OfferIds"];
              final type = receipt["Type"];

              if (contentKey == null) continue;

              final deobfuscatedKey = ReceiptProcessor.deobfuscateContentKey(
                contentKey,
                userKey,
              );
              if (packId != null && deobfuscatedKey.isNotEmpty) {
                keysToUpload[packId.toString()] = deobfuscatedKey;
                keysExtractedFromFile++;

                if (offerIds != null &&
                    offerIds is List &&
                    offerIds.isNotEmpty) {
                  final offerId = offerIds.first;
                  tsvLines.add('$offerId\t$packId\t$type\t$deobfuscatedKey');
                }
              }
            }

            if (keysExtractedFromFile > 0) {
              successfulFiles.add(
                ProcessedFile(
                  filePath: entFile.path,
                  keysExtracted: keysExtractedFromFile,
                ),
              );
            } else {
              failedFiles.add(
                FailedFile(
                  filePath: entFile.path,
                  reason: 'No valid keys found in entitlement receipts',
                ),
              );
            }
          } catch (e) {
            failedFiles.add(
              FailedFile(
                filePath: entFile.path,
                reason: 'Unexpected error: ${e.toString()}',
              ),
            );
          }
        }
      }

      if (tsvLines.length > 1) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/entitlement.tsv');
        await file.writeAsString(tsvLines.join('\n'));
      }

      // Upload keys
      if (keysToUpload.isNotEmpty) {
        try {
          await UploadKeysService.uploadKeysWithRetry(keysToUpload);
        } catch (e) {
          errors.add('Failed to upload keys: ${e.toString()}');
        }
      }
    } catch (e) {
      errors.add(e.toString());
    }

    _lastResult = EntitlementResult(
      successfulFiles: successfulFiles,
      failedFiles: failedFiles,
      errors: errors,
      totalKeysExtracted: keysToUpload.length,
    );

    return _lastResult!;
  }

  static Future<void> _initializePaths() async {
    final userProfile =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (userProfile == null) {
      throw Exception(
        'Could not determine user profile directory. USERPROFILE and HOME environment variables are not set.',
      );
    }

    // UWP path
    final localStatePath1 = p.join(
      userProfile,
      'AppData',
      'Local',
      'Packages',
      'Microsoft.MinecraftUWP_8wekyb3d8bbwe',
      'LocalState',
    );

    if (await Directory(localStatePath1).exists()) {
      final mcpePath1 = p.join(
        localStatePath1,
        'games',
        'com.mojang',
        'minecraftpe',
      );
      if (await Directory(mcpePath1).exists()) {
        final optionsPath1 = p.join(mcpePath1, 'options.txt');
        if (await File(optionsPath1).exists()) {
          _pathPairs[localStatePath1] = optionsPath1;
        }
      }
    }

    // GDK path
    final roamingBasePath = p.join(
      userProfile,
      'AppData',
      'Roaming',
      'Minecraft Bedrock',
    );

    if (await Directory(roamingBasePath).exists()) {
      final usersDir = p.join(roamingBasePath, 'Users');
      if (await Directory(usersDir).exists()) {
        final userDirs = Directory(usersDir).listSync().whereType<Directory>();

        for (final userDir in userDirs) {
          final optionsPath2 = p.join(
            userDir.path,
            'games',
            'com.mojang',
            'minecraftpe',
            'options.txt',
          );
          if (await File(optionsPath2).exists()) {
            _pathPairs[roamingBasePath] = optionsPath2;
            // If there are multiple users, we'll process with the first valid one found
            break;
          }
        }
      }
    }

    if (_pathPairs.isEmpty) {
      throw EntitlementException('minecraftNotInstalled');
    }
  }

  static Future<String?> _getTitleAccountId(String optionsPath) async {
    final file = File(optionsPath);
    if (!await file.exists()) return null;

    final lines = await file.readAsLines();
    for (final line in lines) {
      if (line.startsWith("last_title_account_id:")) {
        final parts = line.split(':');
        if (parts.length > 1) {
          final id = parts[1].trim();
          if (id.isNotEmpty) return id;
        }
      }
    }
    return null;
  }

  static Uint8List _getEntKey(String titleAccountId) {
    final entKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      entKey[i] =
          titleAccountId.codeUnitAt(i % titleAccountId.length) ^
          _entXorKey.codeUnitAt(i);
    }
    return entKey;
  }
}

class EntitlementException implements Exception {
  final String errorKey;
  final dynamic details;

  EntitlementException(this.errorKey, [this.details]);

  @override
  String toString() => errorKey;
}
