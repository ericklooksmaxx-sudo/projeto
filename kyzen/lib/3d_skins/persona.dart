import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

/// Texture source entry from `<piece>.meta.json`
class PersonaTextureSource {
  final String texture;
  final bool useFaceUv;
  final bool animated;
  final int frames;

  const PersonaTextureSource({
    required this.texture,
    this.useFaceUv = false,
    this.animated = false,
    this.frames = 1,
  });

  factory PersonaTextureSource.fromJson(Map<String, dynamic> json) {
    return PersonaTextureSource(
      texture: json['texture'] as String? ?? '',
      useFaceUv: (json['use_face_uv'] as bool?) ?? false,
      animated: (json['animated'] as bool?) ?? false,
      frames: (json['frames'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Geometry source entry from `<piece>.meta.json`
class PersonaGeometrySource {
  final String? bodySize;
  final String? armSize;
  final String? side;
  final String geometry;
  final List<String> zone;
  final String texture;
  final bool animated;
  final int frames;

  const PersonaGeometrySource({
    this.bodySize,
    this.armSize,
    this.side,
    required this.geometry,
    this.zone = const [],
    required this.texture,
    this.animated = false,
    this.frames = 1,
  });

  factory PersonaGeometrySource.fromJson(Map<String, dynamic> json) {
    final rawZone = json['zone'];
    List<String> parsedZone = const [];
    if (rawZone is List) {
      parsedZone = rawZone.map((e) => e.toString()).toList();
    } else if (rawZone is String) {
      parsedZone = [rawZone];
    }

    return PersonaGeometrySource(
      bodySize: json['body_size'] as String?,
      armSize: json['arm_size'] as String?,
      side: json['side'] as String?,
      geometry: json['geometry'] as String? ?? '',
      zone: parsedZone,
      texture: json['texture'] as String? ?? '',
      animated: (json['animated'] as bool?) ?? false,
      frames: (json['frames'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Metadata parsed from `<piece>.meta.json`
class PersonaMeta {
  final String pieceId;
  final String pieceName;
  final String pieceType;
  final List<String> zone;
  final List<PersonaTextureSource> textureSources;
  final List<PersonaGeometrySource> geometrySources;

  const PersonaMeta({
    required this.pieceId,
    required this.pieceName,
    required this.pieceType,
    this.zone = const [],
    this.textureSources = const [],
    this.geometrySources = const [],
  });

  bool get isCape {
    final type = pieceType.toLowerCase();
    if (type == 'persona_capes' || type.contains('cape')) {
      return true;
    }
    for (final z in zone) {
      final lz = z.toLowerCase();
      if (lz.contains('cape')) return true;
    }
    return false;
  }

  factory PersonaMeta.fromJson(Map<String, dynamic> json) {
    final rawZone = json['zone'];
    List<String> parsedZone = const [];
    if (rawZone is List) {
      parsedZone = rawZone.map((e) => e.toString()).toList();
    } else if (rawZone is String) {
      parsedZone = [rawZone];
    }

    final rawTextures = json['texture_sources'] as List<dynamic>?;
    final textures =
        rawTextures
            ?.map(
              (e) => PersonaTextureSource.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [];

    final rawGeometries = json['geometry_sources'] as List<dynamic>?;
    final geometries =
        rawGeometries
            ?.map(
              (e) => PersonaGeometrySource.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [];

    return PersonaMeta(
      pieceId: json['piece_id'] as String? ?? '',
      pieceName: json['piece_name'] as String? ?? 'Unknown Persona',
      pieceType: json['piece_type'] as String? ?? 'persona_piece',
      zone: parsedZone,
      textureSources: textures,
      geometrySources: geometries,
    );
  }
}

/// UV mapping for an individual cube face in Per-Face UV format
class PersonaFaceUV {
  final List<double> uv;
  final List<double> uvSize;

  const PersonaFaceUV({required this.uv, required this.uvSize});

  factory PersonaFaceUV.fromJson(Map<String, dynamic> json) {
    List<double> parseList(dynamic raw, int count, double fallback) {
      if (raw is List) {
        return raw.map((e) => (e as num).toDouble()).toList();
      }
      return List.filled(count, fallback);
    }

    return PersonaFaceUV(
      uv: parseList(json['uv'], 2, 0.0),
      uvSize: parseList(json['uv_size'], 2, 0.0),
    );
  }
}

/// Single 3D cube or plane in a Persona geometry bone
class PersonaCube {
  final List<double> origin;
  final List<double> size;
  final List<double>? boxUv;
  final Map<String, PersonaFaceUV>? perFaceUv;
  final double inflate;
  final bool mirror;
  final List<double>? rotation;
  final List<double>? pivot;

  const PersonaCube({
    required this.origin,
    required this.size,
    this.boxUv,
    this.perFaceUv,
    this.inflate = 0.0,
    this.mirror = false,
    this.rotation,
    this.pivot,
  });

  bool get isPerFaceUv => perFaceUv != null && perFaceUv!.isNotEmpty;

  factory PersonaCube.fromJson(
    Map<String, dynamic> json, {
    bool boneMirror = false,
  }) {
    List<double> parseList(dynamic raw, int count, double fallback) {
      if (raw is List) {
        return raw.map((e) => (e as num).toDouble()).toList();
      }
      return List.filled(count, fallback);
    }

    List<double>? boxUv;
    Map<String, PersonaFaceUV>? perFaceUv;

    final rawUv = json['uv'];
    if (rawUv is Map<String, dynamic>) {
      perFaceUv = {};
      for (final entry in rawUv.entries) {
        if (entry.value is Map<String, dynamic>) {
          perFaceUv[entry.key] = PersonaFaceUV.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    } else if (rawUv is List) {
      boxUv = parseList(rawUv, 2, 0.0);
    }

    return PersonaCube(
      origin: parseList(json['origin'], 3, 0.0),
      size: parseList(json['size'], 3, 0.0),
      boxUv: boxUv,
      perFaceUv: perFaceUv,
      inflate: (json['inflate'] as num?)?.toDouble() ?? 0.0,
      mirror: (json['mirror'] as bool?) ?? boneMirror,
      rotation: json['rotation'] != null
          ? parseList(json['rotation'], 3, 0.0)
          : null,
      pivot: json['pivot'] != null ? parseList(json['pivot'], 3, 0.0) : null,
    );
  }
}

/// Vertex indexing a polygon within [PersonaPolyMesh]
class PersonaPolyVertex {
  final int posIndex;
  final int? normIndex;
  final int? uvIndex;

  const PersonaPolyVertex({
    required this.posIndex,
    this.normIndex,
    this.uvIndex,
  });

  factory PersonaPolyVertex.fromDynamic(dynamic raw, [int fallbackIndex = 0]) {
    if (raw is List) {
      final pos = raw.isNotEmpty ? (raw[0] as num).toInt() : fallbackIndex;
      final norm = raw.length > 1 ? (raw[1] as num?)?.toInt() : null;
      final uv = raw.length > 2
          ? (raw[2] as num?)?.toInt()
          : (raw.length == 2 ? norm : null);
      return PersonaPolyVertex(
        posIndex: pos,
        normIndex: raw.length > 2 ? norm : null,
        uvIndex: uv,
      );
    } else if (raw is num) {
      final idx = raw.toInt();
      return PersonaPolyVertex(posIndex: idx, normIndex: idx, uvIndex: idx);
    }
    return PersonaPolyVertex(posIndex: fallbackIndex);
  }
}

class PersonaPolyMesh {
  final bool normalizedUvs;
  final List<List<double>> positions;
  final List<List<double>> normals;
  final List<List<double>> uvs;
  final List<List<PersonaPolyVertex>> polys;

  const PersonaPolyMesh({
    this.normalizedUvs = false,
    this.positions = const [],
    this.normals = const [],
    this.uvs = const [],
    this.polys = const [],
  });

  factory PersonaPolyMesh.fromJson(Map<String, dynamic> json) {
    List<double> parseDoubles(dynamic list) {
      if (list is List) {
        return list.map((e) => (e as num).toDouble()).toList();
      }
      return const [];
    }

    List<List<double>> parseDoubleLists(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => parseDoubles(e)).toList();
      }
      return const [];
    }

    final normalized = (json['normalized_uvs'] as bool?) ?? false;
    final positions = parseDoubleLists(json['positions']);
    final normals = parseDoubleLists(json['normals']);
    final uvs = parseDoubleLists(json['uvs']);

    final rawPolys = json['polys'];
    final polys = <List<PersonaPolyVertex>>[];

    if (rawPolys is String) {
      final str = rawPolys.toLowerCase().trim();
      if (str == 'tri_list') {
        for (int i = 0; i + 2 < positions.length; i += 3) {
          polys.add([
            PersonaPolyVertex(
              posIndex: i,
              normIndex: i < normals.length ? i : null,
              uvIndex: i < uvs.length ? i : null,
            ),
            PersonaPolyVertex(
              posIndex: i + 1,
              normIndex: i + 1 < normals.length ? i + 1 : null,
              uvIndex: i + 1 < uvs.length ? i + 1 : null,
            ),
            PersonaPolyVertex(
              posIndex: i + 2,
              normIndex: i + 2 < normals.length ? i + 2 : null,
              uvIndex: i + 2 < uvs.length ? i + 2 : null,
            ),
          ]);
        }
      } else if (str == 'quad_list') {
        for (int i = 0; i + 3 < positions.length; i += 4) {
          polys.add([
            PersonaPolyVertex(
              posIndex: i,
              normIndex: i < normals.length ? i : null,
              uvIndex: i < uvs.length ? i : null,
            ),
            PersonaPolyVertex(
              posIndex: i + 1,
              normIndex: i + 1 < normals.length ? i + 1 : null,
              uvIndex: i + 1 < uvs.length ? i + 1 : null,
            ),
            PersonaPolyVertex(
              posIndex: i + 2,
              normIndex: i + 2 < normals.length ? i + 2 : null,
              uvIndex: i + 2 < uvs.length ? i + 2 : null,
            ),
            PersonaPolyVertex(
              posIndex: i + 3,
              normIndex: i + 3 < normals.length ? i + 3 : null,
              uvIndex: i + 3 < uvs.length ? i + 3 : null,
            ),
          ]);
        }
      }
    } else if (rawPolys is List) {
      for (final p in rawPolys) {
        if (p is List) {
          final polyVerts = <PersonaPolyVertex>[];
          for (int vi = 0; vi < p.length; vi++) {
            polyVerts.add(PersonaPolyVertex.fromDynamic(p[vi], vi));
          }
          if (polyVerts.isNotEmpty) {
            polys.add(polyVerts);
          }
        }
      }
    }

    return PersonaPolyMesh(
      normalizedUvs: normalized,
      positions: positions,
      normals: normals,
      uvs: uvs,
      polys: polys,
    );
  }
}

/// A bone node in a Persona geometry definition
class PersonaBone {
  final String name;
  final String? parent;
  final List<double>? pivot;
  final List<double>? rotation;
  final bool mirror;
  final double inflate;
  final List<PersonaCube> cubes;
  final PersonaPolyMesh? polyMesh;

  const PersonaBone({
    required this.name,
    this.parent,
    this.pivot,
    this.rotation,
    this.mirror = false,
    this.inflate = 0.0,
    this.cubes = const [],
    this.polyMesh,
  });

  bool get hasGeometry =>
      cubes.isNotEmpty || (polyMesh != null && polyMesh!.polys.isNotEmpty);

  factory PersonaBone.fromJson(Map<String, dynamic> json) {
    List<double>? parseListOptional(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => (e as num).toDouble()).toList();
      }
      return null;
    }

    final boneMirror = (json['mirror'] as bool?) ?? false;
    final cubesRaw = json['cubes'] as List<dynamic>?;
    final cubes =
        cubesRaw
            ?.map(
              (c) => PersonaCube.fromJson(
                c as Map<String, dynamic>,
                boneMirror: boneMirror,
              ),
            )
            .toList() ??
        const [];

    final polyMeshRaw = json['poly_mesh'] as Map<String, dynamic>?;
    final polyMesh = polyMeshRaw != null
        ? PersonaPolyMesh.fromJson(polyMeshRaw)
        : null;

    return PersonaBone(
      name: json['name'] as String? ?? 'unnamed_bone',
      parent: json['parent'] as String?,
      pivot: parseListOptional(json['pivot']),
      rotation: parseListOptional(json['rotation']),
      mirror: boneMirror,
      inflate: (json['inflate'] as num?)?.toDouble() ?? 0.0,
      cubes: cubes,
      polyMesh: polyMesh,
    );
  }
}

/// Persona geometry definition from `<piece>.geometry.json`
class PersonaGeometry {
  final String identifier;
  final double? textureWidth;
  final double? textureHeight;
  final List<PersonaBone> bones;

  const PersonaGeometry({
    required this.identifier,
    this.textureWidth,
    this.textureHeight,
    required this.bones,
  });

  factory PersonaGeometry.fromJson(
    Map<String, dynamic> json, [
    String? targetKey,
  ]) {
    Map<String, dynamic>? geoMap;
    String id = targetKey ?? 'geometry';

    if (json.containsKey('minecraft:geometry')) {
      final list = json['minecraft:geometry'] as List<dynamic>;
      if (list.isNotEmpty) {
        if (targetKey != null) {
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              final desc = item['description'] as Map<String, dynamic>?;
              if (desc?['identifier'] == targetKey) {
                geoMap = item;
                id = targetKey;
                break;
              }
            }
          }
        }
        if (geoMap == null && list.first is Map<String, dynamic>) {
          geoMap = list.first as Map<String, dynamic>;
          final desc = geoMap['description'] as Map<String, dynamic>?;
          id = desc?['identifier'] as String? ?? id;
        }
      }
    } else {
      if (targetKey != null && json.containsKey(targetKey)) {
        geoMap = json[targetKey] as Map<String, dynamic>;
        id = targetKey;
      } else {
        for (final entry in json.entries) {
          if (entry.key.startsWith('geometry.') && entry.value is Map) {
            if (targetKey == null || entry.key == targetKey) {
              id = entry.key;
              geoMap = entry.value as Map<String, dynamic>;
              break;
            }
          }
        }
        geoMap ??=
            json.entries
                    .firstWhere(
                      (e) => e.value is Map,
                      orElse: () => const MapEntry('', {}),
                    )
                    .value
                as Map<String, dynamic>?;
      }
    }

    if (geoMap == null) {
      throw const FormatException('No valid geometry definition found.');
    }

    final bonesRaw = geoMap['bones'] as List<dynamic>?;
    final bones =
        bonesRaw
            ?.map((b) => PersonaBone.fromJson(b as Map<String, dynamic>))
            .toList() ??
        const [];

    final tw =
        (geoMap['texturewidth'] as num?)?.toDouble() ??
        (geoMap['texture_width'] as num?)?.toDouble();
    final th =
        (geoMap['textureheight'] as num?)?.toDouble() ??
        (geoMap['texture_height'] as num?)?.toDouble();

    return PersonaGeometry(
      identifier: id,
      textureWidth: tw,
      textureHeight: th,
      bones: bones,
    );
  }

  static Future<PersonaGeometry> loadFromFile(
    String filePath, [
    String? targetKey,
  ]) async {
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    return PersonaGeometry.fromJson(jsonMap, targetKey);
  }
}

/// Complete loaded Persona cosmetic piece
class PersonaPiece {
  final PersonaMeta meta;
  final String baseDir;
  final String displayName;
  final String? geometryPath;

  const PersonaPiece({
    required this.meta,
    required this.baseDir,
    required this.displayName,
    this.geometryPath,
  });

  String get pieceId => meta.pieceId;
  String get pieceName => meta.pieceName;
  String get pieceType => meta.pieceType;
  List<PersonaTextureSource> get textureSources => meta.textureSources;
  List<PersonaGeometrySource> get geometrySources => meta.geometrySources;
  List<String> get zone => meta.zone;

  bool get hasGeometry => geometrySources.isNotEmpty && geometryPath != null;
  bool get isCape => meta.isCape;

  String resolveTexturePath(String relativeName) {
    return p.join(baseDir, relativeName);
  }

  /// Selects the best geometry source matching [bodySize] and [armSize]
  PersonaGeometrySource? selectGeometrySource({
    String bodySize = 'medium',
    String armSize = 'wide',
  }) {
    final sources = selectGeometrySources(bodySize: bodySize, armSize: armSize);
    return sources.isNotEmpty ? sources.first : null;
  }

  /// Selects all geometry sources matching [bodySize] and [armSize]
  List<PersonaGeometrySource> selectGeometrySources({
    String bodySize = 'medium',
    String armSize = 'wide',
  }) {
    if (geometrySources.isEmpty) return const [];

    final exactBody = geometrySources
        .where((s) => s.bodySize?.toLowerCase() == bodySize.toLowerCase())
        .toList();
    final nullBody = geometrySources.where((s) => s.bodySize == null).toList();

    final List<PersonaGeometrySource> bodyMatches;
    if (exactBody.isNotEmpty) {
      bodyMatches = exactBody;
    } else if (nullBody.isNotEmpty) {
      bodyMatches = nullBody;
    } else {
      final firstSize = geometrySources
          .firstWhere(
            (s) => s.bodySize != null,
            orElse: () => geometrySources.first,
          )
          .bodySize;
      bodyMatches = geometrySources
          .where((s) => s.bodySize?.toLowerCase() == firstSize?.toLowerCase())
          .toList();
    }

    final exactArm = bodyMatches
        .where((s) => s.armSize?.toLowerCase() == armSize.toLowerCase())
        .toList();
    final nullArm = bodyMatches.where((s) => s.armSize == null).toList();

    final List<PersonaGeometrySource> armMatches;
    if (exactArm.isNotEmpty) {
      armMatches = exactArm;
    } else if (nullArm.isNotEmpty) {
      armMatches = nullArm;
    } else {
      armMatches = bodyMatches;
    }

    return armMatches;
  }

  /// Loads the geometry definition for the selected [geometrySource]
  Future<PersonaGeometry?> loadGeometry([PersonaGeometrySource? source]) async {
    final src = source ?? selectGeometrySource();
    if (src == null || geometryPath == null) return null;

    final file = File(geometryPath!);
    if (!await file.exists()) return null;

    try {
      return await PersonaGeometry.loadFromFile(geometryPath!, src.geometry);
    } catch (e) {
      debugPrint('Failed to load PersonaGeometry from $geometryPath: $e');
      return null;
    }
  }

  static Future<PersonaPiece?> loadFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return null;

    File? metaFile;
    File? geoFile;

    try {
      final entities = await dir.list(recursive: false).toList();
      for (final entity in entities) {
        if (entity is File) {
          final filename = p.basename(entity.path).toLowerCase();
          if (filename.endsWith('.meta.json')) {
            metaFile = entity;
          } else if (filename.endsWith('.geometry.json')) {
            geoFile = entity;
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning persona directory $dirPath: $e');
      return null;
    }

    if (metaFile == null) return null;

    try {
      final metaJsonStr = await metaFile.readAsString();
      final metaJson = jsonDecode(metaJsonStr) as Map<String, dynamic>;
      final meta = PersonaMeta.fromJson(metaJson);

      final translations = await _loadLang(dirPath);
      final rawName = meta.pieceName;
      final resolvedName = _resolveName(translations, rawName);

      return PersonaPiece(
        meta: meta,
        baseDir: dirPath,
        displayName: resolvedName,
        geometryPath: geoFile?.path,
      );
    } catch (e) {
      debugPrint('Error parsing PersonaPiece from ${metaFile.path}: $e');
      return null;
    }
  }

  static Future<List<PersonaPiece>> findInDirectory(String dirPath) async {
    final results = <PersonaPiece>[];
    final dir = Directory(dirPath);
    if (!await dir.exists()) return results;

    final direct = await loadFromDirectory(dirPath);
    if (direct != null) {
      results.add(direct);
      return results;
    }

    try {
      final entities = await dir.list(recursive: true).toList();
      final metaDirs = <String>{};
      for (final e in entities) {
        if (e is File &&
            p.basename(e.path).toLowerCase().endsWith('.meta.json')) {
          metaDirs.add(e.parent.path);
        }
      }
      for (final metaDir in metaDirs) {
        final piece = await loadFromDirectory(metaDir);
        if (piece != null) results.add(piece);
      }
    } catch (e) {
      debugPrint('Error finding persona pieces in $dirPath: $e');
    }
    return results;
  }

  static Future<Map<String, String>> _loadLang(String dirPath) async {
    final candidates = [
      File(p.join(dirPath, 'texts', 'en_US.lang')),
      File(p.join(dirPath, 'en_US.lang')),
    ];

    for (final file in candidates) {
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          return _parseLang(content);
        } catch (e) {
          debugPrint('Failed to read lang file ${file.path}: $e');
        }
      }
    }
    return const {};
  }

  static Map<String, String> _parseLang(String content) {
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

  static String _resolveName(Map<String, String> translations, String rawName) {
    if (translations.isEmpty) return rawName;

    final candidates = [
      'persona.$rawName.title',
      'persona.$rawName',
      'piece.$rawName',
      rawName,
    ];

    for (final c in candidates) {
      if (translations.containsKey(c)) return translations[c]!;
    }

    final lower = rawName.toLowerCase();
    for (final entry in translations.entries) {
      if (entry.key.toLowerCase().contains(lower)) {
        return entry.value;
      }
    }

    return rawName;
  }
}
