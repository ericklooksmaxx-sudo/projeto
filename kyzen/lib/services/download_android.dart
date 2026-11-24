import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class NativeDownloader {
  static const platform = MethodChannel('xyz.kyzendlc.app/download');
  static final Map<String, Completer<Map<String, dynamic>>> _completers = {};
  static final Map<String, Function(double, String)> _progressCallbacks = {};
  static int _requestIdCounter = 0;
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    platform.setMethodCallHandler((call) async {
      if (call.method == 'onProgress') {
        final requestId = call.arguments['requestId'] as String?;
        final progress = call.arguments['progress'] as double;
        final status = call.arguments['status'] as String;

        if (requestId != null && _progressCallbacks.containsKey(requestId)) {
          _progressCallbacks[requestId]?.call(progress, status);
        } else {
          debugPrint(
            'Warning: No progress callback found for requestId=$requestId',
          );
        }
      } else if (call.method == 'onComplete') {
        final requestId = call.arguments['requestId'] as String?;
        final result = call.arguments['result'] as Map<dynamic, dynamic>?;

        if (requestId != null && _completers.containsKey(requestId)) {
          final completer = _completers[requestId]!;
          if (result != null) {
            completer.complete(Map<String, dynamic>.from(result));
          } else {
            completer.completeError(Exception('No result returned'));
          }
          _completers.remove(requestId);
          _progressCallbacks.remove(requestId);
        }
      } else if (call.method == 'onError') {
        final requestId = call.arguments['requestId'] as String?;
        final error = call.arguments['error'] as String?;

        if (requestId != null && _completers.containsKey(requestId)) {
          _completers[requestId]!.completeError(
            Exception(error ?? 'Unknown error'),
          );
          _completers.remove(requestId);
          _progressCallbacks.remove(requestId);
        }
      }
    });
  }

  static Future<void> downloadFile({
    required String url,
    required String savePath,
    String? expectedMd5,
    required Function(double, String) onProgress,
  }) async {
    init();

    final requestId =
        'req_${_requestIdCounter++}_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<Map<String, dynamic>>();

    _completers[requestId] = completer;
    _progressCallbacks[requestId] = onProgress;

    try {
      await platform.invokeMethod('downloadFile', {
        'requestId': requestId,
        'url': url,
        'savePath': savePath,
        'expectedMd5': expectedMd5,
      });
      await completer.future;
    } on PlatformException catch (e) {
      debugPrint('Native download error: ${e.code} - ${e.message}');
      _completers.remove(requestId);
      _progressCallbacks.remove(requestId);
      throw Exception('Download failed: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected download error: $e');
      _completers.remove(requestId);
      _progressCallbacks.remove(requestId);
      rethrow;
    }
  }

  static Future<void> cancelDownloads() async {
    try {
      await platform.invokeMethod('cancelDownloads');
      _completers.clear();
      _progressCallbacks.clear();
    } catch (e) {
      debugPrint('Error canceling downloads: $e');
    }
  }
}
