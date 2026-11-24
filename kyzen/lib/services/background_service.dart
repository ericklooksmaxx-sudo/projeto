import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// The callback function should be a top-level or static function
@pragma('vm:entry-point')
void startDownloadCallback() {
  FlutterForegroundTask.setTaskHandler(DownloadTaskHandler());
}

bool get needsForegroundService {
  // we are never gonna support ios
  return Platform.isAndroid;
}

class DownloadTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain('ping');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isStoppedByUser) async {}

  @override
  void onNotificationPressed() {
    // Handle notification tap - bring app to foreground
    FlutterForegroundTask.launchApp('/');
  }
}

class ForegroundDownloadService {
  static bool _isServiceRunning = false;

  static bool get isServiceRunning =>
      needsForegroundService && _isServiceRunning;

  static Future<void> initialize() async {
    if (!needsForegroundService) return;

    // Initialize foreground task
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_download_service',
        channelName: 'Download Service',
        channelDescription: 'Keeps downloads running in background',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          2000,
        ), // Update every 2 seconds
        allowWifiLock: true,
      ),
    );

    // Setup listener for messages from foreground service
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  static Future<bool> startService({
    required String title,
    required String text,
  }) async {
    if (!needsForegroundService) {
      // On desktop, just mark as "running" but don't actually start anything
      _isServiceRunning = true;
      return true;
    }

    if (_isServiceRunning) return true;

    try {
      // Check if service is already running
      if (await FlutterForegroundTask.isRunningService) {
        _isServiceRunning = true;
        return true;
      }

      // Request notification permission first
      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        final granted =
            await FlutterForegroundTask.requestNotificationPermission();
        if (granted != NotificationPermission.granted) {
          debugPrint('Notification permission not granted');
          return false;
        }
      }

      // Check battery optimization
      final isIgnoringBatteryOptimizations =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoringBatteryOptimizations) {
        debugPrint(
          'Battery optimization is enabled, this may affect background performance, exclude this app from battery optimization in your device settings',
        );
      }

      final serviceRequestResult = await FlutterForegroundTask.startService(
        serviceId: 256,
        serviceTypes: [
          ForegroundServiceTypes.dataSync,
        ], // Required for Android 14+
        notificationTitle: title,
        notificationText: text,
        callback: startDownloadCallback,
        notificationIcon: const NotificationIcon(
          metaDataName: 'xyz.kyzendlc.app.NOTIFY_ICON',
        ),
      );

      final success = serviceRequestResult is ServiceRequestSuccess;

      if (success) {
        _isServiceRunning = true;
        debugPrint('Foreground service started successfully');

        // Initialize communication port after service starts
        FlutterForegroundTask.initCommunicationPort();
      } else {
        final failure = serviceRequestResult as ServiceRequestFailure;
        debugPrint('Failed to start foreground service: ${failure.error}');

        if (failure.error is ServiceNotInitializedException) {
          debugPrint('Service not initialized - call initialize() first');
        } else if (failure.error is ServiceAlreadyStartedException) {
          debugPrint('Service already started');
          _isServiceRunning = true;
          return true;
        } else {
          debugPrint('Unknown error: ${failure.error.runtimeType}');
        }
      }

      return success;
    } catch (e) {
      debugPrint('Exception starting foreground service: $e');
      return false;
    }
  }

  static Future<void> updateService({
    required String title,
    required String text,
  }) async {
    if (!needsForegroundService || !_isServiceRunning) return;

    try {
      final result = await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );

      if (result is ServiceRequestFailure) {
        debugPrint('Failed to update service: ${result.error}');
      }
    } catch (e) {
      debugPrint('Exception updating service: $e');
    }
  }

  static Future<bool> stopService() async {
    if (!needsForegroundService) {
      // On desktop, just mark as stopped
      _isServiceRunning = false;
      return true;
    }

    if (!_isServiceRunning) return true;

    try {
      final result = await FlutterForegroundTask.stopService();
      final success = result is ServiceRequestSuccess;

      if (success) {
        _isServiceRunning = false;
        debugPrint('Foreground service stopped');
      } else {
        final failure = result as ServiceRequestFailure;
        debugPrint('Failed to stop service: ${failure.error}');
      }

      return success;
    } catch (e) {
      debugPrint('Exception stopping service: $e');
      return false;
    }
  }

  static void _onReceiveTaskData(Object data) {
    if (data == 'ping') {
      // Service is alive
    }
  }

  static void dispose() {
    if (!needsForegroundService) return;
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
  }
}
