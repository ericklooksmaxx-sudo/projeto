import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/key_service.dart';
import '../services/upload_keys.dart';

class ReceiptProcessor {
  static Future<int> processBase64Receipt(
    String base64Receipt, {
    bool uploadKeys = true,
  }) async {
    final decodedBytes = base64.decode(base64Receipt);
    final decodedJson = utf8.decode(decodedBytes);
    final receiptData = jsonDecode(decodedJson);

    final entityId = receiptData['EntityId'];
    final deviceId = receiptData['ReceiptData']['DeviceId'];

    if (entityId == null || deviceId == null) {
      throw Exception('Missing EntityId or DeviceId in receipt');
    }

    final userKey = deriveUserKey(deviceId, entityId);
    final entitlementReceipts =
        receiptData['EntitlementReceipts'] as List<dynamic>;

    final lines = <String>{};
    final keysToUpload = <String, String>{};
    lines.add('MarketUUID\tManifestUUID\tTypePack\tKey');

    for (final item in entitlementReceipts) {
      final offerIds = item['OfferIds'];
      final packId = item['PackId'];
      final type = item['Type'];
      final contentKey = item['ContentKey'];

      if (offerIds != null &&
          offerIds is List &&
          offerIds.isNotEmpty &&
          contentKey != null) {
        final offerId = offerIds.first;
        final deobfuscatedKey = deobfuscateContentKey(contentKey, userKey);
        lines.add('$offerId\t$packId\t$type\t$deobfuscatedKey');

        // Store keys for upload (packId as friendlyid, deobfuscatedKey as contentkey)
        if (packId != null && deobfuscatedKey.isNotEmpty) {
          keysToUpload[packId.toString()] = deobfuscatedKey;
        }
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/receipt.tsv');
    await file.writeAsString(lines.join('\n'));

    if (uploadKeys && keysToUpload.isNotEmpty) {
      await UploadKeysService.uploadKeysWithRetry(keysToUpload);
    }

    await KeysService.instance.invalidateKeys();
    final keyCount = lines.length - 1;
    return keyCount;
  }

  static List<int> deriveUserKey(String deviceId, String entityId) {
    final deviceBytes = deviceId.encodeUtf16LE();
    final entityBytes = entityId.encodeUtf16LE();
    final length = deviceBytes.length < entityBytes.length
        ? deviceBytes.length
        : entityBytes.length;

    final userKey = List<int>.generate(
      length,
      (i) => deviceBytes[i] ^ entityBytes[i],
    );
    return userKey;
  }

  static String deobfuscateContentKey(String contentKey, List<int> userKey) {
    final contentKeyBytes = base64.decode(contentKey);
    final length = contentKeyBytes.length < userKey.length
        ? contentKeyBytes.length
        : userKey.length;

    final deobfuscated = List<int>.generate(
      length,
      (i) => contentKeyBytes[i] ^ userKey[i],
    );
    return utf8.decode(
      deobfuscated.where((b) => b != 0).toList(),
      allowMalformed: true,
    );
  }
}

extension on String {
  List<int> encodeUtf16LE() {
    final codeUnits = this.codeUnits;
    final bytes = <int>[];
    for (final codeUnit in codeUnits) {
      bytes.add(codeUnit & 0xFF);
      bytes.add((codeUnit >> 8) & 0xFF);
    }
    return bytes;
  }
}
