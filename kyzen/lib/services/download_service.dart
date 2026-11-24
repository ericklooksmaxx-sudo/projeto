import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/search_result.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path/path.dart' as path;
import '../decrypt/dlc_dec.dart';
import 'http_client.dart';
import 'notifications/notification_service.dart';
import 'background_service.dart';
import 'download_android.dart';
import '../l10n/context_extensions.dart';
import '../kyzen/gate/pass_service.dart';

class DownloadService extends ChangeNotifier {
  final List<DownloadTask> _downloadQueue = [];
  DownloadTask? _currentTask;

  // used by the ui
  final Map<String, CompletedDownload> _completedItemsMap = {};

  final Function(String) onError;

  /// Called when a download needs the 24 h pass. The UI opens the gate: the
  /// pass itself is the site's, not the app's.
  final void Function(SearchResult item)? onGateRequired;

  DownloadService({required this.onError, this.onGateRequired});

  bool get isDownloading => _currentTask != null;
  double get progress => _currentTask?.progress ?? 0.0;
  String get status => _currentTask?.status ?? '';
  String? get currentItemId => _currentTask?.item.dlcId;
  SearchResult? get currentItem => _currentTask?.item;
  int get queueLength => _downloadQueue.length;
  DateTime? _lastProgressUpdateTime;

  List<CompletedDownload> get completedDownloads =>
      _completedItemsMap.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  final Set<String> _completedDownloads = {};
  final Map<String, List<String>> _downloadedFilePaths = {};
  final Set<String> _failedDownloads = {};
  final Map<String, int?> _downloadSizeCache = {};
  final Map<String, String?> _filePathToIconUrl = {};

  bool isDownloaded(String dlcId) => _completedDownloads.contains(dlcId);
  bool isFailed(String dlcId) => _failedDownloads.contains(dlcId);
  List<String> getDownloadedFilePaths(String dlcId) =>
      _downloadedFilePaths[dlcId] ?? [];

  String? getIconUrlForFile(String filePathOrUri) {
    final normalized = filePathOrUri.replaceAll('\\', '/');
    return _filePathToIconUrl[normalized];
  }

  bool isInQueue(String dlcId) {
    return _downloadQueue.any((task) => task.item.dlcId == dlcId);
  }

  void retryDownload(
    SearchResult item, {
    required DownloadStrings strings,
    List<String>? urlOverride,
    String? variantLabel,
  }) {
    _failedDownloads.remove(item.dlcId);
    downloadItem(
      item,
      strings: strings,
      urlOverride: urlOverride,
      variantLabel: variantLabel,
    );
  }

  int getQueuePosition(String dlcId) {
    return _downloadQueue.indexWhere((task) => task.item.dlcId == dlcId) + 1;
  }

  Future<void> downloadSkinPack(
    SearchResult item, {
    required DownloadStrings strings,
  }) async {
    final skinUrl = item.skinBinaryUrl;
    if (skinUrl == null) return;

    final skinDlcId = '${item.dlcId}_skinpack';

    if (isInQueue(skinDlcId) || currentItemId == skinDlcId) {
      return;
    }

    _failedDownloads.remove(skinDlcId);

    final skinItem = SearchResult(
      title: item.title,
      creator: item.creator,
      creatorId: item.creatorId,
      imageUrl: item.imageUrl,
      description: item.description,
      downloadUrls: [skinUrl],
      dlcId: skinDlcId,
      packType: 'SkinPack',
      extraImages: item.extraImages,
      packIconUrl: item.packIconUrl,
      videoUrl: item.videoUrl,
      changelog: item.changelog,
      isOwned: true,
      price: item.price,
      hasVibrantVisuals: item.hasVibrantVisuals,
      creationDate: item.creationDate,
      lastModifiedDate: item.lastModifiedDate,
      version: item.version,
      skinBinaryUrl: skinUrl,
    );

    await downloadItem(skinItem, strings: strings, urlOverride: [skinUrl]);
  }

