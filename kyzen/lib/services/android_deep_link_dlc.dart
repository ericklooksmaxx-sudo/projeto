import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Deep links from Android:
///  * `minecraft://openStore?showStoreOffer=<uuid>` and friends — open a pack;
///  * `kyzen://unlock?c=<code>` — the gate handing the 24 h pass back from the
///    browser.
///
/// A link can land before Flutter has registered its handler (cold start), so
/// the activity buffers the last one and this service asks for it on start.
class DeepLinkService {
  static const MethodChannel _channel = MethodChannel(
    'xyz.kyzendlc.app/deeplink',
  );

  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  Function(String uuid)? _onDeepLinkReceived;
  Function(String code)? _onUnlockReceived;
  bool _isInitialized = false;
  String? _lastUnlockCode;

  void initialize({
    required Function(String uuid) onDeepLinkReceived,
    Function(String code)? onUnlockReceived,
  }) {
    if (!Platform.isAndroid) {
      return;
    }

    // Prevent double initialization
    if (_isInitialized) return;
    _isInitialized = true;

    _onDeepLinkReceived = onDeepLinkReceived;
    _onUnlockReceived = onUnlockReceived;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDeepLink':
          _handleDeepLink(call.arguments);
          break;
        case 'onUnlock':
          _handleUnlock(call.arguments);
          break;
      }
      return null;
    });

    // whatever arrived while Dart was still booting
    _drainPending();
  }

  Future<void> _drainPending() async {
    try {
      final dynamic pending = await _channel.invokeMethod<dynamic>(
        'consumePending',
      );
      if (pending is Map) {
        final uuid = pending['uuid'] as String?;
        final code = pending['code'] as String?;
        if (code != null && code.isNotEmpty) _handleUnlock({'code': code});
        if (uuid != null && uuid.isNotEmpty) _handleDeepLink({'uuid': uuid});
      }
    } catch (e) {
      debugPrint('DeepLinkService: no pending link ($e)');
    }
  }

  void _handleDeepLink(dynamic arguments) {
    if (arguments is Map) {
      final uuid = arguments['uuid'] as String?;
      if (uuid != null && uuid.isNotEmpty && _onDeepLinkReceived != null) {
        _onDeepLinkReceived!(uuid);
      }
    }
  }

  void _handleUnlock(dynamic arguments) {
    if (arguments is! Map) return;
    final code = arguments['code'] as String?;
    if (code == null || code.isEmpty) return;
    // the same intent can be delivered twice (invokeMethod + pending buffer)
    if (code == _lastUnlockCode) return;
    _lastUnlockCode = code;
    _onUnlockReceived?.call(code);
  }

  void dispose() {
    _onDeepLinkReceived = null;
    _onUnlockReceived = null;
    _isInitialized = false;
  }
}
