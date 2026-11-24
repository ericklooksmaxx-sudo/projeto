import 'dart:convert';
import 'dart:io';
import 'package:material_ui/material_ui.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import 'environment_service.dart';
import 'minecraft_endpoint_service.dart';

class MinecraftApi {
  MinecraftApi._internal();
  static final MinecraftApi instance = MinecraftApi._internal();
  factory MinecraftApi() => instance;

  final HttpClient _httpClient = HttpClient();

  EnvironmentConfig _env = EnvironmentService.defaultEnv;

  void setEnvironment(EnvironmentConfig env) {
    _env = env;
    MinecraftEndpoints.setEnvironment(env);
  }

  final Map<String, String> _baseHeaders = {
    'User-Agent': 'libhttpclient/1.0.0.0',
    'Content-Type': 'application/json',
    'Accept-Language': 'en-US',
  };

  // Separate headers for guest account (normal login)
  final Map<String, String> _guestHeaders = {};

  // Separate headers for personal account
  final Map<String, String> _personalHeaders = {};

  /// Starts an MC session using the PlayFab session ticket.
  Future<Map<String, dynamic>> startMinecraftSession(
    String sessionTicket, [
    bool usePersonalAccount = false,
  ]) async {
    final url = Uri.parse(MinecraftEndpoints.sessionStart);
    final deviceId = const Uuid().v4();

    final body = {
      "device": {
        "applicationType": "MinecraftPE",
        "capabilities": null,
        "gameVersion": "1.26.0",
        "id": deviceId,
        "isPreview": false,
        "memory": "8570308608",
        "platform": "Windows10",
        "playFabTitleId": _env.titleId,
        "storePlatform": "uwp.store",
        "treatmentOverrides": null,
        "type": "Windows10",
      },
      "user": {
        "language": "en",
        "languageCode": "en-US",
        "regionCode": "US",
        "token": sessionTicket,
        "tokenType": "PlayFab",
      },
    };

    final response = await _sendRequest(
      url,
      body,
      usePersonalAccount: usePersonalAccount,
    );

    final result = response['result'];
    if (result == null || !result.containsKey('authorizationHeader')) {
      debugPrint('session response error: $response');
      throw Exception(
        'Missing authorizationHeader from Minecraft session response',
      );
    }

    final validUntil = result['validUntil'] != null
        ? DateTime.parse(result['validUntil']).toLocal()
        : DateTime.now().add(const Duration(hours: 4));

    final authHeader = result['authorizationHeader'] as String;

    if (usePersonalAccount) {
      _personalHeaders['authorization'] = authHeader;
    } else {
      _guestHeaders['authorization'] = authHeader;
    }

    return {'token': authHeader, 'expiry': validUntil};
  }

  /// Fetches inventory using the MCToken from startMinecraftSession().
  Future<Map<String, dynamic>> getMinecraftInventory([
    String? mcToken,
    bool usePersonalAccount = false,
  ]) async {
    final url = Uri.parse(MinecraftEndpoints.inventory);

    final additionalHeaders = <String, String>{};
    if (mcToken != null) {
      additionalHeaders['authorization'] = mcToken;
    }

    final response = await _sendRequest(
      url,
      null,
      method: 'GET',
      additionalHeaders: additionalHeaders.isNotEmpty
          ? additionalHeaders
          : null,
      usePersonalAccount: usePersonalAccount,
    );

    return response;
  }

  Future<int> getMinecoinBalance([
    String? mcToken,
    bool usePersonalAccount = false,
  ]) async {
    final url = Uri.parse(MinecraftEndpoints.virtualBalances);

    final additionalHeaders = <String, String>{};
    if (mcToken != null) {
      additionalHeaders['authorization'] = mcToken;
    }

    final response = await _sendRequest(
      url,
      null,
      additionalHeaders: additionalHeaders.isNotEmpty
          ? additionalHeaders
          : null,
      usePersonalAccount: usePersonalAccount,
    );

    final result = response['result'];
    if (result == null || !result.containsKey('virtualCurrencyBalances')) {
      throw Exception('Missing virtualCurrencyBalances from response');
    }

    final balances = result['virtualCurrencyBalances'] as List;
    final minecoinBalance = balances.firstWhere(
      (balance) => balance['type'] == 'Minecoin',
      orElse: () => {'amount': 0},
    );

    return minecoinBalance['amount'] as int;
  }

  void dispose() {
    _httpClient.close(force: true);
  }

  Future<Map<String, dynamic>> _sendRequest(
    Uri uri,
    Map<String, dynamic>? data, {
    String method = 'POST',
    Map<String, String>? additionalHeaders,
    bool usePersonalAccount = false,
  }) async {
    HttpClientRequest request;

    if (method == 'GET') {
      request = await _httpClient.getUrl(uri);
    } else {
      request = await _httpClient.postUrl(uri);
    }

    final requestHeaders = Map<String, String>.from(_baseHeaders);

    if (usePersonalAccount) {
      requestHeaders.addAll(_personalHeaders);
    } else {
      requestHeaders.addAll(_guestHeaders);
    }

    if (additionalHeaders != null) {
      requestHeaders.addAll(additionalHeaders);
    }

    requestHeaders.forEach((key, value) {
      request.headers.set(key, value);
    });

    if (data != null) {
      request.add(utf8.encode(jsonEncode(data)));
    }

    final response = await request.close();
    final responseBytes = await response.fold<List<int>>(
      [],
      (a, b) => a..addAll(b),
    );
    final decoded = utf8.decode(responseBytes);
    final result = jsonDecode(decoded);

    return result is Map<String, dynamic> ? result : {'result': result};
  }
}