  Future<void> downloadItem(
    SearchResult item, {
    required DownloadStrings strings,
    List<String>? urlOverride,
    String? variantLabel,
  }) async {
    // Downloads ride on the free 24 h pass from kyzendlc.xyz. The local flag is
    // only a cache: when it says no, the server is asked before refusing.
    if (!KzPass.instance.active) {
      final bool unlocked = await KzPass.instance.refresh();
      if (!unlocked) {
        onGateRequired?.call(item);
        return;
      }
    }

    final task = DownloadTask(
      item,
      strings: strings,
      urlOverride: urlOverride,
      variantLabel: variantLabel,
    );
    _downloadQueue.add(task);
    notifyListeners();

    // If this is the first item, start service and task immediately
    if (_downloadQueue.length == 1) {
      // Start foreground service in background (don't await, this is to eliminate the slight delay for queue)
      if (!ForegroundDownloadService.isServiceRunning) {
        _ensureForegroundServiceStarted(item);
      }
      _processNextTask();
    }
  }

  Future<void> _ensureForegroundServiceStarted(SearchResult item) async {
    if (!ForegroundDownloadService.isServiceRunning) {
      try {
        final started = await ForegroundDownloadService.startService(
          title: 'Downloading ${item.title}',
          text: 'Download in progress...',
        );

        if (!started) {
          debugPrint(
            'Failed to start foreground service - continuing without it',
          );
          // The downloads will still work, just without foreground service protection
        }
      } catch (e) {
        debugPrint('Error starting foreground service: $e');
        // Continue without foreground service
      }
    }
  }

  Future<void> _processNextTask() async {
    if (_downloadQueue.isEmpty) {
      // Stop foreground service when queue is empty
      try {
        await ForegroundDownloadService.stopService();
      } catch (e) {
        debugPrint('Error stopping foreground service: $e');
      }
      return;
    }

    _currentTask = _downloadQueue.first;
    notifyListeners();

    try {
      await _currentTask!.run(
        onProgress: () {
          notifyListeners();
          _updateForegroundProgress();
        },
        onComplete: (filePaths) {
          final completedItem = _currentTask!.item;
          _completedDownloads.add(completedItem.dlcId);
          _downloadedFilePaths[completedItem.dlcId] = filePaths;

          bool iconAdded = false;
          for (final filePath in filePaths) {
            if (completedItem.packIconUrl != null) {
              final normalizedPath = filePath.replaceAll('\\', '/');
              _filePathToIconUrl[normalizedPath] = completedItem.packIconUrl;
              iconAdded = true;
            }
          }
          if (iconAdded) _saveIconCache();

          _completedItemsMap[completedItem.dlcId] = CompletedDownload(
            item: completedItem,
            timestamp: DateTime.now(),
          );

          // Show completion notification
          NotificationService.showDownloadComplete(
            title: 'Download Complete',
            body: '${completedItem.title} has been downloaded successfully',
          );

          _downloadQueue.remove(_currentTask!);
          _currentTask = null;
          notifyListeners();
          _processNextTask();
        },
      );
    } catch (e) {
      _failedDownloads.add(_currentTask!.item.dlcId);
      final failedItem = _currentTask!.item;

      // Show error notification
      try {
        NotificationService.showDownloadError(
          title: 'Download Failed',
          body: 'Failed to download ${failedItem.title}',
        );
      } catch (notificationError) {
        debugPrint('Error showing notification: $notificationError');
      }

      _downloadQueue.remove(_currentTask!);
      _currentTask = null;
      onError('error: $e');
      notifyListeners();
      _processNextTask();
    }
  }

