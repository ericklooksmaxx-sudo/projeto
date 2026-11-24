import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show Paint, Rect;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'cape_mesh.dart';
import 'elytra_mesh.dart';
import 'skin_3d_model.dart';
import '../services/persona_glb_service.dart';

/// Standard Bedrock humanoid bone pivots (camera space: X=X, Y=Y, Z=-Z)
const Map<String, List<double>> standardHumanoidPivots = {
  'head': [0.0, 24.0, 0.0],
  'hat': [0.0, 24.0, 0.0],
  'body': [0.0, 24.0, 0.0],
  'waist': [0.0, 12.0, 0.0],
  'hip': [0.0, 12.0, 0.0],
  'rightArm': [-5.0, 22.0, 0.0],
  'rightSleeve': [-5.0, 22.0, 0.0],
  'leftArm': [5.0, 22.0, 0.0],
  'leftSleeve': [5.0, 22.0, 0.0],
  'rightLeg': [-1.9, 12.0, 0.0],
  'rightPants': [-1.9, 12.0, 0.0],
  'leftLeg': [1.9, 12.0, 0.0],
  'leftPants': [1.9, 12.0, 0.0],
  'root': [0.0, 0.0, 0.0],
};

/// 3D model Persona character with cosmetics
class PersonaModel implements Skin3DModel {
  final PersonaPiece piece;

  @override
  late final Node rootNode;

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

  // Node references from persona.glb
  Node? headNode;
  Node? hatNode;
  Node? bodyNode;
  Node? waistNode;
  Node? rightArmNode;
  Node? rightSleeveNode;
  Node? leftArmNode;
  Node? leftSleeveNode;
  Node? rightLegNode;
  Node? rightPantsNode;
  Node? leftLegNode;
  Node? leftPantsNode;
  Node? jacketNode;

  final List<Material> _attachmentMaterials = [];
  final List<Texture2D> _animatedFrames = [];
  final List<Material> _animatedMaterials = [];
  final List<Texture2D> _bodyAnimatedFrames = [];
  Material? _bodyMaterial;
  final List<Texture2D> _headAnimatedFrames = [];
  Material? _headMaterial;
  Material? _hatMaterial;

  static Uint8List? _cachedBaseBodyBytes;
  static Uint8List? _cachedBaseHeadBytes;

  static void invalidateBaseTextures() {
    _cachedBaseBodyBytes = null;
    _cachedBaseHeadBytes = null;
  }

  double _scale = 1.0;

  @override
  double get scale => _scale;

  @override
  set scale(double value) {
    _scale = value;
    rootNode.scale = vm.Vector3(value, value, value);
  }

  PersonaModel._({required this.piece});

  /// Creates a [PersonaModel] for [piece]
  static Future<PersonaModel> create({required PersonaPiece piece}) async {
    await initUnlitMaterials();
    final model = PersonaModel._(piece: piece);
    await model._build();
    return model;
  }

  Future<void> _build() async {
    rootNode = Node()..name = 'persona_root';
    rootNode.scale = vm.Vector3(_scale, _scale, _scale);

    final baseNode = await PersonaGlbService.instance.loadPersonaNode();

    // Center model at origin and face camera
    _setupBaseMaterials(baseNode);
    const double initialYRotation = math.pi;
    final modelOffsetNode = Node()
      ..name = 'persona_offset'
      ..position = vm.Vector3(0, -16.0, 0)
      ..rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        initialYRotation,
      );
    modelOffsetNode.add(baseNode);
    rootNode.add(modelOffsetNode);

    // Discover bone nodes
    headNode = _findNodeByName(baseNode, 'head');
    hatNode = _findNodeByName(baseNode, 'hat');
    bodyNode = _findNodeByName(baseNode, 'body');
    waistNode = _findNodeByName(baseNode, 'waist');
    rightArmNode = _findNodeByName(baseNode, 'rightArm');
    rightSleeveNode = _findNodeByName(baseNode, 'rightSleeve');
    leftArmNode = _findNodeByName(baseNode, 'leftArm');
    leftSleeveNode = _findNodeByName(baseNode, 'leftSleeve');
    rightLegNode = _findNodeByName(baseNode, 'rightLeg');
    rightPantsNode = _findNodeByName(baseNode, 'rightPants');
    leftLegNode = _findNodeByName(baseNode, 'leftLeg');
    leftPantsNode = _findNodeByName(baseNode, 'leftPants');
    jacketNode = _findNodeByName(baseNode, 'jacket');

    // Ensure outer clothing layers draw deterministically over inner body parts
    for (final outerNode in [
      hatNode,
      jacketNode,
      rightSleeveNode,
      leftSleeveNode,
      rightPantsNode,
      leftPantsNode,
    ]) {
      if (outerNode?.mesh != null) {
        for (final prim in outerNode!.mesh!.primitives) {
          prim.material.depthLayer = 1;
        }
      }
    }

    applyNearestTextureFiltering(baseNode);

    await _ensureGlbTexturesLoaded();

    // Check for outer clothing layer pixels
    bool hasHatLayerPixels = false;
    bool hasRightPantsLayerPixels = false;
    bool hasLeftPantsLayerPixels = false;
    bool hasRightSleeveLayerPixels = false;
    bool hasLeftSleeveLayerPixels = false;
    bool hasJacketLayerPixels = false;

    for (final src in piece.textureSources) {
      final texPath = piece.resolveTexturePath(src.texture);
      final framesCount = src.animated && src.frames > 0 ? src.frames : 1;
      if (src.useFaceUv) {
        if (!hasHatLayerPixels &&
            await hasHatLayerPixelsInImage(texPath, frames: framesCount)) {
          hasHatLayerPixels = true;
        }
      } else {
        if (!hasRightPantsLayerPixels &&
            await hasLayerPixelsInImage(
              texPath,
              rightPantsLayerRects,
              frames: framesCount,
            )) {
          hasRightPantsLayerPixels = true;
        }
        if (!hasLeftPantsLayerPixels &&
            await hasLayerPixelsInImage(
              texPath,
              leftPantsLayerRects,
              frames: framesCount,
            )) {
          hasLeftPantsLayerPixels = true;
        }
        if (!hasRightSleeveLayerPixels &&
            await hasLayerPixelsInImage(
              texPath,
              rightSleeveLayerRects,
              frames: framesCount,
            )) {
          hasRightSleeveLayerPixels = true;
        }
        if (!hasLeftSleeveLayerPixels &&
            await hasLayerPixelsInImage(
              texPath,
              leftSleeveLayerRects,
              frames: framesCount,
            )) {
          hasLeftSleeveLayerPixels = true;
        }
        if (!hasJacketLayerPixels &&
            await hasLayerPixelsInImage(
              texPath,
              jacketLayerRects,
              frames: framesCount,
            )) {
          hasJacketLayerPixels = true;
        }
      }
    }

