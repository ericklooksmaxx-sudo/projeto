import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../api/playfabapi.dart';

class TokenCheck {
  static final TokenCheck _instance = TokenCheck._internal();
  factory TokenCheck() => _instance;
  TokenCheck._internal();

  final PlayFabClient _client = PlayFabClient.instance;

  Future<bool> isMcTokenValid() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tokenFile = File(
        '${documentsDir.path}/${_client.tokenCacheFileName}.json',
      );

      if (!await tokenFile.exists()) return false;

      final jsonString = await tokenFile.readAsString();
      final tokenData = json.decode(jsonString) as Map<String, dynamic>;

      final mcTokenExpiry = DateTime.parse(tokenData['mcTokenExpiry']);
      final entityTokenExpiry = DateTime.parse(tokenData['entityTokenExpiry']);

      final now = DateTime.now();

      if (now.isBefore(mcTokenExpiry) && now.isBefore(entityTokenExpiry)) {
        final cachedEntityToken = tokenData['entityToken'];
        if (cachedEntityToken != null) {
          _client.restorePersonalEntityToken(cachedEntityToken);
        }
        return true;
      } else {
        await tokenFile.delete();
        return false;
      }
    } catch (e) {
      debugPrint('Token check error: $e');
      return false;
    }
  }
}
