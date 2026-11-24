import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../flutter_gpu/texture_utils.dart';

/// Default pitch for folded wings (~15 deg).
const double defaultElytraPitch = 15.0 * math.pi / 180.0;

/// Default roll for folded wings (~15 deg).
const double defaultElytraRoll = 15.0 * math.pi / 180.0;

/// Vertical offset keeping folded wing tips flush with shoulders.
const double defaultElytraPivotY = -4.2;

/// Slight yaw to prevent z-fighting along the spine.
const double defaultElytraYaw = 0.01;

/// Composes rotation quaternion from Euler angles (pitch X, yaw Y, roll Z).
vm.Quaternion elytraRotation({
  required double pitchX,
  required double yawY,
  required double rollZ,
}) {
  return vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), rollZ) *
      vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yawY) *
      vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pitchX);
}

/// 3D mesh Elytra mapped to 64x32 cape texture
Mesh buildElytraWingMesh(
  TextureSource capeTexture, {
  required bool isRight,
  double dilation = 1.0,
  Material? material,
}) {
  final builder = GeometryBuilder(deduplicate: false);

  const double w = 10.0;
  const double h = 20.0;
  const double d = 2.0;

  final double hw = (w / 2.0) + dilation;
  final double hh = (h / 2.0) + dilation;
  final double hd = (d / 2.0) + dilation;

  // Center of wing relative to pivot (inner edge meets spine at X = 0).
  final double cx = isRight ? 5.0 : -5.0;
  const double cy = -10.0;
  const double cz = -1.0;

  final double xMin = cx - hw;
  final double xMax = cx + hw;
  final double yMin = cy - hh;
  final double yMax = cy + hh;
  final double zMin = cz - hd;
  final double zMax = cz + hd;

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

    // CCW winding
    builder.addTriangle(i0, i1, i2);
    builder.addTriangle(i0, i2, i3);
  }

  // Front (+Z)
  addQuad(
    normal: vm.Vector3(0, 0, 1),
    v0: vm.Vector3(xMin, yMin, zMax),
    v1: vm.Vector3(xMax, yMin, zMax),
    v2: vm.Vector3(xMax, yMax, zMax),
    v3: vm.Vector3(xMin, yMax, zMax),
    uv0: isRight ? uvNorm(24, 22) : uvNorm(34, 22),
    uv1: isRight ? uvNorm(34, 22) : uvNorm(24, 22),
    uv2: isRight ? uvNorm(34, 2) : uvNorm(24, 2),
    uv3: isRight ? uvNorm(24, 2) : uvNorm(34, 2),
  );

  // Back (-Z)
  addQuad(
    normal: vm.Vector3(0, 0, -1),
    v0: vm.Vector3(xMax, yMin, zMin),
    v1: vm.Vector3(xMin, yMin, zMin),
    v2: vm.Vector3(xMin, yMax, zMin),
    v3: vm.Vector3(xMax, yMax, zMin),
    uv0: isRight ? uvNorm(36, 22) : uvNorm(46, 22),
    uv1: isRight ? uvNorm(46, 22) : uvNorm(36, 22),
    uv2: isRight ? uvNorm(46, 2) : uvNorm(36, 2),
    uv3: isRight ? uvNorm(36, 2) : uvNorm(46, 2),
  );

  // Left (+X)
  addQuad(
    normal: vm.Vector3(1, 0, 0),
    v0: vm.Vector3(xMax, yMin, zMax),
    v1: vm.Vector3(xMax, yMin, zMin),
    v2: vm.Vector3(xMax, yMax, zMin),
    v3: vm.Vector3(xMax, yMax, zMax),
    uv0: isRight ? uvNorm(34, 22) : uvNorm(24, 22),
    uv1: isRight ? uvNorm(36, 22) : uvNorm(22, 22),
    uv2: isRight ? uvNorm(36, 2) : uvNorm(22, 2),
    uv3: isRight ? uvNorm(34, 2) : uvNorm(24, 2),
  );

  // Right (-X)
  addQuad(
    normal: vm.Vector3(-1, 0, 0),
    v0: vm.Vector3(xMin, yMin, zMin),
    v1: vm.Vector3(xMin, yMin, zMax),
    v2: vm.Vector3(xMin, yMax, zMax),
    v3: vm.Vector3(xMin, yMax, zMin),
    uv0: isRight ? uvNorm(22, 22) : uvNorm(36, 22),
    uv1: isRight ? uvNorm(24, 22) : uvNorm(34, 22),
    uv2: isRight ? uvNorm(24, 2) : uvNorm(34, 2),
    uv3: isRight ? uvNorm(22, 2) : uvNorm(36, 2),
  );

  // Top (+Y)
  addQuad(
    normal: vm.Vector3(0, 1, 0),
    v0: vm.Vector3(xMin, yMax, zMax),
    v1: vm.Vector3(xMax, yMax, zMax),
    v2: vm.Vector3(xMax, yMax, zMin),
    v3: vm.Vector3(xMin, yMax, zMin),
    uv0: isRight ? uvNorm(24, 2) : uvNorm(34, 2),
    uv1: isRight ? uvNorm(34, 2) : uvNorm(24, 2),
    uv2: isRight ? uvNorm(34, 0) : uvNorm(24, 0),
    uv3: isRight ? uvNorm(24, 0) : uvNorm(34, 0),
  );

  // Bottom (-Y)
  addQuad(
    normal: vm.Vector3(0, -1, 0),
    v0: vm.Vector3(xMin, yMin, zMin),
    v1: vm.Vector3(xMax, yMin, zMin),
    v2: vm.Vector3(xMax, yMin, zMax),
    v3: vm.Vector3(xMin, yMin, zMax),
    uv0: isRight ? uvNorm(34, 0) : uvNorm(44, 0),
    uv1: isRight ? uvNorm(44, 0) : uvNorm(34, 0),
    uv2: isRight ? uvNorm(44, 2) : uvNorm(34, 2),
    uv3: isRight ? uvNorm(34, 2) : uvNorm(44, 2),
  );

  final geometry = builder.build();
  final effectiveMaterial =
      material ??
      createUnlitSkinMaterial(
        texture: capeTexture,
        depthLayer: 3,
        doubleSided: true,
      );

  return Mesh(geometry, effectiveMaterial);
}