  void _updateForegroundProgress() {
    if (_currentTask == null) return;

    final now = DateTime.now();
    if (_lastProgressUpdateTime != null &&
        now.difference(_lastProgressUpdateTime!) < const Duration(seconds: 1)) {
      // Skip update if called within 1s of the last update
      // removing the update time "1s" can cause a lot of overhead and slow down the operations
      return;
    }
    _lastProgressUpdateTime = now;

    try {
      final progressPercent = (_currentTask!.progress * 100).round();
      final queueInfo = _downloadQueue.length > 1
          ? ' (${_downloadQueue.length} in queue)'
          : '';

      // Only update if service is actually running
      if (ForegroundDownloadService.isServiceRunning) {
        ForegroundDownloadService.updateService(
          title: 'Downloading ${_currentTask!.item.title}',
          text: '${_currentTask!.status}$queueInfo - $progressPercent%',
        );
      }
    } catch (e) {
      debugPrint('Error updating foreground service progress: $e');
      // Don't let foreground service errors stop the download
    }
  }

  void clearCompletedDownload(String dlcId) {
    _completedItemsMap.remove(dlcId);
    notifyListeners();
  }

  void clearAllCompletedDownloads() {
    _completedItemsMap.clear();
    notifyListeners();
  }

  Future<int?> getDownloadSize(SearchResult item) async {
    // Return cached size if available
    if (_downloadSizeCache.containsKey(item.dlcId)) {
      return _downloadSizeCache[item.dlcId];
    }

    try {
      int totalSize = 0;
      final processedUrls = <String>{};

      for (final url in item.downloadUrls) {
        if (processedUrls.contains(url)) {
          continue;
        }
        processedUrls.add(url);

        final request = http.Request('HEAD', Uri.parse(url));
        request.headers.addAll({
          'User-Agent': 'libhttpclient/1.0.0.0',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'Keep-Alive',
        });

        final response = await AppHttpClient.instance.send(request);

        if (response.statusCode == 200) {
          final contentLength = response.contentLength;
          if (contentLength != null && contentLength > 0) {
            totalSize += contentLength;
          }
        }
      }

      final result = totalSize > 0 ? totalSize : null;
      if (result != null) {
        _downloadSizeCache[item.dlcId] = result;
      }
      return result;
    } catch (e) {
      debugPrint('Error getting download size: $e');
      return null;
    }
  }

  Future<File> _iconCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final subDir = Directory('${dir.path}/kyzen');
    if (!await subDir.exists()) {
      await subDir.create(recursive: true);
    }
    return File('${subDir.path}/file_icon_cache.json');
  }

  Future<void> _saveIconCache() async {
    try {
      final file = await _iconCacheFile();
      await file.writeAsString(
        jsonEncode({'file_path_to_icon': _filePathToIconUrl}),
      );
    } catch (e) {
      debugPrint('Failed to save icon cache: $e');
    }
  }

  Future<void> loadIconCache() async {
    try {
      final file = await _iconCacheFile();
      if (!await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final map = json['file_path_to_icon'] as Map<String, dynamic>? ?? {};
      for (final entry in map.entries) {
        final normalizedKey = entry.key.replaceAll('\\', '/');
        _filePathToIconUrl[normalizedKey] = entry.value as String?;
      }
    } catch (e) {
      debugPrint('Failed to load icon cache: $e');
    }
  }

  Future<void> removeIconCacheEntry(String filePath) async {
    try {
      final normalizedPath = filePath.replaceAll('\\', '/');

      if (_filePathToIconUrl.remove(normalizedPath) != null) {
        await _saveIconCache();
      }
    } catch (e) {
      debugPrint('Failed to remove icon cache entry: $e');
    }
  }

  @override
  void dispose() {
    try {
      ForegroundDownloadService.dispose();
    } catch (e) {
      debugPrint('Error disposing foreground service: $e');
    }
    super.dispose();
  }
}

class CompletedDownload {
  final SearchResult item;
  final DateTime timestamp;

  CompletedDownload({required this.item, required this.timestamp});
}

class ProcessDlcStrings {
  final String extractingZipFile;
  final String decryptingContents;
  final String compressingPack;
  final String cleaningUp;

