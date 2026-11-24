import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../3d_skins/bedrock_rotation.dart';
import '../models/bedrock_animation.dart';
import '../services/emote_service.dart';
import '../services/persona_glb_service.dart';
import '../services/settings_service.dart';
import '../3d_skins/skin_3d_model.dart';

class EmotePlayer extends StatefulWidget {
  final EmoteAnimationData animationData;
  final Size? size;
  final double initialCameraDistance;

  const EmotePlayer({
    super.key,
    required this.animationData,
    this.size,
    this.initialCameraDistance = 50.0,
  });

  @override
  State<EmotePlayer> createState() => _EmotePlayerState();
}

class _EmotePlayerState extends State<EmotePlayer> {
  Scene? _scene;
  Node? _pivotNode;

  bool _isLoading = true;
  String? _errorMessage;

  // Camera and scene
  Node? _cameraNode;
  OrbitCameraController? _orbitController;

  // Animation playback state
  double _animTime = 0.0;
  final bool _isPlaying = true;
  final double _playbackSpeed = 1.0;

  static const Map<String, String> _boneMap = {
    'root': 'root',
    'hip': 'waist',
    'body': 'body',
    'head': 'head',
    'leftArm': 'leftArm',
    'rightArm': 'rightArm',
    'leftLeg': 'leftLeg',
    'rightLeg': 'rightLeg',
  };

  final Map<String, Node> _boneNodes = {};
  final Map<String, vm.Vector3> _restPositions = {};

  @override
  void initState() {
    super.initState();
    if (!SettingsService.instance.get3DPreviewSync() ||
        !is3DPreviewSupported()) {
      _isLoading = false;
      _errorMessage = !SettingsService.instance.get3DPreviewSync()
          ? null
          : k3DUnsupportedMessage;
      return;
    }

    try {
      final s = Scene();
      configureUnlitScene(s);
      _scene = s;
    } catch (e, stack) {
      debugPrint('EmotePlayer: Failed to initialize Scene: $e\n$stack');
      _isLoading = false;
      _errorMessage = k3DUnsupportedMessage;
      return;
    }

    _initSceneAndLoadModel();
  }

  void _onSceneTick(Duration elapsed, double dt) {
    if (_isPlaying && _boneNodes.isNotEmpty) {
      final animLen = widget.animationData.animation.length;
      if (animLen > 0) {
        _animTime = (_animTime + dt * _playbackSpeed) % animLen;
        _applyEmotePose(_animTime);
      }
    }
  }

