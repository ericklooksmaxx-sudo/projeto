import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../api/playfabapi.dart';

class AuthService {
  final PlayFabClient _client;
  String? _playFabId;
  String? _authToken;
  DateTime? _tokenExpiration;

  // prevent concurrent authentication attempts
  bool _isAuthenticating = false;
  // This will store the authentication in progress
  Future<void>? _authenticationFuture;

  // Authentication retry settings
  static const int maxAuthRetries = 3;
  static const int baseRetryDelayMs = 1000;

  AuthService(this._client);

  bool get isAuthenticated => _isTokenValid();

  bool _isTokenValid() {
    if (_authToken == null) return false;
    if (_tokenExpiration != null && DateTime.now().isAfter(_tokenExpiration!)) {
      return false;
    }
    return true;
  }

  Future<void> authenticate() async {
    // If already authenticated, return immediately
    if (isAuthenticated) return;

    // If authentication is already in progress, return the existing Future
    if (_isAuthenticating && _authenticationFuture != null) {
      return _authenticationFuture!;
    }

    // restoring from cache
    final restored = await _client.restoreGuestEntityTokenFromCache();
    if (restored) {
      final cachedExpiration = _client.configGet(
        _client.envKey('GUEST_TOKEN_EXPIRATION'),
      );
      if (cachedExpiration != null) {
        _tokenExpiration = DateTime.parse(cachedExpiration).toLocal();
        _authToken = _client.configGet(_client.envKey('GUEST_ENTITY_TOKEN'));
        return;
      }
    }

    _isAuthenticating = true;
    _authenticationFuture = _performAuthentication();
    return _authenticationFuture!;
  }

  Future<void> _performAuthentication() async {
    int retryCount = 0;
    String? lastErrorMessage;

    while (retryCount <= maxAuthRetries) {
      try {
        final loginResponse = await _client.loginWithCustomId();

        if (!loginResponse.containsKey('PlayFabId')) {
          throw Exception('Failed to login: PlayFabId not found in response');
        }

        _playFabId = loginResponse['PlayFabId'];

        final tokenResponse = await _getEntityTokenWithRetry(_playFabId!);
        if (!tokenResponse.containsKey('EntityToken')) {
          throw Exception('Failed to get entity token');
        }

        _authToken = tokenResponse['EntityToken'];

        if (tokenResponse.containsKey('TokenExpiration')) {
          _tokenExpiration = DateTime.parse(
            tokenResponse['TokenExpiration'],
          ).toLocal();
        }

        return; // Success
      } on PlayFabException catch (e) {
        debugPrint(
          'PlayFab authentication error: ${e.errorCode} - ${e.message}',
        );
        lastErrorMessage = 'PlayFab error ${e.errorCode}: ${e.message}';

        if (e.errorCode == 1199 || e.httpCode == 429) {
          // Rate limit
          int delayMs = _calculateRetryDelay(retryCount);
          debugPrint(
            'Rate limit during auth, waiting ${delayMs}ms before retry ${retryCount + 1}',
          );

          await Future.delayed(Duration(milliseconds: delayMs));
          retryCount++;

          if (retryCount > maxAuthRetries) {
            debugPrint(
              'Authentication failed: Rate limit exceeded after $maxAuthRetries attempts',
            );
            throw Exception(
              'Authentication failed: Rate limit exceeded after $maxAuthRetries attempts. ${e.message}',
            );
          }
          continue;
        } else {
          debugPrint('Authentication failed: PlayFab error ${e.errorCode}');
          throw Exception(
            'Authentication failed: PlayFab error ${e.errorCode} - ${e.message}',
          );
        }
      } catch (e) {
        debugPrint('Authentication error: $e');
        lastErrorMessage = e.toString();

        if (retryCount < maxAuthRetries) {
          int delayMs = _calculateRetryDelay(retryCount);
          debugPrint(
            'Authentication failed, retrying in ${delayMs}ms (attempt ${retryCount + 1})',
          );

          await Future.delayed(Duration(milliseconds: delayMs));
          retryCount++;
          continue;
        }

        throw Exception(
          'Authentication failed after $maxAuthRetries attempts: $lastErrorMessage',
        );
      } finally {
        _isAuthenticating = false;
      }
    }
    debugPrint('Authentication failed after $maxAuthRetries attempts');
    throw Exception(
      'Authentication failed after $maxAuthRetries attempts: ${lastErrorMessage ?? "Unknown error"}',
    );
  }

  Future<Map<String, dynamic>> _getEntityTokenWithRetry(
    String playFabId,
  ) async {
    int retryCount = 0;

    while (retryCount <= maxAuthRetries) {
      try {
        return await _client.getEntityToken(playFabId);
      } on PlayFabException catch (e) {
        if (e.errorCode == 1199 || e.httpCode == 429) {
          // Rate limit
          int delayMs = _calculateRetryDelay(retryCount);
          debugPrint('Rate limit getting entity token, waiting ${delayMs}ms');

          await Future.delayed(Duration(milliseconds: delayMs));
          retryCount++;

          if (retryCount > maxAuthRetries) {
            throw Exception('Failed to get entity token: Rate limit exceeded');
          }
          continue;
        } else {
          rethrow;
        }
      } catch (e) {
        if (retryCount < maxAuthRetries) {
          int delayMs = _calculateRetryDelay(retryCount);
          await Future.delayed(Duration(milliseconds: delayMs));
          retryCount++;
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      'Failed to get entity token after $maxAuthRetries attempts',
    );
  }

  Future<void> forceReAuthenticate() async {
    _authToken = null;
    _tokenExpiration = null;
    _playFabId = null;
    _isAuthenticating = false;
    _authenticationFuture = null;
    _client.clearGuestEntityTokenCache();
    await authenticate();
  }

  int _calculateRetryDelay(int retryCount) {
    int exponentialDelay = baseRetryDelayMs * (1 << retryCount); // 2^retryCount
    int maxDelay = 30000; // Max 30 seconds

    int jitter = (math.Random().nextDouble() * 1000).round();

    return math.min(exponentialDelay + jitter, maxDelay);
  }

  String? get authToken => _authToken;
  String? get playFabId => _playFabId;
  DateTime? get tokenExpiration => _tokenExpiration;
}
