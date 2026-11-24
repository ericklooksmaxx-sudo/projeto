import 'package:material_ui/material_ui.dart' show debugPrint;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class StoragePermissionHandler {
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  Future<void> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return;
    }
    // For Android 10 (API 29) and above, permission is handled by Scoped Storage

    if (await _isAndroid10OrBelow()) {
      if (await Permission.storage.isGranted) {
        // Permission already granted
        debugPrint('Storage permission already granted');
      } else if (await Permission.storage.isDenied) {
        // Request permission if denied
        PermissionStatus status = await Permission.storage.request();
        if (status.isGranted) {
          debugPrint('Storage permission granted');
        } else if (status.isPermanentlyDenied) {
          // The user has permanently denied permission
          openAppSettings();
          debugPrint('Storage permission permanently denied');
        } else {
          debugPrint('Storage permission denied');
        }
      }
    }
  }

  Future<PermissionStatus> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted || status.isPermanentlyDenied) {
      if (status.isPermanentlyDenied) {
        debugPrint('Notification permission permanently denied');
      }
      return status;
    }

    final reqStatus = await Permission.notification.request();
    if (reqStatus.isPermanentlyDenied) {
      debugPrint('Notification permission permanently denied');
    }
    return reqStatus;
  }

  Future<void> requestGalleryPermission() async {
    if (Platform.isAndroid) {
      final sdk = await _getAndroidVersion();

      if (sdk >= 29) {
        PermissionStatus status;

        if (sdk >= 33) {
          // Android 13+: media permission
          status = await Permission.photos.request();
        } else {
          // Android 11–12: usually no permission needed for MediaStore
          debugPrint('Gallery access handled via Scoped Storage (API $sdk)');
          return;
        }

        if (status.isGranted) {
          debugPrint('Gallery permission granted');
        } else if (status.isPermanentlyDenied) {
          openAppSettings();
          debugPrint('Gallery permission permanently denied');
        } else {
          debugPrint('Gallery permission denied');
        }
      } else {
        debugPrint('Use legacy storage permission for Android 10 and below');
      }
    }
  }

  Future<bool> _isAndroid10OrBelow() async {
    if (Platform.isAndroid) {
      final version = await _getAndroidVersion();
      return version <= 29; // Android 10 or below
    }
    return false;
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      return androidInfo.version.sdkInt;
    }
    return 0;
  }
}