    // Apply texture sources
    for (final src in piece.textureSources) {
      final texPath = piece.resolveTexturePath(src.texture);
      final file = File(texPath);
      if (await file.exists()) {
        try {
          if (piece.isCape) {
            final capeTexture = await loadSkinTexture(texPath);
            attachCape(capeTexture);
          } else if (src.useFaceUv && _cachedBaseHeadBytes != null) {
            // Head texture overlay
            final framesCount = src.animated && src.frames > 0 ? src.frames : 1;
            Texture2D? initialHeadTexture;
            if (framesCount > 1) {
              final frames = await _compositeFrames(
                _cachedBaseHeadBytes!,
                texPath,
                frames: framesCount,
              );
              _headAnimatedFrames.addAll(frames);
              initialHeadTexture = _headAnimatedFrames.first;
            } else {
              initialHeadTexture = await _compositeTexture(
                _cachedBaseHeadBytes!,
                texPath,
                frames: 1,
                frameIndex: 0,
              );
            }

            _applyTextureToNode(headNode, initialHeadTexture);
            if (hasHatLayerPixels) {
              _applyTextureToNode(hatNode, initialHeadTexture);
            }

            if (_headAnimatedFrames.isNotEmpty) {
              for (final prim in (headNode?.mesh?.primitives ?? [])) {
                _headMaterial = prim.material;
                break;
              }
              if (hasHatLayerPixels) {
                for (final prim in (hatNode?.mesh?.primitives ?? [])) {
                  _hatMaterial = prim.material;
                  break;
                }
              }
            }
          } else if (_cachedBaseBodyBytes != null) {
            final framesCount = src.animated && src.frames > 0 ? src.frames : 1;
            Texture2D? initialBodyTexture;
            if (framesCount > 1) {
              final frames = await _compositeFrames(
                _cachedBaseBodyBytes!,
                texPath,
                frames: framesCount,
              );
              _bodyAnimatedFrames.addAll(frames);
              initialBodyTexture = _bodyAnimatedFrames.first;
            } else {
              initialBodyTexture = await _compositeTexture(
                _cachedBaseBodyBytes!,
                texPath,
                frames: 1,
                frameIndex: 0,
              );
            }

            _applyTextureToNode(bodyNode, initialBodyTexture);
            _applyTextureToNode(waistNode, initialBodyTexture);
            _applyTextureToNode(rightArmNode, initialBodyTexture);
            _applyTextureToNode(rightSleeveNode, initialBodyTexture);
            _applyTextureToNode(leftArmNode, initialBodyTexture);
            _applyTextureToNode(leftSleeveNode, initialBodyTexture);
            _applyTextureToNode(rightLegNode, initialBodyTexture);
            _applyTextureToNode(rightPantsNode, initialBodyTexture);
            _applyTextureToNode(leftLegNode, initialBodyTexture);
            _applyTextureToNode(leftPantsNode, initialBodyTexture);
            _applyTextureToNode(jacketNode, initialBodyTexture);

            if (_bodyAnimatedFrames.isNotEmpty) {
              for (final prim in (bodyNode?.mesh?.primitives ?? [])) {
                _bodyMaterial = prim.material;
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Error applying texture source ${src.texture}: $e');
        }
      }
    }

    // Attach 3D geometry
    if (piece.hasGeometry) {
      final geoSources = piece.selectGeometrySources();
      for (final geoSrc in geoSources) {
        // Hide base meshes for replaced zones
        final List<String> effectiveZones;
        if (geoSrc.side != null) {
          effectiveZones = geoSrc.zone.isNotEmpty
              ? geoSrc.zone
              : piece.meta.zone;
        } else {
          effectiveZones = <String>{
            ...geoSrc.zone,
            ...piece.meta.zone,
          }.toList();
        }
        final hasFaceUv = piece.textureSources.any((s) => s.useFaceUv);
        _hideZones(
          effectiveZones,
          hasFaceUv: hasFaceUv,
          hasHatLayerPixels: hasHatLayerPixels,
          hasRightPantsLayerPixels: hasRightPantsLayerPixels,
          hasLeftPantsLayerPixels: hasLeftPantsLayerPixels,
          hasRightSleeveLayerPixels: hasRightSleeveLayerPixels,
          hasLeftSleeveLayerPixels: hasLeftSleeveLayerPixels,
          hasJacketLayerPixels: hasJacketLayerPixels,
        );

        final geometry = await piece.loadGeometry(geoSrc);
        if (geometry != null) {
          _autoHideReplacedBones(
            geometry,
            piece.meta.pieceType,
            hasFaceUv: hasFaceUv,
            hasHatLayerPixels: hasHatLayerPixels,
            hasRightPantsLayerPixels: hasRightPantsLayerPixels,
            hasLeftPantsLayerPixels: hasLeftPantsLayerPixels,
            hasRightSleeveLayerPixels: hasRightSleeveLayerPixels,
            hasLeftSleeveLayerPixels: hasLeftSleeveLayerPixels,
            hasJacketLayerPixels: hasJacketLayerPixels,
            effectiveZones: effectiveZones,
          );
          await _attachGeometry(baseNode, geometry, geoSrc);
        }
      }
    }

    applyNearestTextureFiltering(rootNode);
  }

  void _autoHideReplacedBones(
    PersonaGeometry geometry,
    String pieceType, {
    required bool hasFaceUv,
    bool hasHatLayerPixels = false,
    bool hasRightPantsLayerPixels = false,
    bool hasLeftPantsLayerPixels = false,
    bool hasRightSleeveLayerPixels = false,
    bool hasLeftSleeveLayerPixels = false,
    bool hasJacketLayerPixels = false,
    List<String> effectiveZones = const [],
  }) {
    final type = pieceType.toLowerCase();
    for (final bone in geometry.bones) {
      final name = bone.name.toLowerCase();
      final parent = (bone.parent ?? '').toLowerCase();
      // Arm clothing suppression
      if (!hasRightSleeveLayerPixels &&
          (name.contains('rightarm') ||
              name.contains('right_arm') ||
              parent == 'rightarm')) {
        rightSleeveNode?.mesh = null;
      }
      if (!hasLeftSleeveLayerPixels &&
          (name.contains('leftarm') ||
              name.contains('left_arm') ||
              parent == 'leftarm')) {
        leftSleeveNode?.mesh = null;
      }

      // Torso clothing suppression
      if (type != 'persona_back' &&
          !hasJacketLayerPixels &&
          (name.contains('bodyarmor') ||
              name.contains('body_armor') ||
              (parent == 'body' &&
                  !name.contains('wing') &&
                  !name.contains('tail')))) {
        jacketNode?.mesh = null;
      }

      // Head clothing suppression
      if (!hasHatLayerPixels &&
          (name.contains('helmet') ||
              name.contains('hat') ||
              name.contains('hood'))) {
        hatNode?.mesh = null;
      }

      // Leg clothing suppression
      if (!hasRightPantsLayerPixels &&
          (name.contains('rightboot') ||
              name.contains('rightleg') ||
              parent == 'rightleg')) {
        rightPantsNode?.mesh = null;
      }
      if (!hasLeftPantsLayerPixels &&
          (name.contains('leftboot') ||
              name.contains('leftleg') ||
              parent == 'leftleg')) {
        leftPantsNode?.mesh = null;
      }
    }
  }

  void _hideZones(
    List<String> zones, {
    bool hasFaceUv = false,
    bool hasHatLayerPixels = false,
    bool hasRightPantsLayerPixels = false,
    bool hasLeftPantsLayerPixels = false,
    bool hasRightSleeveLayerPixels = false,
    bool hasLeftSleeveLayerPixels = false,
    bool hasJacketLayerPixels = false,
  }) {
    for (final z in zones) {
      switch (z.toLowerCase()) {
        case 'body':
          bodyNode?.mesh = null;
          if (!hasJacketLayerPixels) {
            jacketNode?.mesh = null;
          }
          break;
        case 'body_clothing':
        case 'jacket':
          if (!hasJacketLayerPixels) {
            jacketNode?.mesh = null;
          }
          break;
        case 'head':
          headNode?.mesh = null;
          hatNode?.mesh = null;
          break;
        case 'head_clothing':
        case 'head_top':
        case 'over_hair':
        case 'hair':
        case 'hat':
          if (!hasHatLayerPixels) {
            hatNode?.mesh = null;
          }
          break;
        case 'left_arm':
        case 'arm_left':
          leftArmNode?.mesh = null;
          if (!hasLeftSleeveLayerPixels) {
            leftSleeveNode?.mesh = null;
          }
          break;
        case 'left_arm_clothing':
        case 'left_sleeve':
          if (!hasLeftSleeveLayerPixels) {
            leftSleeveNode?.mesh = null;
          }
          break;
        case 'right_arm':
        case 'arm_right':
          rightArmNode?.mesh = null;
          if (!hasRightSleeveLayerPixels) {
            rightSleeveNode?.mesh = null;
          }
          break;
        case 'right_arm_clothing':
        case 'right_sleeve':
          if (!hasRightSleeveLayerPixels) {
            rightSleeveNode?.mesh = null;
          }
          break;
        case 'left_leg':
        case 'leg_left':
          leftLegNode?.mesh = null;
          if (!hasLeftPantsLayerPixels) {
            leftPantsNode?.mesh = null;
          }
          break;
        case 'left_leg_clothing':
        case 'left_pants':
          if (!hasLeftPantsLayerPixels) {
            leftPantsNode?.mesh = null;
          }
          break;
        case 'right_leg':
        case 'leg_right':
          rightLegNode?.mesh = null;
          if (!hasRightPantsLayerPixels) {
            rightPantsNode?.mesh = null;
          }
          break;
        case 'right_leg_clothing':
        case 'right_pants':
          if (!hasRightPantsLayerPixels) {
            rightPantsNode?.mesh = null;
          }
          break;
      }
    }
  }

  Future<void> _attachGeometry(
    Node baseNode,
    PersonaGeometry geometry,
    PersonaGeometrySource geoSrc,
  ) async {
    await initUnlitMaterials();
    final texPath = piece.resolveTexturePath(geoSrc.texture);
    final texFile = File(texPath);

    double texW = geometry.textureWidth ?? 128.0;
    double texH = geometry.textureHeight ?? 128.0;
    int frames = geoSrc.animated && geoSrc.frames > 0 ? geoSrc.frames : 1;

    Texture2D? attachmentTexture;
    if (await texFile.exists()) {
      try {
        final bytes = await texFile.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        texW = geometry.textureWidth ?? image.width.toDouble();
        texH = geometry.textureHeight ?? image.height.toDouble();

        const sampling = nearestTextureSampling;

        if (frames > 1) {
          final frameH = image.height ~/ frames;
          final frameW = image.width;
          for (int f = 0; f < frames; f++) {
            final recorder = ui.PictureRecorder();
            final canvas = ui.Canvas(recorder);
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(
                0,
                (f * frameH).toDouble(),
                frameW.toDouble(),
                frameH.toDouble(),
              ),
              Rect.fromLTWH(0, 0, frameW.toDouble(), frameH.toDouble()),
              Paint(),
            );
            final pic = recorder.endRecording();
            final fImg = await pic.toImage(frameW, frameH);
            final tex = await Texture2D.fromImage(fImg, sampling: sampling);
            fImg.dispose();
            _animatedFrames.add(tex);
          }
          attachmentTexture = _animatedFrames.isNotEmpty
              ? _animatedFrames.first
              : null;
        } else {
          attachmentTexture = await loadSkinTexture(texPath);
        }
        image.dispose();
      } catch (e) {
        debugPrint('Error loading attachment texture $texPath: $e');
      }
    }

    for (int i = 0; i < geometry.bones.length; i++) {
      final bone = geometry.bones[i];
      if (!bone.hasGeometry) continue;

      final (targetNode, defaultPivot) = _resolveTargetNodeAndPivot(
        baseNode,
        bone,
      );

      // Determine effective pivot
      final List<double> effectivePivot;
      if (bone.pivot != null && !bone.pivot!.every((v) => v == 0.0)) {
        effectivePivot = bone.pivot!;
      } else {
        effectivePivot = defaultPivot;
      }

      // Node position relative to pivot
      final vm.Vector3 nodePos;
      if (bone.pivot != null) {
        nodePos = vm.Vector3(
          bone.pivot![0] - defaultPivot[0],
          bone.pivot![1] - defaultPivot[1],
          -(bone.pivot![2] - defaultPivot[2]),
        );
      } else {
        nodePos = vm.Vector3.zero();
      }

      // Bone rotation
      vm.Quaternion? nodeRot;
      if (bone.rotation != null) {
        nodeRot = _eulerToQuaternion(bone.rotation!);
      }

      // Hierarchical depthLayer so child overlay bones (e.g. helmet on head) draw deterministically over parent bones
      int boneDepthLayer = 1;
      String? curParent = bone.parent;
      while (curParent != null) {
        final parentBone = geometry.bones
            .where((b) => b.name == curParent)
            .firstOrNull;
        if (parentBone != null) {
          boneDepthLayer++;
          curParent = parentBone.parent;
        } else {
          break;
        }
      }
      boneDepthLayer = boneDepthLayer.clamp(1, 8);

      final perFrameTexH =
          geometry.textureHeight ?? (frames > 1 ? (texH / frames) : texH);
      final mesh = _createPerFaceBoneMesh(
        bone,
        effectivePivot: effectivePivot,
        texW: texW,
        texH: perFrameTexH,
        frames: 1,
        texture: attachmentTexture,
        depthLayer: boneDepthLayer,
      );

      if (mesh != null) {
        if (_animatedFrames.isNotEmpty) {
          for (final prim in mesh.primitives) {
            _animatedMaterials.add(prim.material);
          }
        }
        final attachNode = Node(mesh: mesh)..name = '${bone.name}_mesh_$i';
        attachNode.position = nodePos;
        if (nodeRot != null) attachNode.rotation = nodeRot;
        targetNode.add(attachNode);
      }
    }
  }

  /// Builds a batched mesh for a bone
  Mesh? _createPerFaceBoneMesh(
    PersonaBone bone, {
    required List<double> effectivePivot,
    required double texW,
    required double texH,
    required int frames,
    TextureSource? texture,
    int depthLayer = 1,
  }) {
    final px = effectivePivot[0];
    final py = effectivePivot[1];
    final pz = effectivePivot[2];

    final frameH = texH / frames;

    vm.Vector2 uvNorm(double u, double v, [int frameIndex = 0]) {
      return vm.Vector2(u / texW, (v + frameIndex * frameH) / texH);
    }

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

      // CCW winding
      builder.addTriangle(i0, i1, i2);
      builder.addTriangle(i0, i2, i3);
    }

    for (final cube in bone.cubes) {
      final inf = cube.inflate;
      final w = cube.size[0];
      final h = cube.size[1];
      final d = cube.size[2];

      // Prevent coplanar z-fighting on 2D planes
      const double planeEpsilon = 0.02;
      final double epsX = (w == 0 && inf == 0.0) ? planeEpsilon : 0.0;
      final double epsY = (h == 0 && inf == 0.0) ? planeEpsilon : 0.0;
      final double epsZ = (d == 0 && inf == 0.0) ? planeEpsilon : 0.0;

      // Local coordinates in camera space
      final fromX = (cube.origin[0] - px) - inf - epsX;
      final toX = (cube.origin[0] + w - px) + inf + epsX;
      final fromY = (cube.origin[1] - py) - inf - epsY;
      final toY = (cube.origin[1] + h - py) + inf + epsY;
      final fromZ = -(cube.origin[2] + d - pz) - inf - epsZ;
      final toZ = -(cube.origin[2] - pz) + inf + epsZ;

      // Cube pivot and rotation
      vm.Quaternion? cubeRot;
      vm.Vector3? cubePivotCam;
      if (cube.rotation != null && cube.pivot != null) {
        cubeRot = _eulerToQuaternion(cube.rotation!);
        cubePivotCam = vm.Vector3(
          cube.pivot![0] - px,
          cube.pivot![1] - py,
          -(cube.pivot![2] - pz),
        );
      }

      vm.Vector3 transformPt(vm.Vector3 pt) {
        if (cubeRot != null && cubePivotCam != null) {
          return cubePivotCam + cubeRot.rotate(pt - cubePivotCam);
        }
        return pt;
      }

      vm.Vector3 transformNormal(vm.Vector3 n) {
        if (cubeRot != null) {
          return cubeRot.rotate(n);
        }
        return n;
      }

      // Cube corners
      final p000 = transformPt(vm.Vector3(fromX, fromY, fromZ));
      final p100 = transformPt(vm.Vector3(toX, fromY, fromZ));
      final p110 = transformPt(vm.Vector3(toX, toY, fromZ));
      final p010 = transformPt(vm.Vector3(fromX, toY, fromZ));
      final p001 = transformPt(vm.Vector3(fromX, fromY, toZ));
      final p101 = transformPt(vm.Vector3(toX, fromY, toZ));
      final p111 = transformPt(vm.Vector3(toX, toY, toZ));
      final p011 = transformPt(vm.Vector3(fromX, toY, toZ));

      if (cube.isPerFaceUv) {
        final faces = cube.perFaceUv!;

        // North (+Z)
        if (faces.containsKey('north')) {
          final f = faces['north']!;
          final u0 = f.uv[0];
          final v0 = f.uv[1];
          final u1 = u0 + f.uvSize[0];
          final v1 = v0 + f.uvSize[1];
          addQuad(
            normal: transformNormal(vm.Vector3(0, 0, 1)),
            v0: p001,
            v1: p101,
            v2: p111,
            v3: p011,
            uv0: uvNorm(u0, v1),
            uv1: uvNorm(u1, v1),
            uv2: uvNorm(u1, v0),
            uv3: uvNorm(u0, v0),
          );
        }

        // South (-Z)
        if (faces.containsKey('south')) {
          final f = faces['south']!;
          final u0 = f.uv[0];
          final v0 = f.uv[1];
          final u1 = u0 + f.uvSize[0];
          final v1 = v0 + f.uvSize[1];
          addQuad(
            normal: transformNormal(vm.Vector3(0, 0, -1)),
            v0: p100,
            v1: p000,
            v2: p010,
            v3: p110,
            uv0: uvNorm(u0, v1),
            uv1: uvNorm(u1, v1),
            uv2: uvNorm(u1, v0),
            uv3: uvNorm(u0, v0),
          );
        }

        // East (-X)
        if (faces.containsKey('east')) {
          final f = faces['east']!;
          final u0 = f.uv[0];
          double v0 = f.uv[1];

          // Deltoid UV fix
          if (bone.name.toLowerCase().contains('arm') &&
              (u0 - 18.0).abs() < 0.01 &&
              (v0 - 6.0).abs() < 0.01 &&
              (f.uvSize[0].abs() - 6.0).abs() < 0.01 &&
              (f.uvSize[1].abs() - 6.0).abs() < 0.01) {
            v0 = 0.0;
          }

          final u1 = u0 + f.uvSize[0];
          final v1 = v0 + f.uvSize[1];
          addQuad(
            normal: transformNormal(vm.Vector3(-1, 0, 0)),
            v0: p000,
            v1: p001,
            v2: p011,
            v3: p010,
            uv0: uvNorm(u0, v1),
            uv1: uvNorm(u1, v1),
            uv2: uvNorm(u1, v0),
            uv3: uvNorm(u0, v0),
          );
        }

        // West (+X)
        if (faces.containsKey('west')) {
          final f = faces['west']!;
          final u0 = f.uv[0];
          double v0 = f.uv[1];

          // Deltoid UV fix
          if (bone.name.toLowerCase().contains('arm') &&
              (u0 - 18.0).abs() < 0.01 &&
              (v0 - 6.0).abs() < 0.01 &&
              (f.uvSize[0].abs() - 6.0).abs() < 0.01 &&
              (f.uvSize[1].abs() - 6.0).abs() < 0.01) {
            v0 = 0.0;
          }

          final u1 = u0 + f.uvSize[0];
          final v1 = v0 + f.uvSize[1];
          addQuad(
            normal: transformNormal(vm.Vector3(1, 0, 0)),
            v0: p101,
            v1: p100,
            v2: p110,
            v3: p111,
            uv0: uvNorm(u0, v1),
            uv1: uvNorm(u1, v1),
            uv2: uvNorm(u1, v0),
            uv3: uvNorm(u0, v0),
          );
        }

        // Up (+Y)
        if (faces.containsKey('up')) {
          final f = faces['up']!;
          final u0 = f.uv[0];
          final v0 = f.uv[1];
          final u1 = u0 + f.uvSize[0];
          final v1 = v0 + f.uvSize[1];
          addQuad(
            normal: transformNormal(vm.Vector3(0, 1, 0)),
            v0: p011,
            v1: p111,
            v2: p110,
            v3: p010,
            uv0: uvNorm(u0, v1),
            uv1: uvNorm(u1, v1),
            uv2: uvNorm(u1, v0),
            uv3: uvNorm(u0, v0),
          );
        }

        // Down (-Y)
        if (faces.containsKey('down')) {
          final f = faces['down']!;
          final u0 = f.uv[0];
          final v0 = f.uv[1];
          final u1 = u0 + f.uvSize[0];
          final v1 = v0 + f.uvSize[1];
          addQuad(
            normal: transformNormal(vm.Vector3(0, -1, 0)),
            v0: p000,
            v1: p100,
            v2: p101,
            v3: p001,
            uv0: uvNorm(u0, v1),
            uv1: uvNorm(u1, v1),
            uv2: uvNorm(u1, v0),
            uv3: uvNorm(u0, v0),
          );
        }
      } else if (cube.boxUv != null) {
        // Box UV
        final u = cube.boxUv![0];
        final v = cube.boxUv![1];
        final mirror = cube.mirror;

        final uvW = w.floorToDouble();
        final uvH = h.floorToDouble();
        final uvD = d.floorToDouble();

        final double westU0 = mirror ? u + 2 * uvD + uvW : u;
        final double westU1 = mirror ? u + uvD + uvW : u + uvD;

        final double northU0 = mirror ? u + uvD + uvW : u + uvD;
        final double northU1 = mirror ? u + uvD : u + uvD + uvW;

        final double eastU0 = mirror ? u + uvD : u + uvD + uvW;
        final double eastU1 = mirror ? u : u + 2 * uvD + uvW;

        final double southU0 = mirror
            ? u + 2 * uvD + 2 * uvW
            : u + 2 * uvD + uvW;
        final double southU1 = mirror
            ? u + 2 * uvD + uvW
            : u + 2 * uvD + 2 * uvW;

        final double upU0 = mirror ? u + uvD + uvW : u + uvD;
        final double upU1 = mirror ? u + uvD : u + uvD + uvW;

        final double downU0 = mirror ? u + uvD + 2 * uvW : u + uvD + uvW;
        final double downU1 = mirror ? u + uvD + uvW : u + uvD + 2 * uvW;

        // North
        if (w > 0 && h > 0 || inf > 0 || (d == 0 && w > 0 && h > 0)) {
          addQuad(
            normal: transformNormal(vm.Vector3(0, 0, 1)),
            v0: p001,
            v1: p101,
            v2: p111,
            v3: p011,
            uv0: uvNorm(northU0, v + uvD + uvH),
            uv1: uvNorm(northU1, v + uvD + uvH),
            uv2: uvNorm(northU1, v + uvD),
            uv3: uvNorm(northU0, v + uvD),
          );
        }

        // South
        if (w > 0 && h > 0 || inf > 0 || (d == 0 && w > 0 && h > 0)) {
          addQuad(
            normal: transformNormal(vm.Vector3(0, 0, -1)),
            v0: p100,
            v1: p000,
            v2: p010,
            v3: p110,
            uv0: uvNorm(southU0, v + uvD + uvH),
            uv1: uvNorm(southU1, v + uvD + uvH),
            uv2: uvNorm(southU1, v + uvD),
            uv3: uvNorm(southU0, v + uvD),
          );
        }

        // West
        if (d > 0 && h > 0 || inf > 0 || (w == 0 && d > 0 && h > 0)) {
          addQuad(
            normal: transformNormal(vm.Vector3(-1, 0, 0)),
            v0: p000,
            v1: p001,
            v2: p011,
            v3: p010,
            uv0: uvNorm(westU0, v + uvD + uvH),
            uv1: uvNorm(westU1, v + uvD + uvH),
            uv2: uvNorm(westU1, v + uvD),
            uv3: uvNorm(westU0, v + uvD),
          );
        }

        // East
        if (d > 0 && h > 0 || inf > 0 || (w == 0 && d > 0 && h > 0)) {
          addQuad(
            normal: transformNormal(vm.Vector3(1, 0, 0)),
            v0: p101,
            v1: p100,
            v2: p110,
            v3: p111,
            uv0: uvNorm(eastU0, v + uvD + uvH),
            uv1: uvNorm(eastU1, v + uvD + uvH),
            uv2: uvNorm(eastU1, v + uvD),
            uv3: uvNorm(eastU0, v + uvD),
          );
        }

        // Up
        if (w > 0 && d > 0 || inf > 0 || (h == 0 && w > 0 && d > 0)) {
          addQuad(
            normal: transformNormal(vm.Vector3(0, 1, 0)),
            v0: p011,
            v1: p111,
            v2: p110,
            v3: p010,
            uv0: uvNorm(upU0, v + uvD),
            uv1: uvNorm(upU1, v + uvD),
            uv2: uvNorm(upU1, v),
            uv3: uvNorm(upU0, v),
          );
        }

        // Down
        if (w > 0 && d > 0 || inf > 0 || (h == 0 && w > 0 && d > 0)) {
          addQuad(
            normal: transformNormal(vm.Vector3(0, -1, 0)),
            v0: p000,
            v1: p100,
            v2: p101,
            v3: p001,
            uv0: uvNorm(downU0, v),
            uv1: uvNorm(downU1, v),
            uv2: uvNorm(downU1, v + uvD),
            uv3: uvNorm(downU0, v + uvD),
          );
        }
      }
    }

    // Poly mesh handling
    if (bone.polyMesh != null) {
      final pm = bone.polyMesh!;
      final positions = pm.positions;
      final normals = pm.normals;
      final uvs = pm.uvs;
      final isNormalized = pm.normalizedUvs;
      final boneInflate = bone.inflate;

      vm.Vector2 getUv(int? uvIndex, int frameIndex) {
        if (uvIndex == null || uvIndex < 0 || uvIndex >= uvs.length) {
          return vm.Vector2.zero();
        }
        final uv = uvs[uvIndex];
        if (uv.isEmpty) return vm.Vector2.zero();
        final u = uv[0];
        final v = uv.length > 1 ? uv[1] : 0.0;
        if (isNormalized) {
          // Bedrock poly_mesh UVs have V=0 at the bottom of the texture
          // Invert V to match Flutter Scenes top-left UV coordinates
          final rawV = frames > 1 ? (v * frames).clamp(0.0, 1.0) : v;
          final normV = (1.0 - rawV).clamp(0.0, 1.0);
          return vm.Vector2(u.clamp(0.0, 1.0), (normV + frameIndex) / frames);
        } else {
          // Unnormalized pixel coordinates measured from bottom.
          final vInverted = frameH - v;
          return uvNorm(u, vInverted, frameIndex);
        }
      }

      for (final poly in pm.polys) {
        if (poly.length < 3) continue;

        // Deduplicate vertices within the polygon face
        final uniquePos = <int>{};
        final uniquePoly = <PersonaPolyVertex>[];
        for (final vert in poly) {
          if (uniquePos.add(vert.posIndex)) {
            uniquePoly.add(vert);
          }
        }
        if (uniquePoly.length < 3) continue;

        // Collect transformed vertices
        final vPoints = <vm.Vector3>[];
        final vNorms = <vm.Vector3>[];
        final vUvs = <vm.Vector2>[];

        for (int vi = 0; vi < uniquePoly.length; vi++) {
          final vert = uniquePoly[vi];
          if (vert.posIndex < 0 || vert.posIndex >= positions.length) continue;
          final pos = positions[vert.posIndex];
          if (pos.length < 3) continue;

          // Camera space coordinates:
          // X = x - px, Y = y - py, Z = -(z - pz)
          final pt = vm.Vector3(pos[0] - px, pos[1] - py, -(pos[2] - pz));
          vPoints.add(pt);

          // Normal in camera space: nx, ny, -nz
          vm.Vector3 n;
          if (vert.normIndex != null &&
              vert.normIndex! >= 0 &&
              vert.normIndex! < normals.length &&
              normals[vert.normIndex!].length >= 3) {
            final norm = normals[vert.normIndex!];
            n = vm.Vector3(norm[0], norm[1], -norm[2]);
            if (n.length2 > 1e-6) {
              n.normalize();
            } else {
              n = vm.Vector3.zero();
            }
          } else {
            n = vm.Vector3.zero();
          }
          vNorms.add(n);

          vUvs.add(getUv(vert.uvIndex, 0));
        }

        if (vPoints.length < 3) continue;

        // If normals were zero, compute face normal using first 3 vertices
        final vm.Vector3 fallbackNormal;
        final edge1 = vPoints[1] - vPoints[0];
        final edge2 = vPoints[2] - vPoints[0];
        final computedNormal = edge1.cross(edge2);
        if (computedNormal.length2 > 1e-6) {
          fallbackNormal = computedNormal.normalized();
        } else {
          fallbackNormal = vm.Vector3(0, 1, 0);
        }

        // Add vertices to builder
        final vertIndices = <int>[];
        for (int vi = 0; vi < vPoints.length; vi++) {
          final n = vNorms[vi].length2 > 1e-6 ? vNorms[vi] : fallbackNormal;
          final p = boneInflate != 0.0
              ? (vPoints[vi] + n * boneInflate)
              : vPoints[vi];
          builder.normal(n);
          builder.texCoord(vUvs[vi]);
          final idx = builder.addVertex(p);
          vertIndices.add(idx);
        }

        // Triangulate face using CCW triangle fan
        for (int k = 1; k < vertIndices.length - 1; k++) {
          builder.addTriangle(
            vertIndices[0],
            vertIndices[k],
            vertIndices[k + 1],
          );
        }
      }
    }

    if (builder.vertexCount == 0) return null;

    final meshGeo = builder.build();
    final material = createUnlitSkinMaterial(
      texture: texture,
      depthLayer: depthLayer,
      doubleSided: true,
    );
    _attachmentMaterials.add(material);

    return Mesh(meshGeo, material);
  }

