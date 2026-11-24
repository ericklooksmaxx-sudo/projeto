import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'cape_mesh.dart';
import 'elytra_mesh.dart';
import 'skin_3d_model.dart';

/// 3D character model generator
/// Builds a complete hierarchical 3D character mesh (inner + outer layers)

class MinecraftSkinModel implements Skin3DModel {
  final bool isSlim;

  // Root node and limb nodes
  @override
  late final Node rootNode;
  late final Node headNode;
  late final Node torsoNode;
  late final Node rightArmNode;
  late final Node leftArmNode;
  late final Node rightLegNode;
  late final Node leftLegNode;

  @override
  Node? capeNode;

  TextureSource? _capeTexture;
  BackEquipment? _backEquipment;

  @override
  BackEquipment? get backEquipment => _backEquipment;

  @override
  bool get hasCape => _capeTexture != null;

  @override
  TextureSource? get capeTexture => _capeTexture;

  // Shared material for all limb meshes
  Material? _skinMaterial;

  Material get _effectiveSkinMaterial =>
      _skinMaterial ??= createUnlitSkinMaterial(doubleSided: false);

  MinecraftSkinModel({this.isSlim = false}) {
    _buildModel();
  }

  double _scale = 1.0;

  @override
  double get scale => _scale;

  @override
  set scale(double value) {
    _scale = value;
    // Negate X to correct flutter_scene's inverted horizontal camera projection,
    // ensuring character right (-X) renders on viewer's left and textures are un-mirrored.
    rootNode.scale = vm.Vector3(-value, value, value);
  }

  /// The width of arms (4 for classic, 3 for slim).
  double get armWidth => isSlim ? 3.0 : 4.0;