  ProcessDlcStrings({
    required this.extractingZipFile,
    required this.decryptingContents,
    required this.compressingPack,
    required this.cleaningUp,
  });
}

class DownloadStrings {
  final String startingDownload;
  final String downloadsCompleted;
  final String completed;
  final String downloadFailed;
  final String downloading;
  final String processing;
  final ProcessDlcStrings processDlc;

  DownloadStrings({
    required this.startingDownload,
    required this.downloadsCompleted,
    required this.completed,
    required this.downloadFailed,
    required this.downloading,
    required this.processing,
    required this.processDlc,
  });

  factory DownloadStrings.of(BuildContext context) {
    return DownloadStrings(
      startingDownload: context.l10n.startingDownload,
      downloadsCompleted: context.l10n.downloadsCompleted,
      completed: context.l10n.completed,
      downloadFailed: context.l10n.downloadFailed,
      downloading: context.l10n.downloading,
      processing: context.l10n.processing,
      processDlc: ProcessDlcStrings(
        extractingZipFile: context.l10n.extractingZipFile,
        decryptingContents: context.l10n.decryptingContents,
        compressingPack: context.l10n.compressingPack,
        cleaningUp: context.l10n.cleaningUp,
      ),
    );
  }
}

DownloadStrings createDownloadStrings(BuildContext context) =>
    DownloadStrings.of(context);

class DownloadTask {
  final SearchResult item;
  final DownloadStrings strings;
  final List<String>? urlOverride;
  final String? variantLabel;
  double _progress = 0.0;
  String _status = '';
  Directory? _tempDir;
  int _currentUrlIndex = 0;
  final List<String> _downloadedFilePaths = [];

  DownloadTask(
    this.item, {
    required this.strings,
    this.urlOverride,
    this.variantLabel,
  });

  // uses urlOverride if provided
  List<String> get downloadUrls => urlOverride ?? item.downloadUrls;

  double get progress => _progress;
  String get status => _status;

  Future<void> run({
    required VoidCallback onProgress,
    required void Function(List<String> filePaths) onComplete,
  }) async {
    _progress = 0.0;
    _status = strings.startingDownload;
    onProgress();
    final List<String> allOutputPaths = [];

    final tempBase = await getTemporaryDirectory();
    _tempDir = Directory(
      path.join(tempBase.path, 'mcpack_process_${const Uuid().v4()}'),
    )..createSync();
    final List<Directory> tempDirs = [];

    try {
      // Calculate progress segments
      // 50% for downloads, 50% for processing
      final downloadProgressSegment = 0.5 / downloadUrls.length;

      // Download each URL into its own temp directory
      for (int i = 0; i < downloadUrls.length; i++) {
        _currentUrlIndex = i;
        final url = downloadUrls[i];

        // Create separate temp directory for each download
        final individualTempDir = Directory(
          path.join(_tempDir!.path, 'part_${i + 1}'),
        )..createSync();
        tempDirs.add(individualTempDir);

        final fileName = 'downloaded_dlc.zip';
        final zipFilePath = path.join(individualTempDir.path, fileName);
        _downloadedFilePaths.add(zipFilePath);

        // Download with progress tracking
        await _downloadWithProgress(
          url,
          zipFilePath,
          onProgress: (progress, mbStatus) {
            final baseProgress = downloadProgressSegment * i;
            _progress = baseProgress + (progress * downloadProgressSegment);
            _status =
                '${strings.downloading} ${i + 1}/${downloadUrls.length}: ${(progress * 100).toStringAsFixed(0)}% ($mbStatus)';
            onProgress();
          },
        );
      }

      _progress = 0.5;
      _status = strings.downloadsCompleted;
      onProgress();

      // Process each downloaded file
      for (int i = 0; i < _downloadedFilePaths.length; i++) {
        final processingProgressSegment = 0.5 / _downloadedFilePaths.length;
        final baseProgress = 0.5 + (processingProgressSegment * i);

        // Get the directory for this specific downloaded file
        final processDir = path.dirname(_downloadedFilePaths[i]);

        // Call DLC processing for each file, using its own directory
        final paths = await processDlc(
          _downloadedFilePaths[i],
          processDir,
          itemTitle: item.title,
          variantLabel: variantLabel,
          strings: strings.processDlc,
          onProgress: (progress, message) {
            _progress = baseProgress + (progress * processingProgressSegment);
            _status =
                '${strings.processing} ${i + 1}/${_downloadedFilePaths.length}: $message';
            onProgress();
          },
        );
        allOutputPaths.addAll(paths);
      }

      _progress = 1.0;
      _status = strings.completed;
      onComplete(allOutputPaths);
    } catch (e) {
      _status = '${strings.downloadFailed}: $e';
      onProgress();

      // Clean up temp files if an error occurs
      _cleanupTempFiles();

      rethrow;
    } finally {
      // Clean up temp files when done
      _cleanupTempFiles();
    }
  }

