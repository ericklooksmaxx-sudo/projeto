import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../3d_skins/persona.dart';
import '../3d_skins/skin_model_data.dart';
import '../decrypt/persona_skin_helper.dart';
import '../models/search_result.dart';

class SkinData {
  final Directory tempDir;
  final List<String> extractedFolders;
  final List<SkinPack> skinPacks;
  final List<PersonaPiece> personaPieces;

  SkinData({
    required this.tempDir,
    required this.extractedFolders,
    required this.skinPacks,
    this.personaPieces = const [],
  });

  SkinPack? get primaryPack => skinPacks.isNotEmpty ? skinPacks.first : null;
  PersonaPiece? get primaryPersonaPiece =>
      personaPieces.isNotEmpty ? personaPieces.first : null;
  bool get isPersona => personaPieces.isNotEmpty && skinPacks.isEmpty;

  void dispose() {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (e) {
      debugPrint('Error cleaning up skin temp dir: $e');
    }
  }
}

class SkinService extends ChangeNotifier {
  SkinData? _skinData;
  bool _isLoading = false;
  double _progress = 0.0;
  String? _error;

  bool get isLoading => _isLoading;
  double get progress => _progress;
  String? get error => _error;
  SkinData? get skinData => _skinData;
  bool get hasSkin => _skinData != null;

  /// Downloads, extracts, decrypts, and parses the skin pack.
  /// When complete, [skinData.skinPacks] is ready to pass to SkinViewerScreen.
  Future<void> loadSkin(SearchResult item) async {
    if (_isLoading) return;

    _disposeCurrentSkin();
    _error = null;
    _isLoading = true;
    _progress = 0.0;
    notifyListeners();

    try {
      final tempBase = await getTemporaryDirectory();
      final tempDir = Directory(
        path.join(tempBase.path, 'skin_preview_${const Uuid().v4()}'),
      )..createSync();

      try {
        final downloadUrl =
            item.personaBinaryUrl ??
            item.skinBinaryUrl ??
            (item.downloadUrls.isNotEmpty ? item.downloadUrls.first : null);
        if (downloadUrl == null) {
          throw Exception('No skin download URL found for this item.');
        }

        final zipPath = path.join(tempDir.path, 'skin.zip');
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

        final List<SkinPack> skinPacks = [];
        final List<PersonaPiece> personaPieces = [];
        for (final folder in nestedFolders) {
          final skinsJson = File(path.join(folder, 'skins.json'));
          if (await skinsJson.exists()) {
            try {
              final pack = await SkinPack.loadFromDirectory(folder);
              skinPacks.add(pack);
            } catch (e) {
              debugPrint(
                'SkinService: failed to parse skin pack in $folder: $e',
              );
            }
          } else {
            final pieces = await PersonaPiece.findInDirectory(folder);
            personaPieces.addAll(pieces);
          }
        }

        if (skinPacks.isEmpty && personaPieces.isEmpty) {
          throw Exception(
            'No valid skin packs (skins.json) or persona cosmetics found in archive.',
          );
        }

        _progress = 1.0;
        _skinData = SkinData(
          tempDir: tempDir,
          extractedFolders: nestedFolders,
          skinPacks: skinPacks,
          personaPieces: personaPieces,
        );
      } catch (e) {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        rethrow;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('SkinService: error loading skin: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSkin({bool notify = true}) {
    _disposeCurrentSkin();
    _progress = 0.0;
    _error = null;
    if (notify) notifyListeners();
  }

  void _disposeCurrentSkin() {
    _skinData?.dispose();
    _skinData = null;
  }

  @override
  void dispose() {
    _disposeCurrentSkin();
    super.dispose();
  }
}
