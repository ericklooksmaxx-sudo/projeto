import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'bedrock_geometry.dart';
import 'bedrock_rotation.dart';
import 'cape_mesh.dart';
import 'elytra_mesh.dart';
import 'skin_3d_model.dart';

/// 3D model generator for Custom Geometry
///
/// Bedrock entity geometry coordinate system mapped to Flutter Scene:
/// - In bedrock json:
///   - -X is character's right, +X is character's left
///   - +Y is Up, -Y is Down
///   - -Z is Front, +Z is Back (negated: `Z_cam = -Z_bedrock`)
/// - Flutter Scene camera projection has an inverted horizontal axis (view matrix right
///   vector points West/left), so rootNode.scale has X negated (`-scale, scale, scale`),
///   ensuring character right (-X) renders on viewer's left and textures are un-mirrored.
/// - Centering and scaling:
///   - Preserves `X = 0, Z = 0` as the invariant entity spine and rotation pivot.
///   - Offsets only along `Y` (`-centerY`) to center the model vertically in view.
///   - Auto-scales models exceeding standard bounds (32h x 24w x 24d) to fit the viewport.
/// - Performance and mesh batching:
///   - Batches all cubes within a bone into a single [GeometryBuilder] and [Mesh]
///     to prevent GPU buffer exhaustion on mobile
/// - Material and Depth:
///   - Uses `PhysicallyBasedMaterial` with `AlphaMode.mask` and `alphaCutoff = 0.5`
///     so fragments write to and test against the depth buffer, preventing internal
///     cubes from bleeding onto outer faces.
/// - Box UV Unfolding:
///   - `[West: d x h] [North: w x h] [East: d x h] [South: w x h]`
///   - Top row: `[Up: w x d] [Down: w x d]`
///   - North face is Front (+Z), South is Back (-Z), West is Right (-X), East is Left (+X).
///   - Mirror UV swaps West/East and flips U horizontally.
class BedrockCustomModel implements Skin3DModel {
  final BedrockGeometry geometry;

  @override
  late final Node rootNode;
  final Map<String, Node> boneNodes = {};
  final List<Material> _materials = [];
  final Map<int, Material> _materialPool = {};

  Material _getOrCreateMaterial({
    required int depthLayer,
    required bool doubleSided,
  }) {
    final key = (depthLayer << 1) | (doubleSided ? 1 : 0);
    return _materialPool.putIfAbsent(key, () {
      final mat = createUnlitSkinMaterial(
        depthLayer: depthLayer,
        doubleSided: doubleSided,
      );
      _materials.add(mat);
      return mat;
    });
  }

  // Standard animation bone references (if present in custom geometry)
  Node? headNode;
  Node? bodyNode;
  Node? rightArmNode;
  Node? leftArmNode;
  Node? rightLegNode;
  Node? leftLegNode;

  vm.Quaternion _headRestRotation = vm.Quaternion.identity();
  vm.Quaternion _bodyRestRotation = vm.Quaternion.identity();
  vm.Quaternion _rightArmRestRotation = vm.Quaternion.identity();
  vm.Quaternion _leftArmRestRotation = vm.Quaternion.identity();
  vm.Quaternion _rightLegRestRotation = vm.Quaternion.identity();
  vm.Quaternion _leftLegRestRotation = vm.Quaternion.identity();

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

  double _scale = 1.0;

  @override
  double get scale => _scale;

  @override
  set scale(double value) {
    _scale = value;
    // Negate X to correct flutter_scene's inverted horizontal camera projection
    rootNode.scale = vm.Vector3(-value, value, value);
  }

  BedrockCustomModel({required this.geometry}) {
    _buildModel();
  }

