import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

import 'bedrock_geometry.dart';

/// skin definition
class MinecraftSkinEntry {
  final String localizationName;
  final String geometry;
  final String texture;
  final String? cape;
  final String baseDir;

  const MinecraftSkinEntry({
    required this.localizationName,
    required this.geometry,
    required this.texture,
    this.cape,
    this.baseDir = '',
  });

  String get texturePath =>
      baseDir.isEmpty ? texture : p.join(baseDir, texture);

  String? get capePath => cape == null || cape!.isEmpty
      ? null
      : (baseDir.isEmpty ? cape! : p.join(baseDir, cape!));

  bool get hasCape => cape != null && cape!.isNotEmpty;

  String get geometryPath =>
      baseDir.isEmpty ? 'geometry.json' : p.join(baseDir, 'geometry.json');

  Future<BedrockGeometry> loadGeometry() async {
    final path = geometryPath;
    if (await File(path).exists()) {
      return await BedrockGeometry.loadFromFile(path, geometry);
    }
    throw FileSystemException('geometry.json not found', path);
  }

  /// Whether this skin uses custom Bedrock geo instead of standard
  bool get isCustomGeometry =>
      !geometry.contains('humanoid.custom') &&
      !geometry.contains('humanoid.customSlim') &&
      geometry.isNotEmpty;

  /// Whether this skins geo specifies a slim model
  bool get isSlim =>
      geometry.toLowerCase().contains('slim') ||
      geometry.toLowerCase().contains('alex');

  factory MinecraftSkinEntry.fromJson(
    Map<String, dynamic> json, {
    String baseDir = '',
    String packName = '',
    Map<String, String> translations = const {},
  }) {
    final rawName = json['localization_name'] as String? ?? 'Unknown Skin';
    final resolvedName = translations.isNotEmpty
        ? _resolveSkinName(translations, packName, rawName)
        : rawName;

    return MinecraftSkinEntry(
      localizationName: resolvedName,
      geometry: json['geometry'] as String? ?? 'geometry.humanoid.custom',
      texture: json['texture'] as String? ?? '',
      cape: json['cape'] as String?,
      baseDir: baseDir,
    );
  }

  static String _resolveSkinName(
    Map<String, String> translations,
    String packName,
    String rawName,
  ) {
    final candidates = [
      if (packName.isNotEmpty) 'skin.$packName.$rawName',
      'skin.$rawName',
      rawName,
    ];

    for (final c in candidates) {
      if (translations.containsKey(c)) {
        return translations[c]!;
      }
    }

    for (final c in candidates) {
      final lowerC = c.toLowerCase();
      for (final entry in translations.entries) {
        if (entry.key.toLowerCase() == lowerC) {
          return entry.value;
        }
      }
    }

    return rawName;
  }
}

/// multiple skins
class SkinPack {
  final String serializeName;
  final String localizationName;
  final String baseDir;
  final List<MinecraftSkinEntry> skins;

  const SkinPack({
    required this.serializeName,
    required this.localizationName,
    required this.baseDir,
    required this.skins,
  });

  factory SkinPack.fromJson(
    Map<String, dynamic> json, {
    String baseDir = '',
    Map<String, String> translations = const {},
  }) {
    final serializeName = json['serialize_name'] as String? ?? 'skins';
    final rawLocName = json['localization_name'] as String? ?? serializeName;

    String resolvedPackName = rawLocName;
    if (translations.isNotEmpty) {
      resolvedPackName =
          translations['skinpack.$serializeName'] ??
          translations['skinpack.$rawLocName'] ??
          translations[serializeName] ??
          translations[rawLocName] ??
          rawLocName;
    }

    final list =
        (json['skins'] as List<dynamic>?)
            ?.map(
              (e) => MinecraftSkinEntry.fromJson(
                e as Map<String, dynamic>,
                baseDir: baseDir,
                packName: serializeName,
                translations: translations,
              ),
            )
            .toList() ??
        [];

    return SkinPack(
      serializeName: serializeName,
      localizationName: resolvedPackName,
      baseDir: baseDir,
      skins: list,
    );
  }

  static Future<SkinPack> loadFromDirectory(String dirPath) async {
    final skinsFile = File(p.join(dirPath, 'skins.json'));
    if (!await skinsFile.exists()) {
      throw Exception('skins.json not found in $dirPath');
    }
    final jsonStr = await skinsFile.readAsString();
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    final translations = await loadPackTranslations(dirPath);
    return SkinPack.fromJson(
      jsonMap,
      baseDir: dirPath,
      translations: translations,
    );
  }
}

// get skin name
Map<String, String> parseLangFile(String content) {
  final map = <String, String>{};
  final lines = const LineSplitter().convert(content);
  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final commentIdx = line.indexOf('#');
    if (commentIdx != -1) {
      line = line.substring(0, commentIdx).trim();
    }
    final eqIdx = line.indexOf('=');
    if (eqIdx != -1) {
      final key = line.substring(0, eqIdx).trim();
      final val = line.substring(eqIdx + 1).trim();
      if (key.isNotEmpty && val.isNotEmpty) {
        map[key] = val;
      }
    }
  }
  return map;
}

Future<Map<String, String>> loadPackTranslations(String dirPath) async {
  final candidates = [
    File(p.join(dirPath, 'texts', 'en_US.lang')),
    File(p.join(dirPath, 'en_US.lang')),
  ];

  for (final file in candidates) {
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        return parseLangFile(content);
      } catch (e) {
        debugPrint('Failed to read lang file ${file.path}: $e');
      }
    }
  }
  return const {};
}
