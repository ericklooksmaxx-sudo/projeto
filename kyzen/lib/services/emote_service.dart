import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../decrypt/persona_skin_helper.dart';
import '../models/bedrock_animation.dart';
import '../models/search_result.dart';

class EmoteAnimationData {
  final BedrockAnimation animation;
  final String animationName;

  const EmoteAnimationData({
    required this.animation,
    required this.animationName,
  });
}

class EmoteData {
  final Directory tempDir;
  final List<String> extractedFolders;

  final EmoteAnimationData? animationData;

  EmoteData({
    required this.tempDir,
    required this.extractedFolders,
    this.animationData,
  });

  void dispose() {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (e) {
      debugPrint('Error cleaning up emote temp dir: $e');
    }
  }
}

class EmoteService extends ChangeNotifier {
  EmoteData? _emoteData;
  bool _isLoading = false;
  double _progress = 0.0;
  String? _error;

  bool get isLoading => _isLoading;
  double get progress => _progress;
  String? get error => _error;
  EmoteData? get emoteData => _emoteData;
  bool get hasEmote => _emoteData != null;

  /// Downloads, extracts, decrypts, and parses the emote animation.
  /// When complete, [emoteData.animationData] is ready to pass to EmotePlayer.
  Future<void> loadEmote(SearchResult item) async {
    if (_isLoading) return;

    _disposeCurrentEmote();
    _error = null;
    _isLoading = true;
    _progress = 0.0;
    notifyListeners();

    try {
      final tempBase = await getTemporaryDirectory();
      final tempDir = Directory(
        path.join(tempBase.path, 'emote_preview_${const Uuid().v4()}'),
      )..createSync();

      try {
        final downloadUrl =
            item.personaBinaryUrl ??
            (item.downloadUrls.isNotEmpty ? item.downloadUrls.first : null);
        if (downloadUrl == null) {
          throw Exception('No emote download URL found for this item.');
        }

        final zipPath = path.join(tempDir.path, 'emote.zip');
        await downloadZip(
          url: downloadUrl,
          savePath: zipPath,
          onProgress: (p) {
            _progress = p * 0.5;
            notifyListeners();
          },
        );

        _progress = 0.5;
        notifyListeners();

        final nestedFolders = await extractAndDecryptPersonaZip(
          zipPath: zipPath,
          outputDir: tempDir.path,
          onProgress: (p) {
            _progress = 0.6 + p * 0.35;
            notifyListeners();
          },
        );

        final animationData = await _parseEmoteAnimation(nestedFolders.first);

        _progress = 1.0;
        _emoteData = EmoteData(
          tempDir: tempDir,
          extractedFolders: nestedFolders,
          animationData: animationData,
        );
      } catch (e) {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        rethrow;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('EmoteService: error loading emote: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reads the .meta.json in [folderPath], finds the animation file listed in
  /// animation_sources, then parses and returns [EmoteAnimationData].
  Future<EmoteAnimationData?> _parseEmoteAnimation(String folderPath) async {
    try {
      final dir = Directory(folderPath);

      final metaFile = dir.listSync().whereType<File>().firstWhere(
        (f) => f.path.endsWith('.meta.json'),
        orElse: () => throw Exception('No .meta.json found in $folderPath'),
      );

      final metaJson =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;

      final animationSources = metaJson['animation_sources'] as List<dynamic>?;
      if (animationSources == null || animationSources.isEmpty) {
        throw Exception('No animation_sources in meta.json');
      }

      final source = animationSources.first as Map<String, dynamic>;
      final animationName = source['name'] as String;
      final animationFile = source['animationFile'] as String;

      final animFile = File(path.join(folderPath, animationFile));
      if (!animFile.existsSync()) {
        throw Exception('Animation file not found: ${animFile.path}');
      }

      final animJson =
          jsonDecode(await animFile.readAsString()) as Map<String, dynamic>;

      final animation = parseBedrockAnimation(
        animJson,
        animationName: animationName,
      );

      return EmoteAnimationData(
        animation: animation,
        animationName: animationName,
      );
    } catch (e) {
      debugPrint('EmoteService: failed to parse emote animation: $e');
      return null;
    }
  }

  void clearEmote({bool notify = true}) {
    _disposeCurrentEmote();
    _progress = 0.0;
    _error = null;
    if (notify) notifyListeners();
  }

  void _disposeCurrentEmote() {
    _emoteData?.dispose();
    _emoteData = null;
  }

  @override
  void dispose() {
    _disposeCurrentEmote();
    super.dispose();
  }
}
