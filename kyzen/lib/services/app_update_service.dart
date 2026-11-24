import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/update_info.dart';
import 'app_version.dart';
import 'http_client.dart';
import 'settings_service.dart';

class AppUpdateService {
  static const _endpoint = String.fromEnvironment('UPDATE_URL');
  static bool _missingUrlWarned = false;

  // get platform to know what binaries to download
  static String? get _platformKey {
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) {
      final abi = Abi.current();
      if (abi == Abi.windowsArm64) return 'windows_arm64';
      return 'windows';
    }
    return null;
  }

  static Future<UpdateResult> checkForUpdate() async {
    if (_endpoint.isEmpty) {
      if (!_missingUrlWarned) {
        _missingUrlWarned = true;
        debugPrint(
          '[AppUpdateService] UPDATE_URL is not set. '
          'Build with --dart-define=UPDATE_URL=<url> or '
          '--dart-define-from-file=.env.json. '
          'Skipping update check.',
        );
      }
      return const UpdateResult.none();
    }

    try {
      final response = await AppHttpClient.instance
          .get(
            Uri.parse(_endpoint),
            headers: {'User-Agent': AppVersion.userAgent},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          '[AppUpdateService] Failed to fetch update info: '
          'HTTP ${response.statusCode}',
        );
        return const UpdateResult.none();
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final updateInfo = UpdateInfo.fromJson(json);

      if (!isNewerVersion(updateInfo.latestVersion)) {
        return const UpdateResult.none();
      }

      final platform = _platformKey;
      if (platform == null) {
        debugPrint(
          '[AppUpdateService] Current platform is not supported for updates.',
        );
        return const UpdateResult.none();
      }

      final platformDownload = updateInfo.platforms[platform];
      if (platformDownload == null) {
        debugPrint(
          '[AppUpdateService] No download entry for platform "$platform".',
        );
        return const UpdateResult.none();
      }

      return UpdateResult(
        updateAvailable: true,
        latestVersion: updateInfo.latestVersion,
        changelog: updateInfo.changelog,
        platformDownload: platformDownload,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for update: $e');
      return const UpdateResult.none();
    }
  }

  static Future<String> downloadUpdate(
    PlatformDownload info, {
    required void Function(double progress, String status) onProgress,
  }) async {
    final downloadDir = await SettingsService.instance.getDownloadPath();
    final isContentUri = downloadDir.startsWith('content://');

    final httpClient = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(info.downloadUrl));
      request.headers.addAll({
        'User-Agent': AppVersion.userAgent,
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'Keep-Alive',
      });

      final response = await httpClient.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download update. Status: ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength ?? 0;
      int receivedBytes = 0;
      int lastReportedPercentage = -1;

      void reportProgress(int chunkLength) {
        receivedBytes += chunkLength;
        if (contentLength > 0) {
          final progress = receivedBytes / contentLength;
          final currentPercentage = (progress * 100).floor();

          if (currentPercentage != lastReportedPercentage) {
            lastReportedPercentage = currentPercentage;
            final statusMessage =
                '${_formatMB(receivedBytes)}/${_formatMB(contentLength)}';
            onProgress(progress, statusMessage);
          }
        } else {
          onProgress(0.0, '${_formatMB(receivedBytes)}/?');
        }
      }

      // android only
      if (isContentUri) {
        final List<int> bytesList = [];
        await response.stream.forEach((List<int> chunk) {
          bytesList.addAll(chunk);
          reportProgress(chunk.length);
        });

        const storageChannel = MethodChannel('xyz.kyzendlc.app/storage');
        final String? writtenUri = await storageChannel
            .invokeMethod<String>('writeFileBytes', {
              'uri': downloadDir,
              'fileName': info.fileName,
              'bytes': Uint8List.fromList(bytesList),
            });

        if (writtenUri == null || writtenUri.isEmpty) {
          throw Exception(
            'Failed to write update file to custom download folder.',
          );
        }

        return writtenUri;
      } else {
        final savePath = path.join(downloadDir, info.fileName);
        String actualSavePath = savePath;

        try {
          final file = File(savePath);
          final dir = file.parent;
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          // File.openWrite() opens lazily, so we test-open with file.open() to catch PathAccessException immediately
          // can rarely occur on android
          final raf = await file.open(mode: FileMode.write);
          await raf.close();
        } catch (e) {
          if (e is FileSystemException || e is PathAccessException) {
            debugPrint(
              '[AppUpdateService] $e, Falling back to temporary directory.',
            );
            final tempDir = await getTemporaryDirectory();
            actualSavePath = path.join(tempDir.path, info.fileName);
            final fallbackFile = File(actualSavePath);
            final tempParent = fallbackFile.parent;
            if (!await tempParent.exists()) {
              await tempParent.create(recursive: true);
            }
          } else {
            rethrow;
          }
        }

        final file = File(actualSavePath);
        final sink = file.openWrite();

        try {
          await response.stream.forEach((List<int> chunk) {
            sink.add(chunk);
            reportProgress(chunk.length);
          });

          await sink.flush();
        } catch (e) {
          debugPrint('[AppUpdateService] Error writing download stream: $e');
          try {
            final partialFile = File(actualSavePath);
            if (await partialFile.exists()) {
              await partialFile.delete();
            }
          } catch (_) {}
          rethrow;
        } finally {
          await sink.close();
        }

        return actualSavePath;
      }
    } finally {
      httpClient.close();
    }
  }

  // open on browser if the download link is not a direct link
  static Future<void> openInBrowser(PlatformDownload info) async {
    final uri = Uri.parse(info.downloadUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('[AppUpdateService] Could not launch ${info.downloadUrl}');
    }
  }

  // install only supports android for now
  static Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      debugPrint(
        '[AppUpdateService] APK installation is only supported on Android.',
      );
      return false;
    }

    try {
      const storageChannel = MethodChannel('xyz.kyzendlc.app/storage');
      final bool? success = await storageChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return success ?? false;
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to launch installer: $e');
      return false;
    }
  }

  @visibleForTesting
  static bool isNewerVersion(String remote) {
    final remoteParts = remote.split('.').map(int.tryParse).toList();
    if (remoteParts.length < 3 || remoteParts.any((p) => p == null)) {
      debugPrint(
        '[AppUpdateService] Could not parse remote version "$remote".',
      );
      return false;
    }

    final rMajor = remoteParts[0]!;
    final rMinor = remoteParts[1]!;
    final rPatch = remoteParts[2]!;

    if (rMajor != AppVersion.major) return rMajor > AppVersion.major;
    if (rMinor != AppVersion.minor) return rMinor > AppVersion.minor;
    return rPatch > AppVersion.ultraminor;
  }

  static String _formatMB(int bytes) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