  static (Node, List<double>) _resolveTargetNodeAndPivot(
    Node baseNode,
    PersonaBone bone,
  ) {
    // Match by bone name
    final nodeByName = _findNodeByName(baseNode, bone.name);
    if (nodeByName != null) {
      final pivot =
          standardHumanoidPivots[bone.name] ?? standardHumanoidPivots['body']!;
      return (nodeByName, pivot);
    }

    // Match by parent name
    final parent = bone.parent;
    if (parent != null) {
      if (parent == 'hip') {
        final waist = _findNodeByName(baseNode, 'waist');
        return (
          waist ?? _findNodeByName(baseNode, 'body') ?? baseNode,
          standardHumanoidPivots['waist']!,
        );
      }
      final nodeByParent = _findNodeByName(baseNode, parent);
      if (nodeByParent != null) {
        final pivot =
            standardHumanoidPivots[parent] ?? standardHumanoidPivots['body']!;
        return (nodeByParent, pivot);
      }
    }

    // Fallback to body
    final body = _findNodeByName(baseNode, 'body');
    return (body ?? baseNode, standardHumanoidPivots['body']!);
  }

  /// Outer clothing layer UV bounds
  static const List<Rect> hatLayerRects = [Rect.fromLTRB(0.0, 0.5, 1.0, 1.0)];

