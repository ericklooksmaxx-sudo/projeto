import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/http_client.dart';

class OAuth2Token {
  final String accessToken;
  final String tokenType;
  final String refreshToken;
  final DateTime expiry;

  OAuth2Token({
    required this.accessToken,
    required this.tokenType,
    required this.refreshToken,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'token_type': tokenType,
    'refresh_token': refreshToken,
    'expiry': expiry.toIso8601String(),
  };

  factory OAuth2Token.fromJson(Map<String, dynamic> json) => OAuth2Token(
    accessToken: json['access_token'],
    tokenType: json['token_type'],
    refreshToken: json['refresh_token'],
    expiry: DateTime.parse(json['expiry']),
  );
}

/// Token source interface
abstract class TokenSource {
  Future<OAuth2Token> getToken();
}

/// Microsoft Live Connect authentication implementation
class LiveConnectAuth implements TokenSource {
  static const String clientId = '0000000048183522';
  static const String scope = 'service::user.auth.xboxlive.com::MBI_SSL';

  // URL to redirect the user to for login and consent.
  static const String authorizationUrl =
      'https://login.live.com/oauth20_authorize.srf';

  // URL to exchange codes and refresh tokens.
  static const String tokenUrl = 'https://login.live.com/oauth20_token.srf';
  static const String defaultTokenFile = 'personal_token.json';
  static const String redirectUri = 'ms-xal-0000000048183522://auth';

  OAuth2Token? _cachedToken;
  String? _tokenFilePath;

  LiveConnectAuth({String? tokenFilePath}) : _tokenFilePath = tokenFilePath;

  Future<String> _getTokenFilePath() async {
    if (_tokenFilePath != null) {
      return _tokenFilePath!;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    _tokenFilePath = '${documentsDir.path}/$defaultTokenFile';
    return _tokenFilePath!;
  }

  /// Generates the URL to be opened in a browser for user authentication.
  ///
  /// [redirectUri] must match the custom URL scheme configured in the app.
  String getAuthorizationUrl() {
    final params = {
      'client_id': clientId,
      'scope': scope,
      'response_type': 'code',
      'redirect_uri': redirectUri,
    };
    return Uri.parse(
      authorizationUrl,
    ).replace(queryParameters: params).toString();
  }

  /// Exchanges an authorization code for an OAuth2Token.
  ///
  /// This method is called after the user authenticates in the browser
  /// and is redirected back to the app with an authorization [code].
  Future<OAuth2Token> exchangeCodeForToken({required String code}) async {
    final response = await AppHttpClient.instance.post(
      Uri.parse(tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'scope': scope,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to exchange code: ${response.statusCode} ${response.body}',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final token = OAuth2Token(
      accessToken: data['access_token'],
      tokenType: data['token_type'] ?? 'Bearer',
      refreshToken: data['refresh_token'],
      expiry: DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600)),
    );

    // Cache and save the newly acquired token.
    _cachedToken = token;
    await saveTokenToFile(token);

    return token;
  }

  /// Gets a token from cache or storage. Refreshes if it's expired.
  /// Throws an error if no token is available.
  @override
  Future<OAuth2Token> getToken() async {
    _cachedToken ??= await loadTokenFromFile();

    if (_cachedToken == null) {
      throw Exception(
        'Not authenticated. Please initiate authentication flow.',
      );
    }

    if (_cachedToken!.isExpired) {
      debugPrint('Token expired. Attempting to refresh...');
      try {
        _cachedToken = await refreshToken(_cachedToken!);
        await saveTokenToFile(_cachedToken!);
        debugPrint('Token refreshed successfully.');
      } catch (e) {
        await clearStoredToken(); // Clear invalid token
        debugPrint('Token refresh failed: $e');
        throw Exception('Session expired. Please authenticate again.');
      }
    }
    return _cachedToken!;
  }

  /// Refresh an existing OAuth2 token
  Future<OAuth2Token> refreshToken(OAuth2Token token) async {
    final response = await AppHttpClient.instance.post(
      Uri.parse(tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'scope': scope,
        'grant_type': 'refresh_token',
        'refresh_token': token.refreshToken,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to refresh token: ${response.statusCode} ${response.body}',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    if (data['access_token'] == null) {
      throw Exception('Refresh token response missing access_token');
    }

    return OAuth2Token(
      accessToken: data['access_token'],
      tokenType: data['token_type'] ?? 'Bearer',
      // The refresh token might be re-issued, so update if present.
      refreshToken: data['refresh_token'] ?? token.refreshToken,
      expiry: DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600)),
    );
  }

  Future<void> saveTokenToFile(OAuth2Token token) async {
    try {
      final tokenPath = await _getTokenFilePath();
      final file = File(tokenPath);
      final tokenJson = json.encode(token.toJson());
      await file.writeAsString(tokenJson);
    } catch (e) {
      debugPrint('Warning: Failed to save token to file: $e');
    }
  }

  Future<OAuth2Token?> loadTokenFromFile() async {
    try {
      final tokenPath = await _getTokenFilePath();
      final file = File(tokenPath);
      if (!await file.exists()) {
        return null;
      }

      final tokenJson = await file.readAsString();
      final tokenData = json.decode(tokenJson) as Map<String, dynamic>;
      return OAuth2Token.fromJson(tokenData);
    } catch (e) {
      debugPrint('Warning: Failed to load token from file: $e');
      return null;
    }
  }

  Future<void> clearStoredToken() async {
    try {
      _cachedToken = null;
      final tokenPath = await _getTokenFilePath();
      final file = File(tokenPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Warning: Failed to delete token file: $e');
    }
  }

  /// Check if the token exists
  Future<bool> hasToken() async {
    try {
      if (_cachedToken != null) {
        return true;
      }

      final tokenPath = await _getTokenFilePath();
      final file = File(tokenPath);
      if (!await file.exists()) {
        return false;
      }

      final tokenJson = await file.readAsString();
      final tokenData = json.decode(tokenJson) as Map<String, dynamic>;
      _cachedToken = OAuth2Token.fromJson(tokenData);
      return true;
    } catch (e) {
      debugPrint('Token check failed: $e');
      return false;
    }
  }

  Future<bool> hasValidToken() async {
    try {
      if (!await hasToken()) {
        return false;
      }

      return !_cachedToken!.isExpired;
    } catch (e) {
      debugPrint('Valid token check failed: $e');
      return false;
    }
  }

  /// Check if user is currently authenticated and token is not expired.
  Future<bool> isAuthenticated() async {
    try {
      if (!await hasToken()) {
        return false;
      }

      if (!_cachedToken!.isExpired) {
        return true;
      }

      // Try to refresh expired token
      _cachedToken = await refreshToken(_cachedToken!);
      await saveTokenToFile(_cachedToken!);
      return true;
    } catch (e) {
      debugPrint('Authentication check failed: $e');
      await clearStoredToken();
      return false;
    }
  }
}
