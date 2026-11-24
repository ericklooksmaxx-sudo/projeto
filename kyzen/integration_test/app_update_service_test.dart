import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kyzen/models/update_info.dart';
import 'package:kyzen/services/app_update_service.dart';
import 'package:kyzen/services/app_version.dart';

// flutter test integration_test/app_update_service_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Validate the sample JSON
  group('example_sample_update_service.json', () {
    testWidgets('is valid JSON and matches the expected schema', (
      tester,
    ) async {
      final file = File('example_sample_update_service.json');
      expect(
        file.existsSync(),
        true,
        reason: 'Sample JSON file should exist at project root',
      );

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // Top-level fields
      expect(json.containsKey('latest_version'), true);
      expect(json.containsKey('changelog'), true);
      expect(json.containsKey('platforms'), true);

      final platforms = json['platforms'] as Map<String, dynamic>;
      expect(platforms.containsKey('android'), true);
      expect(platforms.containsKey('linux'), true);
      expect(platforms.containsKey('windows'), true);
      expect(platforms.containsKey('windows_arm64'), true);

      for (final entry in platforms.entries) {
        final platform = entry.value as Map<String, dynamic>;
        expect(
          platform.containsKey('download_url'),
          true,
          reason: '${entry.key} should have download_url',
        );
        expect(
          platform.containsKey('is_direct_download'),
          true,
          reason: '${entry.key} should have is_direct_download',
        );
        expect(
          platform.containsKey('file_name'),
          true,
          reason: '${entry.key} should have file_name',
        );
      }

      final updateInfo = UpdateInfo.fromJson(json);
      expect(updateInfo.platforms.length, 4);
    });
  });

  // Version comparison with AppVersion
  group('Version comparison against actual AppVersion', () {
    testWidgets('current version string is well-formed', (tester) async {
      expect(
        AppVersion.string,
        '${AppVersion.major}.${AppVersion.minor}.${AppVersion.ultraminor}',
      );
    });

    testWidgets('same version is not newer', (tester) async {
      expect(AppUpdateService.isNewerVersion(AppVersion.string), false);
    });

    testWidgets('bumped patch is newer', (tester) async {
      final bumped =
          '${AppVersion.major}.${AppVersion.minor}.${AppVersion.ultraminor + 1}';
      expect(AppUpdateService.isNewerVersion(bumped), true);
    });

    testWidgets('bumped minor is newer', (tester) async {
      final bumped = '${AppVersion.major}.${AppVersion.minor + 1}.0';
      expect(AppUpdateService.isNewerVersion(bumped), true);
    });

    testWidgets('bumped major is newer', (tester) async {
      final bumped = '${AppVersion.major + 1}.0.0';
      expect(AppUpdateService.isNewerVersion(bumped), true);
    });

    testWidgets('version 0.0.0 is not newer', (tester) async {
      expect(AppUpdateService.isNewerVersion('0.0.0'), false);
    });
  });

  // checkForUpdate with no UPDATE_URL set
  group('checkForUpdate without UPDATE_URL', () {
    testWidgets('returns UpdateResult.none when UPDATE_URL is empty', (
      tester,
    ) async {
      final result = await AppUpdateService.checkForUpdate();
      expect(result.updateAvailable, false);
      expect(result.latestVersion, isNull);
      expect(result.changelog, isNull);
      expect(result.platformDownload, isNull);
    });
  });

  // Platform
  group('Platform detection', () {
    testWidgets('current platform is supported', (tester) async {
      final isSupported =
          Platform.isAndroid || Platform.isLinux || Platform.isWindows;
      expect(
        isSupported,
        true,
        reason: 'Tests should run on a supported platform',
      );
    });
  });
}