  Future<void> _initSceneAndLoadModel() async {
    try {
      await Scene.initializeStaticResources();

      final node = await loadScene('assets/persona.glb');

      // Center model geometry at origin
      final bounds = node.combinedLocalBounds;
      final yCenter = bounds != null ? bounds.center.y : -1.875;
      node.position = vm.Vector3(0, -yCenter, 0);

      _pivotNode = Node()..add(node);
      _scene?.add(_pivotNode!);

      applyNearestTextureFiltering(node);
      applyUnlitMaterials(node, doubleSided: false, depthLayer: 0);

      if (await PersonaGlbService.instance.hasCustomPersona()) {
        try {
          final textures = await PersonaGlbService.instance
              .getEmotePersonaPngBytes();
          final bodyTex = await Texture2D.fromEncodedBytes(
            textures.body,
            sampling: nearestTextureSampling,
          );
          final headTex = await Texture2D.fromEncodedBytes(
            textures.head,
            sampling: nearestTextureSampling,
          );

          for (final meshNode in node.meshNodes) {
            final mesh = meshNode.mesh;
            if (mesh == null) continue;
            final isHeadOrHat =
                meshNode.name == 'head' || meshNode.name == 'hat';
            final tex = isHeadOrHat ? headTex : bodyTex;
            for (final prim in mesh.primitives) {
              setMaterialTexture(prim.material, tex);
            }
          }
        } catch (e) {
          debugPrint('Error applying custom skin to emote_player: $e');
        }
      }

      _setupOrbitCamera();

      _cacheBones(node);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('EmotePlayer initialization error: $e\n$stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = isImpellerOrGpuException(e)
              ? k3DUnsupportedMessage
              : e.toString();
        });
      }
    }
  }

  void _cacheBones(Node root) {
    _boneNodes.clear();
    _restPositions.clear();

    for (final entry in _boneMap.entries) {
      final found = _findNodeByName(root, entry.value);
      if (found != null) {
        _boneNodes[entry.key] = found;
        _restPositions[entry.key] = found.position.clone();
      } else {
        debugPrint('Bone node not found: "${entry.value}"');
      }
    }
  }

  Node? _findNodeByName(Node node, String name) {
    if (node.name == name) return node;
    for (final child in node.children) {
      final found = _findNodeByName(child, name);
      if (found != null) return found;
    }
    return null;
  }

  void _applyEmotePose(double t) {
    final anim = widget.animationData.animation;

    for (final boneName in anim.bones.keys) {
      final node = _boneNodes[boneName];
      if (node == null) continue;

      final track = anim.bones[boneName]!;
      final rest = _restPositions[boneName] ?? vm.Vector3.zero();

      final rot = sampleChannel(track.rotation, t, isRotation: true);
      final pos = sampleChannel(track.position, t);
      final scl = sampleChannel(track.scale, t);

      node.rotation = bedrockEulerToQuaternion(rot);

      // Add animation offset to GLB bind rest position (negate Z for coordinate system)
      node.position = vm.Vector3(
        rest.x + pos[0],
        rest.y + pos[1],
        rest.z - pos[2],
      );

      if (track.scale.isNotEmpty) {
        node.scale = vm.Vector3(scl[0], scl[1], scl[2]);
      }
    }
  }

  void _setupOrbitCamera({
    double? distance,
    vm.Vector3? target,
    double? azimuth,
    double? polar,
  }) {
    if (_scene == null) return;
    final res = setupOrbitCamera(
      scene: _scene!,
      cameraNode: _cameraNode,
      oldController: _orbitController,
      modelNode: _pivotNode,
      target: target,
      distance: distance ?? widget.initialCameraDistance,
      azimuth: azimuth,
      polar: polar,
      minDistance: 8.0,
      maxDistance: 90.0,
    );
    _cameraNode = res.cameraNode;
    _orbitController = res.controller;
  }

  void _resetView() {
    setState(() {
      _setupOrbitCamera(distance: widget.initialCameraDistance);
    });
  }

  @override
  void didUpdateWidget(covariant EmotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCameraDistance != widget.initialCameraDistance) {
      _setupOrbitCamera(distance: widget.initialCameraDistance);
    }
    if (oldWidget.animationData != widget.animationData) {
      _animTime = 0.0;
      if (_boneNodes.isNotEmpty) {
        _applyEmotePose(0.0);
      }
    }
  }

  @override
  void dispose() {
    releaseTransientRenderTargets();
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!SettingsService.instance.get3DPreviewSync()) {
      return const SizedBox.shrink();
    }
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final effectiveDpr = math.min(dpr, 2.0);

    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      final isUnsupported = _errorMessage == k3DUnsupportedMessage;
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUnsupported ? Icons.view_in_ar_outlined : Icons.error_outline,
                size: 36,
                color: isUnsupported
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.redAccent,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isUnsupported
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _resetView,
        child: (_orbitController != null && _scene != null)
            ? CameraControls(
                controller: _orbitController!,
                child: TickerMode(
                  enabled: isCurrentRoute,
                  child: SceneView(
                    _scene!,
                    pixelRatio: effectiveDpr,
                    onTick: _onSceneTick,
                    maxFrameRate: 60,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
    }

    if (widget.size != null) {
      return SizedBox(
        width: widget.size!.width,
        height: widget.size!.height,
        child: content,
      );
    }

    return content;
  }
}