  void _buildModel() {
    rootNode = Node()..name = geometry.identifier;

    // Calculate overall model bounds (X, Y, Z) to center and auto-scale the character
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;
    double minZ = double.infinity;
    double maxZ = -double.infinity;

    for (final bone in geometry.bones) {
      final px = bone.pivot[0];
      final py = bone.pivot[1];
      final pz = bone.pivot[2];

      vm.Matrix3? boneRotMat;
      if (bone.rotation != null) {
        boneRotMat = bedrockEulerToQuaternion(
          bone.rotation!,
        ).asRotationMatrix();
      }

      for (final cube in bone.cubes) {
        final inf = cube.inflate;
        final x0 = cube.origin[0] - inf;
        final x1 = cube.origin[0] + cube.size[0] + inf;
        final y0 = cube.origin[1] - inf;
        final y1 = cube.origin[1] + cube.size[1] + inf;
        final z0 = -(cube.origin[2] + cube.size[2] + inf);
        final z1 = -(cube.origin[2] - inf);

        if (boneRotMat != null) {
          // Transform the 8 cube corners around the bone pivot
          for (final cx in [x0, x1]) {
            for (final cy in [y0, y1]) {
              for (final cz in [z0, z1]) {
                final local = vm.Vector3(cx - px, cy - py, cz - (-pz));
                final rotated = boneRotMat.transformed(local);
                final wx = px + rotated.x;
                final wy = py + rotated.y;
                final wz = -pz + rotated.z;
                if (wx < minX) minX = wx;
                if (wx > maxX) maxX = wx;
                if (wy < minY) minY = wy;
                if (wy > maxY) maxY = wy;
                if (wz < minZ) minZ = wz;
                if (wz > maxZ) maxZ = wz;
              }
            }
          }
        } else {
          if (x0 < minX) minX = x0;
          if (x1 > maxX) maxX = x1;
          if (y0 < minY) minY = y0;
          if (y1 > maxY) maxY = y1;
          if (z0 < minZ) minZ = z0;
          if (z1 > maxZ) maxZ = z1;
        }
      }
    }

    if (minY == double.infinity) {
      minX = -8.0;
      maxX = 8.0;
      minY = 0.0;
      maxY = 32.0;
      minZ = -4.0;
      maxZ = 4.0;
    }

    final modelWidth = (maxX - minX).abs();
    final modelHeight = (maxY - minY).abs();
    final modelDepth = (maxZ - minZ).abs();

    final centerY = (minY + maxY) / 2.0;

    // Standard Minecraft player reference dimensions (height 32, width 16, depth 8)
    // If a custom geometry is larger than standard dimensions, scale it down to fit the viewport.
    const double standardHeight = 32.0;
    const double maxAllowedWidth = 24.0;
    const double maxAllowedDepth = 24.0;

    _scale = 1.0;
    if (modelHeight > standardHeight && modelHeight > 0) {
      _scale = math.min(_scale, standardHeight / modelHeight);
    }
    if (modelWidth > maxAllowedWidth && modelWidth > 0) {
      _scale = math.min(_scale, maxAllowedWidth / modelWidth);
    }
    if (modelDepth > maxAllowedDepth && modelDepth > 0) {
      _scale = math.min(_scale, maxAllowedDepth / modelDepth);
    }

    rootNode.scale = vm.Vector3(-_scale, _scale, _scale);

    // Center model along Y so it is vertically centered in the viewport
    // In Minecraft, (X = 0, Z = 0) is the natural center of the entity's spine and rotation pivot.
    // Offsetting X or Z causes models with asymmetrical parts (e.g, hair, one raised arm, weapon)
    // to be shifted horizontally
    final modelOffsetNode = Node()
      ..name = 'model_offset'
      ..position = vm.Vector3(0.0, -centerY, 0.0);
    rootNode.add(modelOffsetNode);

    // Each bone gets its own unique Node tracked by index
    // Some Bedrock geometry files have duplicate bone names; putIfAbsent ensures
    // we get the first occurrence for parent/animation lookups
    final Map<String, BedrockBone> boneMap = {};
    final List<Node> boneNodeList = [];

    for (final bone in geometry.bones) {
      final node = Node()..name = bone.name;
      boneNodeList.add(node);

      boneNodes.putIfAbsent(bone.name, () => node);
      boneMap.putIfAbsent(bone.name, () => bone);

      // Check for standard humanoid bones for animations
      if (bone.name == 'head' && headNode == null) headNode = node;
      if (bone.name == 'body' && bodyNode == null) bodyNode = node;
      if (bone.name == 'rightArm' && rightArmNode == null) rightArmNode = node;
      if (bone.name == 'leftArm' && leftArmNode == null) leftArmNode = node;
      if (bone.name == 'rightLeg' && rightLegNode == null) rightLegNode = node;
      if (bone.name == 'leftLeg' && leftLegNode == null) leftLegNode = node;
    }

    // Connect bone hierarchy and set relative positions
    // In camera space: X and Y are unchanged, Z is negated (-Z_bedrock)
    // Uses index-based iteration so each bone entry gets its own unique Node,
    // even if multiple bones share the same name
    for (int i = 0; i < geometry.bones.length; i++) {
      final bone = geometry.bones[i];
      final node = boneNodeList[i];
      final px = bone.pivot[0];
      final py = bone.pivot[1];
      final pz = bone.pivot[2];

      if (bone.parent != null && boneMap.containsKey(bone.parent)) {
        final parentBone = boneMap[bone.parent]!;
        final parentNode = boneNodes[bone.parent]!;
        // Relative to parent pivot:
        node.position = vm.Vector3(
          px - parentBone.pivot[0],
          py - parentBone.pivot[1],
          -(pz - parentBone.pivot[2]),
        );
        parentNode.add(node);
      } else {
        // Root-level bone
        node.position = vm.Vector3(px, py, -pz);
        modelOffsetNode.add(node);
      }

      // Initial bone rotation if defined (in degrees)
      if (bone.rotation != null) {
        node.rotation = bedrockEulerToQuaternion(bone.rotation!);
      }

      // single batched mesh for all cubes
      if (bone.cubes.isNotEmpty) {
        int boneDepthLayer = 0;
        String? curParent = bone.parent;
        while (curParent != null) {
          final parentBone = boneMap[curParent];
          if (parentBone != null) {
            boneDepthLayer++;
            curParent = parentBone.parent;
          } else {
            break;
          }
        }
        boneDepthLayer = boneDepthLayer.clamp(0, 8);

        final mesh = _createBoneMesh(bone, depthLayer: boneDepthLayer);
        if (mesh != null) {
          node.add(Node(mesh: mesh)..name = '${bone.name}_mesh_$i');
        }
      }
    }

    // Capture rest rotations for animation blending and pose resets
    if (headNode != null) _headRestRotation = headNode!.rotation.clone();
    if (bodyNode != null) _bodyRestRotation = bodyNode!.rotation.clone();
    if (rightArmNode != null) {
      _rightArmRestRotation = rightArmNode!.rotation.clone();
    }
    if (leftArmNode != null) {
      _leftArmRestRotation = leftArmNode!.rotation.clone();
    }
    if (rightLegNode != null) {
      _rightLegRestRotation = rightLegNode!.rotation.clone();
    }
    if (leftLegNode != null) {
      _leftLegRestRotation = leftLegNode!.rotation.clone();
    }
  }

