import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../flutter_gpu/texture_utils.dart';

/// Slight tilt
const double defaultCapeAngle = 12.5 * math.pi / 180.0;

/// Default position offset when attaching the cape node to the player body bone
/// (where the body top / neck plane is at Y = 0.0).
///
/// - Y = -0.30: Lowered slightly from the neck plane (Y = 0.0) to the upper back / shoulder line,
///   ensuring that when the cape tilts backward, its top edge does not pierce the head.
/// - Z = -2.00: Placed flush against the back of the player torso.
vm.Vector3 get defaultCapeBodyOffset => vm.Vector3(0.0, -0.30, -2.00);

/// 3D cape mesh (10 x 16 x 1)
///
/// The cape mesh has its origin/pivot at its top-front edge `(0, 0, 0)`:
/// - X ranges from -5.0 to +5.0 (width: 10)
/// - Y ranges from -16.0 to 0.0 (height: 16, hangs downward)
/// - Z ranges from -1.0 to 0.0 (depth: 1, extends backward)
///
/// Face mapping:
/// - Front (+Z): Inside of cape (facing player's back)
/// - Back (-Z): Outside of cape (facing viewer from behind)
/// - Right (-X) & Left (+X): Cape sides
/// - Top (+Y) & Bottom (-Y): Top and bottom edges

Mesh buildCapeMesh(TextureSource capeTexture, {bool lit = false}) {
  final builder = GeometryBuilder(deduplicate: false);

  const double w = 10.0;
  const double h = 16.0;
  const double d = 1.0;

  const double cx = 0.0;
  const double cy = -8.0;
  const double cz = -0.5;

  const double hw = w / 2.0;
  const double hh = h / 2.0;
  const double hd = d / 2.0;

  const double texW = 64.0;
  const double texH = 32.0;

  vm.Vector2 uvNorm(double px, double py) => vm.Vector2(px / texW, py / texH);

  void addQuad({
    required vm.Vector3 normal,
    required vm.Vector3 v0,
    required vm.Vector3 v1,
    required vm.Vector3 v2,
    required vm.Vector3 v3,
    required vm.Vector2 uv0,
    required vm.Vector2 uv1,
    required vm.Vector2 uv2,
    required vm.Vector2 uv3,
  }) {
    builder.normal(normal);

    builder.texCoord(uv0);
    final i0 = builder.addVertex(v0);

    builder.texCoord(uv1);
    final i1 = builder.addVertex(v1);

    builder.texCoord(uv2);
    final i2 = builder.addVertex(v2);

    builder.texCoord(uv3);
    final i3 = builder.addVertex(v3);

    // CCW winding order
    builder.addTriangle(i0, i1, i2);
    builder.addTriangle(i0, i2, i3);
  }

  // Front Face (+Z)
  addQuad(
    normal: vm.Vector3(0, 0, 1),
    v0: vm.Vector3(cx - hw, cy - hh, cz + hd),
    v1: vm.Vector3(cx + hw, cy - hh, cz + hd),
    v2: vm.Vector3(cx + hw, cy + hh, cz + hd),
    v3: vm.Vector3(cx - hw, cy + hh, cz + hd),
    uv0: uvNorm(12, 17),
    uv1: uvNorm(22, 17),
    uv2: uvNorm(22, 1),
    uv3: uvNorm(12, 1),
  );

  // Back Face (-Z)
  addQuad(
    normal: vm.Vector3(0, 0, -1),
    v0: vm.Vector3(cx + hw, cy - hh, cz - hd),
    v1: vm.Vector3(cx - hw, cy - hh, cz - hd),
    v2: vm.Vector3(cx - hw, cy + hh, cz - hd),
    v3: vm.Vector3(cx + hw, cy + hh, cz - hd),
    uv0: uvNorm(1, 17),
    uv1: uvNorm(11, 17),
    uv2: uvNorm(11, 1),
    uv3: uvNorm(1, 1),
  );

  // Right Face (-X)
  addQuad(
    normal: vm.Vector3(-1, 0, 0),
    v0: vm.Vector3(cx - hw, cy - hh, cz - hd),
    v1: vm.Vector3(cx - hw, cy - hh, cz + hd),
    v2: vm.Vector3(cx - hw, cy + hh, cz + hd),
    v3: vm.Vector3(cx - hw, cy + hh, cz - hd),
    uv0: uvNorm(11, 17),
    uv1: uvNorm(12, 17),
    uv2: uvNorm(12, 1),
    uv3: uvNorm(11, 1),
  );

  // Left Face (+X)
  addQuad(
    normal: vm.Vector3(1, 0, 0),
    v0: vm.Vector3(cx + hw, cy - hh, cz + hd),
    v1: vm.Vector3(cx + hw, cy - hh, cz - hd),
    v2: vm.Vector3(cx + hw, cy + hh, cz - hd),
    v3: vm.Vector3(cx + hw, cy + hh, cz + hd),
    uv0: uvNorm(0, 17),
    uv1: uvNorm(1, 17),
    uv2: uvNorm(1, 1),
    uv3: uvNorm(0, 1),
  );

  // Top Face (+Y)
  addQuad(
    normal: vm.Vector3(0, 1, 0),
    v0: vm.Vector3(cx - hw, cy + hh, cz + hd),
    v1: vm.Vector3(cx + hw, cy + hh, cz + hd),
    v2: vm.Vector3(cx + hw, cy + hh, cz - hd),
    v3: vm.Vector3(cx - hw, cy + hh, cz - hd),
    uv0: uvNorm(1, 1),
    uv1: uvNorm(11, 1),
    uv2: uvNorm(11, 0),
    uv3: uvNorm(1, 0),
  );

  // Bottom Face (-Y)
  addQuad(
    normal: vm.Vector3(0, -1, 0),
    v0: vm.Vector3(cx - hw, cy - hh, cz - hd),
    v1: vm.Vector3(cx + hw, cy - hh, cz - hd),
    v2: vm.Vector3(cx + hw, cy - hh, cz + hd),
    v3: vm.Vector3(cx - hw, cy - hh, cz + hd),
    uv0: uvNorm(21, 1),
    uv1: uvNorm(11, 1),
    uv2: uvNorm(11, 0),
    uv3: uvNorm(21, 0),
  );

  final geometry = builder.build();
  final material = lit
      ? createLitSkinMaterial(
          texture: capeTexture,
          depthLayer: 3,
          doubleSided: true,
        )
      : createUnlitSkinMaterial(
          texture: capeTexture,
          depthLayer: 3,
          doubleSided: true,
        );

  return Mesh(geometry, material);
}

Node buildCapeNode(
  TextureSource capeTexture, {
  vm.Vector3? position,
  double? angle,
  bool lit = false,
}) {
  final capeMesh = buildCapeMesh(capeTexture, lit: lit);
  final node = Node(mesh: capeMesh)..name = 'cape';
  node.position = position ?? defaultCapeBodyOffset;
  node.rotation = vm.Quaternion.axisAngle(
    vm.Vector3(1, 0, 0),
    angle ?? defaultCapeAngle,
  );
  return node;
}