  void _buildModel() {
    rootNode = Node()..name = 'root';
    rootNode.scale = vm.Vector3(-_scale, _scale, _scale);

    // Center model at (0, 0, 0): feet at Y = -16, head top at Y = +16 (matching BedrockCustomModel)
    final modelOffsetNode = Node()
      ..name = 'model_offset'
      ..position = vm.Vector3(0, 2.0, 0);
    rootNode.add(modelOffsetNode);

    // Torso (centered at 0, 0, 0)
    // Box: w=8, h=12, d=4. Y ranges from -6 to +6.
    torsoNode = Node()..name = 'torso';
    final torsoBuilder = GeometryBuilder(deduplicate: false);
    _addBoxGeometry(
      torsoBuilder,
      w: 8,
      h: 12,
      d: 4,
      u: 16,
      v: 16,
      dilation: 0.0,
      centerOffset: vm.Vector3(0, 0, 0),
    );
    _addBoxGeometry(
      torsoBuilder,
      w: 8,
      h: 12,
      d: 4,
      u: 16,
      v: 32,
      dilation: 0.25,
      centerOffset: vm.Vector3(0, 0, 0),
    );
    torsoNode.add(Node(mesh: _finalizeMesh(torsoBuilder))..name = 'torso_mesh');
    modelOffsetNode.add(torsoNode);

    // Head (pivot at neck: 0, 6, 0)
    // Box: w=8, h=8, d=8. Head center relative to neck: (0, 4, 0).
    headNode = Node()
      ..name = 'head'
      ..position = vm.Vector3(0, 6, 0);
    final headBuilder = GeometryBuilder(deduplicate: false);
    _addBoxGeometry(
      headBuilder,
      w: 8,
      h: 8,
      d: 8,
      u: 0,
      v: 0,
      dilation: 0.0,
      centerOffset: vm.Vector3(0, 4, 0),
    );
    _addBoxGeometry(
      headBuilder,
      w: 8,
      h: 8,
      d: 8,
      u: 32,
      v: 0,
      dilation: 0.5,
      centerOffset: vm.Vector3(0, 4, 0),
    );
    headNode.add(Node(mesh: _finalizeMesh(headBuilder))..name = 'head_mesh');
    modelOffsetNode.add(headNode);

    // Right Arm (pivot at shoulder: -4 - armWidth/2, 5, 0)
    // Center relative to shoulder: (0, -5, 0)
    final rArmPivotX = -4.0 - (armWidth / 2.0);
    rightArmNode = Node()
      ..name = 'rightArm'
      ..position = vm.Vector3(rArmPivotX, 5, 0);
    final rArmBuilder = GeometryBuilder(deduplicate: false);
    _addBoxGeometry(
      rArmBuilder,
      w: armWidth,
      h: 12,
      d: 4,
      u: 40,
      v: 16,
      dilation: 0.0,
      centerOffset: vm.Vector3(0, -5, 0),
    );
    _addBoxGeometry(
      rArmBuilder,
      w: armWidth,
      h: 12,
      d: 4,
      u: 40,
      v: 32,
      dilation: 0.25,
      centerOffset: vm.Vector3(0, -5, 0),
    );
    rightArmNode.add(
      Node(mesh: _finalizeMesh(rArmBuilder))..name = 'right_arm_mesh',
    );
    modelOffsetNode.add(rightArmNode);

    // Left Arm (pivot at shoulder: +4 + armWidth/2, 5, 0)
    final lArmPivotX = 4.0 + (armWidth / 2.0);
    leftArmNode = Node()
      ..name = 'leftArm'
      ..position = vm.Vector3(lArmPivotX, 5, 0);
    final lArmBuilder = GeometryBuilder(deduplicate: false);
    _addBoxGeometry(
      lArmBuilder,
      w: armWidth,
      h: 12,
      d: 4,
      u: 32,
      v: 48,
      dilation: 0.0,
      centerOffset: vm.Vector3(0, -5, 0),
    );
    _addBoxGeometry(
      lArmBuilder,
      w: armWidth,
      h: 12,
      d: 4,
      u: 48,
      v: 48,
      dilation: 0.25,
      centerOffset: vm.Vector3(0, -5, 0),
    );
    leftArmNode.add(
      Node(mesh: _finalizeMesh(lArmBuilder))..name = 'left_arm_mesh',
    );
    modelOffsetNode.add(leftArmNode);

    // Right Leg (pivot at hip: -2, -6, 0)
    // Center relative to hip: (0, -6, 0)
    rightLegNode = Node()
      ..name = 'rightLeg'
      ..position = vm.Vector3(-2, -6, 0);
    final rLegBuilder = GeometryBuilder(deduplicate: false);
    _addBoxGeometry(
      rLegBuilder,
      w: 4,
      h: 12,
      d: 4,
      u: 0,
      v: 16,
      dilation: 0.0,
      centerOffset: vm.Vector3(0, -6, 0),
    );
    _addBoxGeometry(
      rLegBuilder,
      w: 4,
      h: 12,
      d: 4,
      u: 0,
      v: 32,
      dilation: 0.25,
      centerOffset: vm.Vector3(0, -6, 0),
    );
    rightLegNode.add(
      Node(mesh: _finalizeMesh(rLegBuilder))..name = 'right_leg_mesh',
    );
    modelOffsetNode.add(rightLegNode);

    // Left Leg (pivot at hip: +2, -6, 0)
    leftLegNode = Node()
      ..name = 'leftLeg'
      ..position = vm.Vector3(2, -6, 0);
    final lLegBuilder = GeometryBuilder(deduplicate: false);
    _addBoxGeometry(
      lLegBuilder,
      w: 4,
      h: 12,
      d: 4,
      u: 16,
      v: 48,
      dilation: 0.0,
      centerOffset: vm.Vector3(0, -6, 0),
    );
    _addBoxGeometry(
      lLegBuilder,
      w: 4,
      h: 12,
      d: 4,
      u: 0,
      v: 48,
      dilation: 0.25,
      centerOffset: vm.Vector3(0, -6, 0),
    );
    leftLegNode.add(
      Node(mesh: _finalizeMesh(lLegBuilder))..name = 'left_leg_mesh',
    );
    modelOffsetNode.add(leftLegNode);
  }

  /// Updates the diffuse/emissive texture on all mesh materials in this model
  @override
  void setTexture(TextureSource texture) {
    setMaterialTexture(_effectiveSkinMaterial, texture);
  }

