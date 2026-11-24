import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _downloadNotificationId = 1000;

  static bool get _isSupported => Platform.isAndroid || Platform.isWindows;

  static Future<void> initialize() async {
    if (!_isSupported) return;

    try {
      const androidSettings = AndroidInitializationSettings('ic_stat_notify');

      const windowsSettings = WindowsInitializationSettings(
        appName: 'Kyzen',
        appUserModelId: 'blc.Kyzen',
        guid: '98fc8dc3-c018-4bdc-ad1c-baa3a5623ba4',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        windows: windowsSettings,
      );

      await _notifications.initialize(settings: initSettings);
    } catch (_) {}
  }

  static Future<void> showDownloadComplete({
    required String title,
    required String body,
  }) async {
    if (!_isSupported) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'download_complete_channel',
        'Download Complete',
        channelDescription: 'Download completion notifications',
      );

      final windowsDetails = WindowsNotificationDetails(
        images: [
          WindowsImage(
            WindowsImage.getAssetUri('assets/win_icon_notf.png'),
            altText: 'Kyzen',
            placement: WindowsImagePlacement.appLogoOverride,
          ),
        ],
      );

      final details = NotificationDetails(
        android: androidDetails,
        windows: windowsDetails,
      );

      await _notifications.show(
        id: _downloadNotificationId + 1,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }

  static Future<void> showDownloadError({
    required String title,
    required String body,
  }) async {
    if (!_isSupported) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'download_error_channel',
        'Download Errors',
        channelDescription: 'Download error notifications',
        importance: Importance.high,
        priority: Priority.high,
      );

      final windowsDetails = WindowsNotificationDetails(
        images: [
          WindowsImage(
            WindowsImage.getAssetUri('assets/win_icon_notf.png'),
            altText: 'Kyzen',
            placement: WindowsImagePlacement.appLogoOverride,
          ),
        ],
      );

      final details = NotificationDetails(
        android: androidDetails,
        windows: windowsDetails,
      );

      await _notifications.show(
        id: _downloadNotificationId + 2,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!_isSupported) return;
    try {
      await _notifications.cancelAll();
    } catch (_) {}
  }
}