  @override
  void setTexture(TextureSource texture) {
    for (final mat in _materials) {
      setMaterialTexture(mat, texture);
    }
  }

  /// Attaches a standard Minecraft cape to this model.
  /// The cape is attached to the `body` bone (or model root) at the upper back
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

    final Node node;
    if (_backEquipment == BackEquipment.cape) {
      node = buildCapeNode(_capeTexture!);
    } else {
      final elytra = buildElytraNode(_capeTexture!);
      elytra.position = defaultCapeBodyOffset;
      node = elytra;
    }

    capeNode = node;

    // Attach relative to body bone if present, otherwise attach to root/offset
    if (bodyNode != null) {
      node.position = defaultCapeBodyOffset;
      bodyNode!.add(node);
    } else {
      // Fallback: attach to root / modelOffsetNode (at shoulder height ~24)
      node.position = vm.Vector3(
        defaultCapeBodyOffset.x,
        24.0 + defaultCapeBodyOffset.y,
        defaultCapeBodyOffset.z,
      );
      if (rootNode.children.isNotEmpty) {
        rootNode.children.first.add(node);
      } else {
        rootNode.add(node);
      }
    }
  }

  /// Removes the cape if currently attached
  @override
  void removeCape() {
    if (capeNode != null) {
      capeNode!.parent?.remove(capeNode!);
      capeNode = null;
    }
    _capeTexture = null;
    _backEquipment = null;
  }

  /// Resets limb rotations to default rest pose
  @override
  void resetPose() {
    headNode?.rotation = _headRestRotation.clone();
    bodyNode?.rotation = _bodyRestRotation.clone();
    rightArmNode?.rotation = _rightArmRestRotation.clone();
    leftArmNode?.rotation = _leftArmRestRotation.clone();
    rightLegNode?.rotation = _rightLegRestRotation.clone();
    leftLegNode?.rotation = _leftLegRestRotation.clone();
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

  /// Applies sinusoidal walk animation to standard bones
  @override
  void applyWalkAnimation(double t, {double speed = 4.0}) {
    final angle = math.sin(t * speed);
    const maxArmAngle = 0.6;
    const maxLegAngle = 0.5;

    // Relative swing rotations
    final swingRArm = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      -angle * maxArmAngle,
    );
    final swingLArm = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      angle * maxArmAngle,
    );
    final swingRLeg = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      angle * maxLegAngle,
    );
    final swingLLeg = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      -angle * maxLegAngle,
    );
    final bobHead = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      math.sin(t * speed * 0.5) * 0.08,
    );

    // Combine rest rotation with walk swing so models with A-pose or custom limb angles
    // preserve their rest pose while walking or standing
    rightArmNode?.rotation = _rightArmRestRotation * swingRArm;
    leftArmNode?.rotation = _leftArmRestRotation * swingLArm;
    rightLegNode?.rotation = _rightLegRestRotation * swingRLeg;
    leftLegNode?.rotation = _leftLegRestRotation * swingLLeg;
    headNode?.rotation = _headRestRotation * bobHead;

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

  /// Builds a single batched mesh
  /// All cubes share a single [GeometryBuilder], single GPU DeviceBuffer
  Mesh? _createBoneMesh(BedrockBone bone, {int depthLayer = 0}) {
    final bool has2DPlane = bone.cubes.any(
      (c) => c.size[0] == 0 || c.size[1] == 0 || c.size[2] == 0,
    );
    final px = bone.pivot[0];
    final py = bone.pivot[1];
    final pz = bone.pivot[2];

    final texW = geometry.textureWidth;
    final texH = geometry.textureHeight;

    vm.Vector2 uvNorm(double pu, double pv) => vm.Vector2(pu / texW, pv / texH);

    final builder = GeometryBuilder(deduplicate: false);

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

      // CCW winding: (0, 1, 2) and (0, 2, 3)
      builder.addTriangle(i0, i1, i2);
      builder.addTriangle(i0, i2, i3);
    }

    for (final cube in bone.cubes) {
      final inf = cube.inflate;
      final w = cube.size[0];
      final h = cube.size[1];
      final d = cube.size[2];

      // Local coordinates in camera space:
      // fromX / toX: Left (-X) to Right (+X)
      // fromY / toY: Bottom (-Y) to Top (+Y)
      // fromZ / toZ: Back (-Z) to Front (+Z)
      final fromX = (cube.origin[0] - px) - inf;
      final toX = (cube.origin[0] + w - px) + inf;
      final fromY = (cube.origin[1] - py) - inf;
      final toY = (cube.origin[1] + h - py) + inf;
      final fromZ = -(cube.origin[2] + d - pz) - inf;
      final toZ = -(cube.origin[2] - pz) + inf;

      final u = cube.uv[0];
      final v = cube.uv[1];

      final mirror = cube.mirror;

      // In Bedrock Box UV, sizes are floored to integers for UV unwrapping
      final uvW = w.floorToDouble();
      final uvH = h.floorToDouble();
      final uvD = d.floorToDouble();

      // UV Face Coordinates for Bedrock Box UV:
      // [West: d x h] [North: w x h] [East: d x h] [South: w x h]
      // Top row: [Up: w x d] [Down: w x d]
      // In mirror mode:
      // West and East swap texture columns
      // All faces flip horizontally (U inverted)
      final double westU0 = mirror ? u + 2 * uvD + uvW : u;
      final double westU1 = mirror ? u + uvD + uvW : u + uvD;

      final double northU0 = mirror ? u + uvD + uvW : u + uvD;
      final double northU1 = mirror ? u + uvD : u + uvD + uvW;

      final double eastU0 = mirror ? u + uvD : u + uvD + uvW;
      final double eastU1 = mirror ? u : u + 2 * uvD + uvW;

      final double southU0 = mirror ? u + 2 * uvD + 2 * uvW : u + 2 * uvD + uvW;
      final double southU1 = mirror ? u + 2 * uvD + uvW : u + 2 * uvD + 2 * uvW;

      final double upU0 = mirror ? u + uvD + uvW : u + uvD;
      final double upU1 = mirror ? u + uvD : u + uvD + uvW;

      final double downU0 = mirror ? u + uvD + 2 * uvW : u + uvD + uvW;
      final double downU1 = mirror ? u + uvD + uvW : u + uvD + 2 * uvW;

      // North Face (Front, at Z = toZ, facing +Z towards camera)
      if (w > 0 && h > 0 || inf > 0 || (d == 0 && w > 0 && h > 0)) {
        addQuad(
          normal: vm.Vector3(0, 0, 1),
          v0: vm.Vector3(fromX, fromY, toZ),
          v1: vm.Vector3(toX, fromY, toZ),
          v2: vm.Vector3(toX, toY, toZ),
          v3: vm.Vector3(fromX, toY, toZ),
          uv0: uvNorm(northU0, v + uvD + uvH),
          uv1: uvNorm(northU1, v + uvD + uvH),
          uv2: uvNorm(northU1, v + uvD),
          uv3: uvNorm(northU0, v + uvD),
        );
      }

      // South Face (Back, at Z = fromZ, facing -Z away from camera)
      if (w > 0 && h > 0 || inf > 0 || (d == 0 && w > 0 && h > 0)) {
        addQuad(
          normal: vm.Vector3(0, 0, -1),
          v0: vm.Vector3(toX, fromY, fromZ),
          v1: vm.Vector3(fromX, fromY, fromZ),
          v2: vm.Vector3(fromX, toY, fromZ),
          v3: vm.Vector3(toX, toY, fromZ),
          uv0: uvNorm(southU0, v + uvD + uvH),
          uv1: uvNorm(southU1, v + uvD + uvH),
          uv2: uvNorm(southU1, v + uvD),
          uv3: uvNorm(southU0, v + uvD),
        );
      }

      // West Face (Character's Right side, at X = fromX, facing -X)
      if (d > 0 && h > 0 || inf > 0 || (w == 0 && d > 0 && h > 0)) {
        addQuad(
          normal: vm.Vector3(-1, 0, 0),
          v0: vm.Vector3(fromX, fromY, fromZ),
          v1: vm.Vector3(fromX, fromY, toZ),
          v2: vm.Vector3(fromX, toY, toZ),
          v3: vm.Vector3(fromX, toY, fromZ),
          uv0: uvNorm(westU0, v + uvD + uvH),
          uv1: uvNorm(westU1, v + uvD + uvH),
          uv2: uvNorm(westU1, v + uvD),
          uv3: uvNorm(westU0, v + uvD),
        );
      }

      // East Face (Character's Left side, at X = toX, facing +X)
      if (d > 0 && h > 0 || inf > 0 || (w == 0 && d > 0 && h > 0)) {
        addQuad(
          normal: vm.Vector3(1, 0, 0),
          v0: vm.Vector3(toX, fromY, toZ),
          v1: vm.Vector3(toX, fromY, fromZ),
          v2: vm.Vector3(toX, toY, fromZ),
          v3: vm.Vector3(toX, toY, toZ),
          uv0: uvNorm(eastU0, v + uvD + uvH),
          uv1: uvNorm(eastU1, v + uvD + uvH),
          uv2: uvNorm(eastU1, v + uvD),
          uv3: uvNorm(eastU0, v + uvD),
        );
      }

      // Up Face (Top, at Y = toY, facing +Y)
      if (w > 0 && d > 0 || inf > 0 || (h == 0 && w > 0 && d > 0)) {
        addQuad(
          normal: vm.Vector3(0, 1, 0),
          v0: vm.Vector3(fromX, toY, toZ),
          v1: vm.Vector3(toX, toY, toZ),
          v2: vm.Vector3(toX, toY, fromZ),
          v3: vm.Vector3(fromX, toY, fromZ),
          uv0: uvNorm(upU0, v + uvD),
          uv1: uvNorm(upU1, v + uvD),
          uv2: uvNorm(upU1, v),
          uv3: uvNorm(upU0, v),
        );
      }

      // Down Face (Bottom, at Y = fromY, facing -Y)
      if (w > 0 && d > 0 || inf > 0 || (h == 0 && w > 0 && d > 0)) {
        addQuad(
          normal: vm.Vector3(0, -1, 0),
          v0: vm.Vector3(fromX, fromY, fromZ),
          v1: vm.Vector3(toX, fromY, fromZ),
          v2: vm.Vector3(toX, fromY, toZ),
          v3: vm.Vector3(fromX, fromY, toZ),
          uv0: uvNorm(downU0, v),
          uv1: uvNorm(downU1, v),
          uv2: uvNorm(downU1, v + uvD),
          uv3: uvNorm(downU0, v + uvD),
        );
      }
    }

    if (builder.vertexCount == 0) return null;

    final meshGeo = builder.build();
    final material = _getOrCreateMaterial(
      depthLayer: depthLayer,
      doubleSided: has2DPlane,
    );

    return Mesh(meshGeo, material);
  }
}