Node buildElytraNode(TextureSource capeTexture, {double dilation = 1.0}) {
  final elytraRoot = Node()..name = 'elytra';
  final sharedMaterial = createUnlitSkinMaterial(
    texture: capeTexture,
    depthLayer: 3,
    doubleSided: true,
  );

  final leftWingMesh = buildElytraWingMesh(
    capeTexture,
    isRight: false,
    dilation: dilation,
    material: sharedMaterial,
  );
  final leftWingNode = Node(mesh: leftWingMesh)
    ..name = 'leftWing'
    ..position = vm.Vector3(5, defaultElytraPivotY, 0)
    ..rotation = elytraRotation(
      pitchX: defaultElytraPitch,
      yawY: defaultElytraYaw,
      rollZ: -defaultElytraRoll,
    );

  final rightWingMesh = buildElytraWingMesh(
    capeTexture,
    isRight: true,
    dilation: dilation,
    material: sharedMaterial,
  );
  final rightWingNode = Node(mesh: rightWingMesh)
    ..name = 'rightWing'
    ..position = vm.Vector3(-5, defaultElytraPivotY, 0)
    ..rotation = elytraRotation(
      pitchX: defaultElytraPitch,
      yawY: -defaultElytraYaw,
      rollZ: defaultElytraRoll,
    );

  elytraRoot.add(leftWingNode);
  elytraRoot.add(rightWingNode);

  return elytraRoot;
}

void resetElytraJoints(Node elytraNode) {
  elytraNode.rotation = vm.Quaternion.identity();
  for (final child in elytraNode.children) {
    if (child.name == 'leftWing') {
      child.rotation = elytraRotation(
        pitchX: defaultElytraPitch,
        yawY: defaultElytraYaw,
        rollZ: -defaultElytraRoll,
      );
    } else if (child.name == 'rightWing') {
      child.rotation = elytraRotation(
        pitchX: defaultElytraPitch,
        yawY: -defaultElytraYaw,
        rollZ: defaultElytraRoll,
      );
    }
  }
}

void applyElytraWalkAnimation(Node elytraNode, double t, {double speed = 4.0}) {
  final flutter = math.sin(t * speed).abs() * 0.15;

  elytraNode.rotation = vm.Quaternion.axisAngle(
    vm.Vector3(1, 0, 0),
    flutter * 0.4,
  );

  for (final child in elytraNode.children) {
    if (child.name == 'leftWing') {
      child.rotation = elytraRotation(
        pitchX: defaultElytraPitch + flutter * 0.4,
        yawY: defaultElytraYaw,
        rollZ: -(defaultElytraRoll + flutter * 0.25),
      );
    } else if (child.name == 'rightWing') {
      child.rotation = elytraRotation(
        pitchX: defaultElytraPitch + flutter * 0.4,
        yawY: -defaultElytraYaw,
        rollZ: defaultElytraRoll + flutter * 0.25,
      );
    }
  }
}
