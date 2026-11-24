import 'dart:convert';
import 'dart:io';

/// Single 3D cube or 2D plane within a Bedrock bone
class BedrockCube {
  final List<double> origin;
  final List<double> size;
  final List<double> uv;
  final double inflate;
  final bool mirror;
  final List<double>? rotation;
  final List<double>? pivot;

  const BedrockCube({
    required this.origin,
    required this.size,
    required this.uv,
    this.inflate = 0.0,
    this.mirror = false,
    this.rotation,
    this.pivot,
  });

  factory BedrockCube.fromJson(
    Map<String, dynamic> json, {
    bool boneMirror = false,
  }) {
    List<double> parseList(dynamic raw, int count, double fallback) {
      if (raw is List) {
        return raw.map((e) => (e as num).toDouble()).toList();
      }
      return List.filled(count, fallback);
    }

    return BedrockCube(
      origin: parseList(json['origin'], 3, 0.0),
      size: parseList(json['size'], 3, 0.0),
      uv: parseList(json['uv'], 2, 0.0),
      inflate: (json['inflate'] as num?)?.toDouble() ?? 0.0,
      mirror: (json['mirror'] as bool?) ?? boneMirror,
      rotation: json['rotation'] != null
          ? parseList(json['rotation'], 3, 0.0)
          : null,
      pivot: json['pivot'] != null ? parseList(json['pivot'], 3, 0.0) : null,
    );
  }
}

/// A bone (joint/node) in a Bedrock geometry hierarchy
class BedrockBone {
  final String name;
  final String? parent;
  final List<double> pivot;
  final List<double>? rotation;
  final bool mirror;
  final double inflate;
  final List<BedrockCube> cubes;

  const BedrockBone({
    required this.name,
    this.parent,
    required this.pivot,
    this.rotation,
    this.mirror = false,
    this.inflate = 0.0,
    this.cubes = const [],
  });

  factory BedrockBone.fromJson(Map<String, dynamic> json) {
    List<double> parseList(dynamic raw, int count, double fallback) {
      if (raw is List) {
        return raw.map((e) => (e as num).toDouble()).toList();
      }
      return List.filled(count, fallback);
    }

    final boneMirror = (json['mirror'] as bool?) ?? false;
    final cubesRaw = json['cubes'] as List<dynamic>?;
    final cubes =
        cubesRaw
            ?.map(
              (c) => BedrockCube.fromJson(
                c as Map<String, dynamic>,
                boneMirror: boneMirror,
              ),
            )
            .toList() ??
        [];

    return BedrockBone(
      name: json['name'] as String? ?? 'unnamed_bone',
      parent: json['parent'] as String?,
      pivot: parseList(json['pivot'], 3, 0.0),
      rotation: json['rotation'] != null
          ? parseList(json['rotation'], 3, 0.0)
          : null,
      mirror: boneMirror,
      inflate: (json['inflate'] as num?)?.toDouble() ?? 0.0,
      cubes: cubes,
    );
  }
}

/// Complete Bedrock Entity / Custom Skin Geometry model
class BedrockGeometry {
  final String identifier;
  final double textureWidth;
  final double textureHeight;
  final double? visibleBoundsWidth;
  final double? visibleBoundsHeight;
  final List<double>? visibleBoundsOffset;
  final List<BedrockBone> bones;

  const BedrockGeometry({
    required this.identifier,
    this.textureWidth = 64.0,
    this.textureHeight = 64.0,
    this.visibleBoundsWidth,
    this.visibleBoundsHeight,
    this.visibleBoundsOffset,
    required this.bones,
  });

  /// Finds a bone by name.
  BedrockBone? findBone(String name) {
    for (final bone in bones) {
      if (bone.name == name) return bone;
    }
    return null;
  }

  factory BedrockGeometry.fromJson(
    Map<String, dynamic> json, [
    String? targetKey,
  ]) {
    // Format A: Legacy / Direct key: { "geometry.Gru_Young": { ... } }
    // Format B: 1.12.0: { "format_version": "1.12.0", "minecraft:geometry": [ { "description": { "identifier": ... } } ] }
    Map<String, dynamic>? geoMap;
    String id = targetKey ?? 'geometry';

    if (json.containsKey('minecraft:geometry')) {
      final list = json['minecraft:geometry'] as List<dynamic>;
      if (list.isNotEmpty) {
        geoMap = list.first as Map<String, dynamic>;
        final desc = geoMap['description'] as Map<String, dynamic>?;
        id = desc?['identifier'] as String? ?? id;
      }
    } else {
      if (targetKey != null && json.containsKey(targetKey)) {
        geoMap = json[targetKey] as Map<String, dynamic>;
        id = targetKey;
      } else {
        for (final entry in json.entries) {
          if (entry.key.startsWith('geometry.') || entry.value is Map) {
            id = entry.key;
            geoMap = entry.value as Map<String, dynamic>;
            break;
          }
        }
      }
    }

    if (geoMap == null) {
      throw const FormatException(
        'No valid geometry definition found in JSON.',
      );
    }

    final bonesRaw = geoMap['bones'] as List<dynamic>?;
    final bones =
        bonesRaw
            ?.map((b) => BedrockBone.fromJson(b as Map<String, dynamic>))
            .toList() ??
        [];

    final texW =
        (geoMap['texturewidth'] as num?)?.toDouble() ??
        (geoMap['texture_width'] as num?)?.toDouble() ??
        64.0;
    final texH =
        (geoMap['textureheight'] as num?)?.toDouble() ??
        (geoMap['texture_height'] as num?)?.toDouble() ??
        64.0;

    return BedrockGeometry(
      identifier: id,
      textureWidth: texW,
      textureHeight: texH,
      visibleBoundsWidth: (geoMap['visible_bounds_width'] as num?)?.toDouble(),
      visibleBoundsHeight: (geoMap['visible_bounds_height'] as num?)
          ?.toDouble(),
      visibleBoundsOffset: (geoMap['visible_bounds_offset'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      bones: bones,
    );
  }

  static Future<BedrockGeometry> loadFromFile(
    String filePath, [
    String? targetKey,
  ]) async {
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    return BedrockGeometry.fromJson(jsonMap, targetKey);
  }
}