  static const List<Rect> rightPantsLayerRects = [
    Rect.fromLTRB(0.0, 0.25, 0.125, 0.375),
    Rect.fromLTRB(0.0, 0.5, 0.25, 0.75),
  ];

  static const List<Rect> leftPantsLayerRects = [
    Rect.fromLTRB(0.375, 0.25, 0.5, 0.375),
    Rect.fromLTRB(0.0, 0.75, 0.25, 1.0),
  ];

  static const List<Rect> jacketLayerRects = [
    Rect.fromLTRB(0.125, 0.125, 0.3125, 0.25),
    Rect.fromLTRB(0.25, 0.5, 0.5, 0.75),
  ];

  static const List<Rect> rightSleeveLayerRects = [
    Rect.fromLTRB(0.0, 0.125, 0.125, 0.25),
    Rect.fromLTRB(0.625, 0.5, 0.75, 0.75),
  ];

  static const List<Rect> leftSleeveLayerRects = [
    Rect.fromLTRB(0.3125, 0.125, 0.4375, 0.25),
    Rect.fromLTRB(0.75, 0.75, 0.875, 1.0),
  ];

  /// Checks whether an overlay image file contains pixels in the specified UV rectangles
  static Future<bool> hasLayerPixelsInImage(
    String imagePath,
    List<Rect> normalizedRects, {
    int frames = 1,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (byteData == null) return false;

        final frameH = frames > 1 ? (image.height ~/ frames) : image.height;
        final totalFrames = frames > 1 ? frames : 1;
        final width = image.width;

        for (int f = 0; f < totalFrames; f++) {
          final frameOffsetY = f * frameH;
          for (final rect in normalizedRects) {
            // Skip 64x32 head
            if (rect.top >= 0.5 && frameH <= 16) continue;

            final startX = (rect.left * width).floor().clamp(0, width);
            final endX = (rect.right * width).ceil().clamp(0, width);
            final startY = (frameOffsetY + rect.top * frameH).floor().clamp(
              0,
              image.height,
            );
            final endY = (frameOffsetY + rect.bottom * frameH).ceil().clamp(
              0,
              image.height,
            );

            for (int y = startY; y < endY; y++) {
              final rowOffset = y * width * 4;
              for (int x = startX; x < endX; x++) {
                final alpha = byteData.getUint8(rowOffset + x * 4 + 3);
                if (alpha > 0) {
                  return true;
                }
              }
            }
          }
        }
        return false;
      } finally {
        image.dispose();
      }
    } catch (e) {
      debugPrint('Error checking layer pixels in $imagePath: $e');
      return false;
    }
  }

  /// Checks whether an overlay image file contains hat layer pixels
  static Future<bool> hasHatLayerPixelsInImage(
    String imagePath, {
    int frames = 1,
  }) async {
    return hasLayerPixelsInImage(imagePath, hatLayerRects, frames: frames);
  }

  static Future<void> _ensureGlbTexturesLoaded() async {
    if (_cachedBaseBodyBytes != null && _cachedBaseHeadBytes != null) return;
    try {
      final textures = await PersonaGlbService.instance
          .getBasePersonaPngBytes();
      _cachedBaseBodyBytes = textures.body;
      _cachedBaseHeadBytes = textures.head;
    } catch (e) {
      debugPrint('Error extracting base textures from persona GLB: $e');
    }
  }

  static Future<List<Texture2D>> _compositeFrames(
    Uint8List baseBytes,
    String overlayPath, {
    required int frames,
    Rect? clipRect,
  }) async {
    final baseCodec = await ui.instantiateImageCodec(baseBytes);
    final baseFrame = await baseCodec.getNextFrame();
    final baseImage = baseFrame.image;

    final overlayBytes = await File(overlayPath).readAsBytes();
    final overlayCodec = await ui.instantiateImageCodec(overlayBytes);
    final overlayFrame = await overlayCodec.getNextFrame();
    final overlayImage = overlayFrame.image;

    final targetW = baseImage.width;
    final targetH = baseImage.height;
    final frameH = overlayImage.height ~/ frames;

    const sampling = nearestTextureSampling;

    final List<Texture2D> result = [];
    try {
      for (int f = 0; f < frames; f++) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        canvas.drawImage(baseImage, ui.Offset.zero, Paint());

        final srcY = (f * frameH).toDouble();
        canvas.save();
        if (clipRect != null) {
          final scaleX = targetW / 128.0;
          final scaleY = targetH / 128.0;
          final scaledClip = Rect.fromLTWH(
            clipRect.left * scaleX,
            clipRect.top * scaleY,
            clipRect.width * scaleX,
            clipRect.height * scaleY,
          );
          canvas.clipRect(scaledClip);
        }

        canvas.drawImageRect(
          overlayImage,
          Rect.fromLTWH(
            0,
            srcY,
            overlayImage.width.toDouble(),
            frameH.toDouble(),
          ),
          Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
          Paint(),
        );
        canvas.restore();

        final picture = recorder.endRecording();
        final compositeImage = await picture.toImage(targetW, targetH);
        try {
          final tex = await Texture2D.fromImage(
            compositeImage,
            sampling: sampling,
          );
          result.add(tex);
        } finally {
          compositeImage.dispose();
        }
      }
    } finally {
      baseImage.dispose();
      overlayImage.dispose();
    }
    return result;
  }

  static Future<Texture2D> _compositeTexture(
    Uint8List baseBytes,
    String overlayPath, {
    int frames = 1,
    int frameIndex = 0,
    Rect? clipRect,
  }) async {
    final baseCodec = await ui.instantiateImageCodec(baseBytes);
    final baseFrame = await baseCodec.getNextFrame();
    final baseImage = baseFrame.image;

    final overlayBytes = await File(overlayPath).readAsBytes();
    final overlayCodec = await ui.instantiateImageCodec(overlayBytes);
    final overlayFrame = await overlayCodec.getNextFrame();
    final overlayImage = overlayFrame.image;

    final targetW = baseImage.width;
    final targetH = baseImage.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawImage(baseImage, ui.Offset.zero, Paint());

    final frameH = frames > 1
        ? (overlayImage.height ~/ frames)
        : overlayImage.height;
    final srcY = (frameIndex * frameH).toDouble();

    canvas.save();
    if (clipRect != null) {
      // Scale clipRect if base image dimensions differ from 128x128
      final scaleX = targetW / 128.0;
      final scaleY = targetH / 128.0;
      final scaledClip = Rect.fromLTWH(
        clipRect.left * scaleX,
        clipRect.top * scaleY,
        clipRect.width * scaleX,
        clipRect.height * scaleY,
      );
      canvas.clipRect(scaledClip);
    }

    canvas.drawImageRect(
      overlayImage,
      Rect.fromLTWH(0, srcY, overlayImage.width.toDouble(), frameH.toDouble()),
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
      Paint(),
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final compositeImage = await picture.toImage(targetW, targetH);

    baseImage.dispose();
    overlayImage.dispose();

    const sampling = nearestTextureSampling;

    try {
      return await Texture2D.fromImage(compositeImage, sampling: sampling);
    } finally {
      compositeImage.dispose();
    }
  }

  void _applyTextureToNode(Node? node, TextureSource texture) {
    if (node?.mesh == null) return;
    for (final prim in node!.mesh!.primitives) {
      setMaterialTexture(prim.material, texture);
    }
  }

  static void _setupBaseMaterials(Node node) {
    applyUnlitMaterials(node, doubleSided: false, depthLayer: 0);
  }

  static Node? _findNodeByName(Node node, String name) {
    if (node.name == name) return node;
    for (final child in node.children) {
      final found = _findNodeByName(child, name);
      if (found != null) return found;
    }
    return null;
  }

  /// Converts Bedrock Euler rotations into camera space [vm.Quaternion]
  static vm.Quaternion _eulerToQuaternion(List<double> rotDeg) {
    const degToRad = math.pi / 180.0;
    final qx = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      -rotDeg[0] * degToRad,
    );
    final qy = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      rotDeg[1] * degToRad,
    );
    final qz = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      rotDeg[2] * degToRad,
    );
    return qx * qy * qz;
  }

  @override
  void setTexture(TextureSource texture) {
    for (final mat in _attachmentMaterials) {
      setMaterialTexture(mat, texture);
    }
  }

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

    if (_backEquipment == BackEquipment.cape) {
      final node = buildCapeNode(_capeTexture!);
      capeNode = node;
      (bodyNode ?? rootNode).add(node);
    } else if (_backEquipment == BackEquipment.elytra) {
      final elytraRoot = buildElytraNode(_capeTexture!);
      elytraRoot.position = defaultCapeBodyOffset;
      capeNode = elytraRoot;
      (bodyNode ?? rootNode).add(elytraRoot);
    }
  }

  @override
  void removeCape() {
    if (capeNode != null) {
      capeNode!.parent?.remove(capeNode!);
      capeNode = null;
    }
    _capeTexture = null;
    _backEquipment = null;
  }

  @override
  void resetPose() {
    headNode?.rotation = vm.Quaternion.identity();
    bodyNode?.rotation = vm.Quaternion.identity();
    rightArmNode?.rotation = vm.Quaternion.identity();
    leftArmNode?.rotation = vm.Quaternion.identity();
    rightLegNode?.rotation = vm.Quaternion.identity();
    leftLegNode?.rotation = vm.Quaternion.identity();
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
    if (_headAnimatedFrames.isNotEmpty) {
      final idleTex = toNearestGpuTexture(_headAnimatedFrames.first);
      if (_headMaterial != null) setMaterialTexture(_headMaterial!, idleTex);
      if (_hatMaterial != null) setMaterialTexture(_hatMaterial!, idleTex);
    }
    if (_bodyAnimatedFrames.isNotEmpty && _bodyMaterial != null) {
      final idleTex = toNearestGpuTexture(_bodyAnimatedFrames.first);
      setMaterialTexture(_bodyMaterial!, idleTex);
    }
    if (_animatedFrames.isNotEmpty && _animatedMaterials.isNotEmpty) {
      final idleTex = toNearestGpuTexture(_animatedFrames.first);
      for (final mat in _animatedMaterials) {
        setMaterialTexture(mat, idleTex);
      }
    }
  }

  @override
  void applyWalkAnimation(double t, {double speed = 4.0}) {
    final angle = math.sin(t * speed);
    const maxArmAngle = 0.6;
    const maxLegAngle = 0.5;

    // Swing limbs
    rightArmNode?.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      -angle * maxArmAngle,
    );
    leftArmNode?.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      angle * maxArmAngle,
    );
    rightLegNode?.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      angle * maxLegAngle,
    );
    leftLegNode?.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      -angle * maxLegAngle,
    );

    headNode?.rotation = vm.Quaternion.axisAngle(
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

    // Flipbook framerate
    const flipbookFps = 8.0;

    if (_animatedFrames.isNotEmpty && _animatedMaterials.isNotEmpty) {
      final frameIndex = ((t * flipbookFps).toInt()) % _animatedFrames.length;
      final currentTex = toNearestGpuTexture(_animatedFrames[frameIndex]);
      for (final mat in _animatedMaterials) {
        setMaterialTexture(mat, currentTex);
      }
    }

    if (_bodyAnimatedFrames.isNotEmpty && _bodyMaterial != null) {
      final frameIndex =
          ((t * flipbookFps).toInt()) % _bodyAnimatedFrames.length;
      final currentTex = toNearestGpuTexture(_bodyAnimatedFrames[frameIndex]);
      setMaterialTexture(_bodyMaterial!, currentTex);
    }

    if (_headAnimatedFrames.isNotEmpty) {
      final frameIndex =
          ((t * flipbookFps).toInt()) % _headAnimatedFrames.length;
      final currentTex = toNearestGpuTexture(_headAnimatedFrames[frameIndex]);
      if (_headMaterial != null) {
        setMaterialTexture(_headMaterial!, currentTex);
      }
      if (_hatMaterial != null) {
        setMaterialTexture(_hatMaterial!, currentTex);
      }
    }
  }
}