  void _cleanupTempFiles() {
    try {
      // Clean up the parent temp directory, which will also remove all child directories
      if (_tempDir != null && _tempDir!.existsSync()) {
        _tempDir!.deleteSync(recursive: true);
      }
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }

  Future<void> _downloadWithProgress(
    String url,
    String savePath, {
    required Function(double, String) onProgress,
  }) async {
    // Download on Android is done via native since it doesn't have issues with background downloads
    // Download can also be made on the dart side for Android, but some users are experiencing issues with the background, i haven't been able to reproduce the issue
    // but they reported that now the background works fine
    if (Platform.isAndroid) {
      await NativeDownloader.downloadFile(
        url: url,
        savePath: savePath,
        onProgress: onProgress,
      );
      return;
    }

    final httpClient = http.Client();
    final request = http.Request('GET', Uri.parse(url));

    request.headers.addAll({
      'User-Agent': 'libhttpclient/1.0.0.0',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'Keep-Alive',
    });

    final response = await httpClient.send(request);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download part ${_currentUrlIndex + 1}. Status: ${response.statusCode}',
      );
    }

    final expectedMd5B64 = response.headers['content-md5'];
    final contentLength = response.contentLength ?? 0;
    int receivedBytes = 0;
    int lastReportedPercentage = -1; // Track last reported percentage
    final file = File(savePath);
    final sink = file.openWrite();
    final md5Hash = AccumulatorSink<Digest>();
    final md5Sink = md5.startChunkedConversion(md5Hash);

    String formatMB(int bytes) {
      return (bytes / (1024 * 1024)).toStringAsFixed(0);
    }

    try {
      await response.stream.forEach((List<int> chunk) {
        sink.add(chunk);
        md5Sink.add(chunk);
        receivedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = receivedBytes / contentLength;
          final currentPercentage = (progress * 100).floor();

          // update if percentage changed
          // less ui frequent updates to avoid overhead
          if (currentPercentage != lastReportedPercentage) {
            lastReportedPercentage = currentPercentage;
            final statusMessage =
                '${formatMB(receivedBytes)}MB/${formatMB(contentLength)}MB';
            onProgress(progress, statusMessage);
          }
        } else {
          // Fallback
          final statusMessage = '${formatMB(receivedBytes)}MB/?MB';
          onProgress(0.0, statusMessage);
        }
      });

      await sink.flush();
      await sink.close();

      md5Sink.close();
      final digest = md5Hash.events.single;
      final actualMd5B64 = base64Encode(digest.bytes);

      // Verify MD5 checksum
      if (expectedMd5B64 != null && expectedMd5B64.isNotEmpty) {
        if (expectedMd5B64 != actualMd5B64) {
          debugPrint('MD5 checksum mismatch, file may be corrupted.');
          throw Exception('File may be corrupted, redownload the file.');
        }
      }
    } catch (e) {
      debugPrint('Error during download: $e');
      rethrow;
    } finally {
      httpClient.close();
    }
  }
}