  /// Attaches a standard Minecraft cape to the torso
  @override
  void attachCape(TextureSource capeTexture) {
    _capeTexture = capeTexture;
    _backEquipment = BackEquipment.cape;
    _rebuildBackEquipment();
  }

  void attachElytra(TextureSource capeTexture) {
    _capeTexture = capeTexture;
    _backEquipment = BackEquipment.elytra;
    _rebuildBackEquipment();
  }

  /// Switch between Cape and Elytra
  @override
  void setBackEquipment(BackEquipment equipment) {
    if (_backEquipment == equipment) return;
    _backEquipment = equipment;
    _rebuildBackEquipment();
  }

  void _rebuildBackEquipment() {
    if (capeNode != null) {
      capeNode!.parent?.remove(capeNode!);
      capeNode = null;
    }

    if (_capeTexture == null || _backEquipment == null) return;

    final capePos = vm.Vector3(
      defaultCapeBodyOffset.x,
      6.0 + defaultCapeBodyOffset.y,
      defaultCapeBodyOffset.z,
    );

    if (_backEquipment == BackEquipment.cape) {
      final node = buildCapeNode(_capeTexture!, position: capePos);
      capeNode = node;
      torsoNode.add(node);
    } else if (_backEquipment == BackEquipment.elytra) {
      final elytraRoot = buildElytraNode(_capeTexture!);
      elytraRoot.position = capePos;
      capeNode = elytraRoot;
      torsoNode.add(elytraRoot);
    }
  }

  /// Removes the cape/elytra if currently attached.
  @override
  void removeCape() {
    if (capeNode != null) {
      capeNode!.parent?.remove(capeNode!);
      capeNode = null;
    }
    _capeTexture = null;
    _backEquipment = null;
  }

