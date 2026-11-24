import 'dart:async';

import 'package:flutter/foundation.dart';

/// Start-up status, shown on the loading screen.
///
/// Every awaited step of the boot sequence runs through [step], so a start-up
/// that stalls says which call it is stuck in and for how long, instead of
/// leaving a progress bar at 100%.
class KzBoot {
  const KzBoot._();

  static final ValueNotifier<String> status = ValueNotifier<String>('starting');

  static final List<String> log = <String>[];

  static Timer? _ticker;
  static String? _current;
  static DateTime? _since;

  static void _begin(String label) {
    _current = label;
    _since = DateTime.now();
    status.value = label;
    _ticker?.cancel();
    // after a few seconds the label starts counting, so a stall is visible
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final DateTime? since = _since;
      if (since == null) return;
      final int s = DateTime.now().difference(since).inSeconds;
      if (s >= 3) status.value = '$_current… ${s}s';
    });
  }

  static void _end(String label, Object? error) {
    _ticker?.cancel();
    _ticker = null;
    final int ms = _since == null
        ? 0
        : DateTime.now().difference(_since!).inMilliseconds;
    _since = null;
    final String line = error == null
        ? '$label ok (${ms}ms)'
        : '$label FAILED (${ms}ms): $error';
    log.add(line);
    debugPrint('KzBoot: $line');
    if (error != null) status.value = '$label failed: $error';
  }

  /// Runs [body] as a named boot step. With [timeout], a step that does not
  /// answer gives up instead of holding the splash screen forever.
  static Future<T> step<T>(
    String label,
    Future<T> Function() body, {
    Duration? timeout,
  }) async {
    _begin(label);
    try {
      final Future<T> work = body();
      final T result = timeout == null ? await work : await work.timeout(timeout);
      _end(label, null);
      return result;
    } catch (e) {
      _end(label, e);
      rethrow;
    }
  }

  /// Same, but a step that fails is swallowed: boot carries on and the failure
  /// stays in [log].
  static Future<T?> tryStep<T>(
    String label,
    Future<T> Function() body, {
    Duration? timeout,
  }) async {
    try {
      return await step<T>(label, body, timeout: timeout);
    } catch (_) {
      return null;
    }
  }

  static void mark(String label) {
    _ticker?.cancel();
    _ticker = null;
    _since = null;
    _current = label;
    status.value = label;
    log.add(label);
    debugPrint('KzBoot: $label');
  }
}
