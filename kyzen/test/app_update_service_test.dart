import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyzen/models/update_info.dart';
import 'package:kyzen/services/app_update_service.dart';
import 'package:kyzen/services/app_version.dart';

// flutter test test/app_update_service_test.dart
void main() {
  // UpdateInfo / PlatformDownload JSON parsing
  group('UpdateInfo.fromJson', () {
    late Map<String, dynamic> sampleJson;

    setUp(() {
      sampleJson =
          jsonDecode('''
      {
        "latest_version": "2.0.0",
        "changelog": "New features and bug fixes",
        "platforms": {
          "android": {
            "download_url": "https://example.com/app.apk",
            "is_direct_download": true,
            "file_name": "app-2.0.0.apk"
          },
          "linux": {
            "download_url": "https://example.com/app.tar.gz",
            "is_direct_download": true,
            "file_name": "app-2.0.0-linux.tar.gz"
          },
          "windows": {
            "download_url": "https://example.com/app.zip",
            "is_direct_download": true,
            "file_name": "app-2.0.0-windows-x64.zip",
            "zip_password": "kyzen"
          },
          "windows_arm64": {
            "download_url": "https://github.com/user/repo/releases/tag/v2.0.0",
            "is_direct_download": false,
            "file_name": "app-2.0.0-windows-arm64.zip"
          }
        }
      }
      ''')
              as Map<String, dynamic>;
    });

    test('parses latest_version correctly', () {
      final info = UpdateInfo.fromJson(sampleJson);
      expect(info.latestVersion, '2.0.0');
    });

    test('parses changelog correctly', () {
      final info = UpdateInfo.fromJson(sampleJson);
      expect(info.changelog, 'New features and bug fixes');
    });

    test('parses all 4 platform entries', () {
      final info = UpdateInfo.fromJson(sampleJson);
      expect(info.platforms.length, 4);
      expect(
        info.platforms.keys,
        containsAll(['android', 'linux', 'windows', 'windows_arm64']),
      );
    });

    test('parses PlatformDownload fields for android', () {
      final info = UpdateInfo.fromJson(sampleJson);
      final android = info.platforms['android']!;
      expect(android.downloadUrl, 'https://example.com/app.apk');
      expect(android.isDirectDownload, true);
      expect(android.fileName, 'app-2.0.0.apk');
    });

    test('parses is_direct_download=false for windows_arm64', () {
      final info = UpdateInfo.fromJson(sampleJson);
      final winArm = info.platforms['windows_arm64']!;
      expect(winArm.isDirectDownload, false);
      expect(winArm.downloadUrl, contains('github.com'));
    });

    test('defaults is_direct_download to false when missing', () {
      sampleJson['platforms']['android']['is_direct_download'] = null;
      final info = UpdateInfo.fromJson(sampleJson);
      expect(info.platforms['android']!.isDirectDownload, false);
    });

    test('parses zip_password when present', () {
      final info = UpdateInfo.fromJson(sampleJson);
      expect(info.platforms['windows']!.zipPassword, 'kyzen');
    });

    test('zipPassword is null when not present in JSON', () {
      final info = UpdateInfo.fromJson(sampleJson);
      expect(info.platforms['android']!.zipPassword, isNull);
      expect(info.platforms['linux']!.zipPassword, isNull);
    });
  });

  // PlatformDownload.fromJson edge cases
  group('PlatformDownload.fromJson', () {
    test('parses minimal valid JSON', () {
      final pd = PlatformDownload.fromJson({
        'download_url': 'https://example.com/file.zip',
        'file_name': 'file.zip',
      });
      expect(pd.downloadUrl, 'https://example.com/file.zip');
      expect(pd.fileName, 'file.zip');
      expect(pd.isDirectDownload, false); // default
      expect(pd.zipPassword, isNull); // default
    });
  });

  // UpdateResult
  group('UpdateResult', () {
    test('.none() sets updateAvailable to false', () {
      const result = UpdateResult.none();
      expect(result.updateAvailable, false);
      expect(result.latestVersion, isNull);
      expect(result.changelog, isNull);
      expect(result.platformDownload, isNull);
    });

    test('constructor sets all fields', () {
      const download = PlatformDownload(
        downloadUrl: 'https://example.com/file.zip',
        isDirectDownload: true,
        fileName: 'file.zip',
      );
      const result = UpdateResult(
        updateAvailable: true,
        latestVersion: '3.0.0',
        changelog: 'Changelog text',
        platformDownload: download,
      );
      expect(result.updateAvailable, true);
      expect(result.latestVersion, '3.0.0');
      expect(result.changelog, 'Changelog text');
      expect(result.platformDownload, isNotNull);
    });
  });

  // Version comparison (AppUpdateService.isNewerVersion)
  group('AppUpdateService.isNewerVersion (current = ${AppVersion.string})', () {
    // newer versions
    test('returns true for higher major', () {
      expect(
        AppUpdateService.isNewerVersion('${AppVersion.major + 1}.0.0'),
        true,
      );
    });

    test('returns true for higher minor', () {
      expect(
        AppUpdateService.isNewerVersion(
          '${AppVersion.major}.${AppVersion.minor + 1}.0',
        ),
        true,
      );
    });

    test('returns true for higher patch', () {
      expect(
        AppUpdateService.isNewerVersion(
          '${AppVersion.major}.${AppVersion.minor}.${AppVersion.ultraminor + 1}',
        ),
        true,
      );
    });

    test('returns true for much higher version', () {
      expect(AppUpdateService.isNewerVersion('10.20.30'), true);
    });

    // same version
    test('returns false for same version', () {
      expect(AppUpdateService.isNewerVersion(AppVersion.string), false);
    });

    // older versions
    test('returns false for lower major', () {
      expect(AppUpdateService.isNewerVersion('0.9.9'), false);
    });

    test('returns false for lower minor', () {
      expect(
        AppUpdateService.isNewerVersion(
          '${AppVersion.major}.${AppVersion.minor - 1}.9',
        ),
        false,
      );
    });

    test('returns false for lower patch', () {
      expect(
        AppUpdateService.isNewerVersion(
          '${AppVersion.major}.${AppVersion.minor}.${AppVersion.ultraminor - 1}',
        ),
        false,
      );
    });

    // invalid versions
    test('returns false for malformed version string', () {
      expect(AppUpdateService.isNewerVersion('abc'), false);
    });

    test('returns false for empty string', () {
      expect(AppUpdateService.isNewerVersion(''), false);
    });

    test('returns false for version with only two segments', () {
      expect(AppUpdateService.isNewerVersion('1.5'), false);
    });

    test('handles version with extra segments', () {
      expect(AppUpdateService.isNewerVersion('2.0.0.1'), true);
    });
  });

  group('Full JSON', () {
    test('parses the exact schema from example_sample_update_service.json', () {
      const rawJson = '''
      {
        "latest_version": "1.5.0",
        "changelog": "## What's New in v1.5.0\\n\\n- Added in-app update support",
        "platforms": {
          "android": {
            "download_url": "https://example.com/releases/v1.5.0/kyzen-1.5.0.apk",
            "is_direct_download": true,
            "file_name": "kyzen-1.5.0.apk"
          },
          "linux": {
            "download_url": "https://example.com/releases/v1.5.0/kyzen-1.5.0-linux.tar.gz",
            "is_direct_download": true,
            "file_name": "kyzen-1.5.0-linux.tar.gz"
          },
          "windows": {
            "download_url": "https://example.com/releases/v1.5.0/kyzen-1.5.0-windows-x64.zip",
            "is_direct_download": true,
            "file_name": "kyzen-1.5.0-windows-x64.zip"
          },
          "windows_arm64": {
            "download_url": "https://github.com/user/repo/releases/tag/v1.5.0",
            "is_direct_download": false,
            "file_name": "kyzen-1.5.0-windows-arm64.zip"
          }
        }
      }
      ''';

      final json = jsonDecode(rawJson) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(json);

      expect(info.latestVersion, '1.5.0');
      expect(info.changelog, contains("What's New"));
      expect(info.platforms.length, 4);

      // Verify each platform
      expect(info.platforms['android']!.isDirectDownload, true);
      expect(info.platforms['android']!.fileName, endsWith('.apk'));

      expect(info.platforms['linux']!.isDirectDownload, true);
      expect(info.platforms['linux']!.fileName, contains('linux'));

      expect(info.platforms['windows']!.isDirectDownload, true);
      expect(info.platforms['windows']!.fileName, contains('x64'));

      expect(info.platforms['windows_arm64']!.isDirectDownload, false);
      expect(info.platforms['windows_arm64']!.fileName, contains('arm64'));
    });
  });

  group('AppUpdateService.installApk', () {
    test('returns false when not on Android', () async {
      final success = await AppUpdateService.installApk('dummy_path.apk');
      expect(success, false);
    });
  });
}