  /// Resets limb rotations to default standing pose.
  @override
  void resetPose() {
    headNode.rotation = vm.Quaternion.identity();
    torsoNode.rotation = vm.Quaternion.identity();
    rightArmNode.rotation = vm.Quaternion.identity();
    leftArmNode.rotation = vm.Quaternion.identity();
    rightLegNode.rotation = vm.Quaternion.identity();
    leftLegNode.rotation = vm.Quaternion.identity();
    if (capeNode != null) {
      if (_backEquipment == BackEquipment.elytra) {
        resetElytraJoints(capeNode!);
      } else {
        capeNode!.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(1, 0, 0),
          defaultCapeAngle,
        );
      }
    }
  }

  /// Applies a sinusoidal walk animation at time [t] (in seconds).
  @override
  void applyWalkAnimation(double t, {double speed = 4.0}) {
    final angle = math.sin(t * speed);
    const maxArmAngle = 0.6; // radians (~35 deg)
    const maxLegAngle = 0.5; // radians (~28 deg)

    // Left arm and Right leg move together, right arm and left leg move opposite
    rightArmNode.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      -angle * maxArmAngle,
    );
    leftArmNode.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      angle * maxArmAngle,
    );
    rightLegNode.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      angle * maxLegAngle,
    );
    leftLegNode.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      -angle * maxLegAngle,
    );

    // Subtle head bob
    headNode.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      math.sin(t * speed * 0.5) * 0.08,
    );

    if (capeNode != null) {
      if (_backEquipment == BackEquipment.elytra) {
        applyElytraWalkAnimation(capeNode!, t, speed: speed);
      } else {
        final flutter = math.sin(t * speed).abs() * 0.15;
        capeNode!.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(1, 0, 0),
          defaultCapeAngle + flutter,
        );
      }
    }
  }

  /// Creates a finalized Mesh with unlit material from a completed [GeometryBuilder].
  Mesh _finalizeMesh(GeometryBuilder builder) {
    final geometry = builder.build();
    return Mesh(geometry, _effectiveSkinMaterial);
  }

  /// Adds a single textured cuboid to [builder] without creating GPU resources
  /// We must use `deduplicate: false` on the builder because different faces
  /// share positions but need distinct UV coordinates and face normals
  void _addBoxGeometry(
    GeometryBuilder builder, {
    required double w,
    required double h,
    required double d,
    required double u,
    required double v,
    required double dilation,
    required vm.Vector3 centerOffset,
  }) {
    final hw = (w / 2.0) + dilation;
    final hh = (h / 2.0) + dilation;
    final hd = (d / 2.0) + dilation;
    final cx = centerOffset.x;
    final cy = centerOffset.y;
    final cz = centerOffset.z;

    const texSize = 64.0;
    vm.Vector2 uvNorm(double px, double py) =>
        vm.Vector2(px / texSize, py / texSize);

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

      // CCW winding order: (0, 1, 2) and (0, 2, 3)
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
      uv0: uvNorm(u + d, v + d + h),
      uv1: uvNorm(u + d + w, v + d + h),
      uv2: uvNorm(u + d + w, v + d),
      uv3: uvNorm(u + d, v + d),
    );

    // Back Face (-Z)
    addQuad(
      normal: vm.Vector3(0, 0, -1),
      v0: vm.Vector3(cx + hw, cy - hh, cz - hd),
      v1: vm.Vector3(cx - hw, cy - hh, cz - hd),
      v2: vm.Vector3(cx - hw, cy + hh, cz - hd),
      v3: vm.Vector3(cx + hw, cy + hh, cz - hd),
      uv0: uvNorm(u + 2 * d + w, v + d + h),
      uv1: uvNorm(u + 2 * d + 2 * w, v + d + h),
      uv2: uvNorm(u + 2 * d + 2 * w, v + d),
      uv3: uvNorm(u + 2 * d + w, v + d),
    );

    // Right Face (-X, character's right side)
    addQuad(
      normal: vm.Vector3(-1, 0, 0),
      v0: vm.Vector3(cx - hw, cy - hh, cz - hd),
      v1: vm.Vector3(cx - hw, cy - hh, cz + hd),
      v2: vm.Vector3(cx - hw, cy + hh, cz + hd),
      v3: vm.Vector3(cx - hw, cy + hh, cz - hd),
      uv0: uvNorm(u, v + d + h),
      uv1: uvNorm(u + d, v + d + h),
      uv2: uvNorm(u + d, v + d),
      uv3: uvNorm(u, v + d),
    );

    // Left Face (+X, character's left side)
    addQuad(
      normal: vm.Vector3(1, 0, 0),
      v0: vm.Vector3(cx + hw, cy - hh, cz + hd),
      v1: vm.Vector3(cx + hw, cy - hh, cz - hd),
      v2: vm.Vector3(cx + hw, cy + hh, cz - hd),
      v3: vm.Vector3(cx + hw, cy + hh, cz + hd),
      uv0: uvNorm(u + d + w, v + d + h),
      uv1: uvNorm(u + 2 * d + w, v + d + h),
      uv2: uvNorm(u + 2 * d + w, v + d),
      uv3: uvNorm(u + d + w, v + d),
    );

    // Top Face (+Y)
    addQuad(
      normal: vm.Vector3(0, 1, 0),
      v0: vm.Vector3(cx - hw, cy + hh, cz + hd),
      v1: vm.Vector3(cx + hw, cy + hh, cz + hd),
      v2: vm.Vector3(cx + hw, cy + hh, cz - hd),
      v3: vm.Vector3(cx - hw, cy + hh, cz - hd),
      uv0: uvNorm(u + d, v + d),
      uv1: uvNorm(u + d + w, v + d),
      uv2: uvNorm(u + d + w, v),
      uv3: uvNorm(u + d, v),
    );

    // Bottom Face (-Y)
    addQuad(
      normal: vm.Vector3(0, -1, 0),
      v0: vm.Vector3(cx - hw, cy - hh, cz - hd),
      v1: vm.Vector3(cx + hw, cy - hh, cz - hd),
      v2: vm.Vector3(cx + hw, cy - hh, cz + hd),
      v3: vm.Vector3(cx - hw, cy - hh, cz + hd),
      uv0: uvNorm(u + d + w, v),
      uv1: uvNorm(u + d + 2 * w, v),
      uv2: uvNorm(u + d + 2 * w, v + d),
      uv3: uvNorm(u + d + w, v + d),
    );
  }
}
