// Data classes

import 'package:flutter/material.dart';

class BedrockKeyframe {
  final double time;
  final double x, y, z;
  const BedrockKeyframe(this.time, this.x, this.y, this.z);
}

class BedrockBoneTrack {
  final List<BedrockKeyframe> rotation;
  final List<BedrockKeyframe> position;
  final List<BedrockKeyframe> scale;
  const BedrockBoneTrack({
    required this.rotation,
    required this.position,
    required this.scale,
  });
}

class BedrockAnimation {
  final String name;
  final double length;
  final Map<String, BedrockBoneTrack> bones;
  const BedrockAnimation({
    required this.name,
    required this.length,
    required this.bones,
  });
}

// Parser

BedrockAnimation parseBedrockAnimation(
  Map<String, dynamic> json, {
  String? animationName,
}) {
  final anims = json['animations'] as Map<String, dynamic>;

  final String resolvedName;
  final Map<String, dynamic> animData;

  if (animationName != null && anims.containsKey(animationName)) {
    resolvedName = animationName;
    animData = anims[animationName] as Map<String, dynamic>;
  } else {
    resolvedName = anims.keys.first;
    animData = anims.values.first as Map<String, dynamic>;
  }

  final bonesJson = (animData['bones'] as Map<String, dynamic>?) ?? {};
  final Map<String, BedrockBoneTrack> bones = {};

  for (final boneName in bonesJson.keys) {
    final boneData = bonesJson[boneName] as Map<String, dynamic>;
    bones[boneName] = BedrockBoneTrack(
      rotation: _parseChannel(boneData['rotation']),
      position: _parseChannel(boneData['position']),
      scale: _parseChannel(boneData['scale']),
    );
  }

  double length;
  if (animData.containsKey('animation_length')) {
    length = (animData['animation_length'] as num).toDouble();
  } else {
    length = 0;
    for (final track in bones.values) {
      for (final kf in [...track.rotation, ...track.position, ...track.scale]) {
        if (kf.time > length) length = kf.time;
      }
    }
    if (length == 0) length = 1;
  }

  return BedrockAnimation(name: resolvedName, length: length, bones: bones);
}

List<BedrockKeyframe> _parseChannel(dynamic channel) {
  if (channel == null) return [];

  // Static value: [x, y, z]
  if (channel is List) {
    return [
      BedrockKeyframe(
        0,
        _parseMolang(channel[0]),
        _parseMolang(channel[1]),
        _parseMolang(channel[2]),
      ),
    ];
  }

  if (channel is! Map) return [];

  final map = channel as Map<String, dynamic>;
  final frames = <BedrockKeyframe>[];

  for (final entry in map.entries) {
    final t = double.tryParse(entry.key) ?? 0.0;

    if (entry.value is List) {
      final v = entry.value as List<dynamic>;
      frames.add(
        BedrockKeyframe(
          t,
          _parseMolang(v[0]),
          _parseMolang(v[1]),
          _parseMolang(v[2]),
        ),
      );
    } else if (entry.value is Map) {
      final m = entry.value as Map<String, dynamic>;
      final hasPre = m.containsKey('pre');
      final hasPost = m.containsKey('post');

      if (hasPre && hasPost) {
        final pre = m['pre'] as List<dynamic>;
        final post = m['post'] as List<dynamic>;
        frames.add(
          BedrockKeyframe(
            t - 0.0001,
            _parseMolang(pre[0]),
            _parseMolang(pre[1]),
            _parseMolang(pre[2]),
          ),
        );
        frames.add(
          BedrockKeyframe(
            t,
            _parseMolang(post[0]),
            _parseMolang(post[1]),
            _parseMolang(post[2]),
          ),
        );
      } else {
        final raw = (hasPost ? m['post'] : m['pre']) as List<dynamic>;
        frames.add(
          BedrockKeyframe(
            t,
            _parseMolang(raw[0]),
            _parseMolang(raw[1]),
            _parseMolang(raw[2]),
          ),
        );
      }
    }
  }

  frames.sort((a, b) => a.time.compareTo(b.time));
  return frames;
}

// Interpolation

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

double _angleLerp(double a, double b, double t) {
  double delta = (b - a) % 360.0;
  if (delta > 180.0) delta -= 360.0;
  if (delta < -180.0) delta += 360.0;
  return a + delta * t;
}

double _parseMolang(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final cleaned = value.replaceAll(' ', '');

    // arithmetic handler for cases like "2700+180"
    try {
      if (cleaned.contains('+')) {
        final parts = cleaned.split('+');
        return (double.tryParse(parts[0]) ?? 0) +
            (double.tryParse(parts[1]) ?? 0);
      }
      if (cleaned.contains('-')) {
        final parts = cleaned.split('-');
        if (parts.length == 2) {
          return (double.tryParse(parts[0]) ?? 0) -
              (double.tryParse(parts[1]) ?? 0);
        }
      }

      return double.tryParse(cleaned) ?? 0.0;
    } catch (e) {
      debugPrint('Failed to parse Molang expression: $value');
      return 0.0;
    }
  }
  return 0.0;
}

/// Samples a keyframe channel at time [t].
/// Set [isRotation] to true to use shortest-path angle interpolation.
List<double> sampleChannel(
  List<BedrockKeyframe> frames,
  double t, {
  bool isRotation = false,
}) {
  if (frames.isEmpty) return [0, 0, 0];
  if (t <= frames.first.time) {
    return [frames.first.x, frames.first.y, frames.first.z];
  }
  if (t >= frames.last.time) {
    return [frames.last.x, frames.last.y, frames.last.z];
  }

  for (int i = 0; i < frames.length - 1; i++) {
    final a = frames[i];
    final b = frames[i + 1];
    if (t >= a.time && t <= b.time) {
      final alpha = (t - a.time) / (b.time - a.time);
      if (isRotation) {
        return [
          _angleLerp(a.x, b.x, alpha),
          _angleLerp(a.y, b.y, alpha),
          _angleLerp(a.z, b.z, alpha),
        ];
      }
      return [
        _lerpDouble(a.x, b.x, alpha),
        _lerpDouble(a.y, b.y, alpha),
        _lerpDouble(a.z, b.z, alpha),
      ];
    }
  }
  return [0, 0, 0];
}
