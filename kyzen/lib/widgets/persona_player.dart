import 'dart:math' as math;
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../3d_skins/skin_3d_model.dart';
import '../3d_skins/skin_viewer_screen.dart';
import '../services/settings_service.dart';

/// Embedded 3D viewer widget for a single Persona cosmetic piece.
/// Designed to fit in the image carousel section with orbit & zoom controls.
class PersonaPlayer extends StatefulWidget {
  final PersonaPiece piece;
  final Size? size;
  final double initialCameraDistance;

  const PersonaPlayer({
    super.key,
    required this.piece,
    this.size,
    this.initialCameraDistance = 45.0,
  });

  @override
  State<PersonaPlayer> createState() => _PersonaPlayerState();
}

class _PersonaPlayerState extends State<PersonaPlayer> {
  Scene? _scene;
  Node? _pivotNode;
  Node? _cameraNode;
  OrbitCameraController? _orbitController;
  Skin3DModel? _activeModel;

  bool _isLoading = true;
  String? _errorMessage;

  late double _defaultDistance;
  bool _autoRotate = false;
  bool _isWalking = true;
  BackEquipment _backEquipment = BackEquipment.cape;

  double _animTime = 0.0;

  @override
  void initState() {
    super.initState();
    final initialDist = widget.size != null
        ? calculateCameraDistance(
            viewportWidth: widget.size!.width,
            viewportHeight: widget.size!.height,
          )
        : widget.initialCameraDistance;
    _defaultDistance = initialDist;

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
      debugPrint('PersonaPlayer: Failed to initialize Scene: $e\n$stack');
      _isLoading = false;
      _errorMessage = k3DUnsupportedMessage;
      return;
    }

    _initSceneAndLoadModel();
  }

  void _onSceneTick(Duration elapsed, double dt) {
    _animTime += dt;
    if (_isWalking) {
      _activeModel?.applyWalkAnimation(_animTime);
    } else {
      _activeModel?.applyWalkAnimation(_animTime, speed: 0.0);
    }
    if (_autoRotate) {
      _orbitController?.orbitBy(0.015, 0.0);
    }
  }

  Future<void> _initSceneAndLoadModel() async {
    try {
      await Scene.initializeStaticResources();
      final model = await buildPersona3DModel(piece: widget.piece);
      if (model.hasCape) {
        model.setBackEquipment(_backEquipment);
      }

      final newPivot = Node()..add(model.rootNode);
      _pivotNode = newPivot;
      _activeModel = model;
      _scene?.add(newPivot);
      _setupOrbitCamera();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('PersonaPlayer initialization error: $e\n$stack');
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
      distance: distance ?? _defaultDistance,
      azimuth: azimuth,
      polar: polar,
      isCape: widget.piece.isCape,
    );
    _cameraNode = res.cameraNode;
    _orbitController = res.controller;
  }

  @override
  void didUpdateWidget(covariant PersonaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.piece.pieceId != widget.piece.pieceId) {
      _isLoading = true;
      _errorMessage = null;
      if (_pivotNode != null && _scene != null) {
        _scene!.remove(_pivotNode!);
        _pivotNode = null;
      }
      if (!is3DPreviewSupported() || _scene == null) {
        _isLoading = false;
        _errorMessage = k3DUnsupportedMessage;
        return;
      }
      _initSceneAndLoadModel();
    }
  }

  @override
  void dispose() {
    if (_pivotNode != null && _scene != null) {
      _scene!.remove(_pivotNode!);
    }
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

    return Stack(
      children: [
        if (!_isLoading &&
            _errorMessage == null &&
            _scene != null &&
            _pivotNode != null &&
            _orbitController != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () {
                setState(() {
                  _setupOrbitCamera(distance: _defaultDistance);
                });
              },
              child: Listener(
                onPointerDown: (_) {
                  if (_autoRotate) {
                    setState(() {
                      _autoRotate = false;
                    });
                  }
                },
                child: CameraControls(
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
                ),
              ),
            ),
          ),

        if (_isLoading)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  context.l10n.loading3DPersona,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

        if (_errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _errorMessage == k3DUnsupportedMessage
                        ? Icons.view_in_ar_outlined
                        : Icons.error_outline,
                    size: 32,
                    color: _errorMessage == k3DUnsupportedMessage
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Colors.redAccent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage == k3DUnsupportedMessage
                        ? _errorMessage!
                        : context.l10n.failedToLoad3dPreview(
                            _errorMessage ?? '',
                          ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _errorMessage == k3DUnsupportedMessage
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Controls overlay (Fullscreen button + Turntable toggle)
        if (!_isLoading && _errorMessage == null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isWalking ? Icons.directions_walk : Icons.man,
                    size: 18,
                  ),
                  tooltip: _isWalking ? context.l10n.idle : context.l10n.walk,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _isWalking = !_isWalking;
                      if (!_isWalking) {
                        _activeModel?.resetPose();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.rotate_right,
                    size: 18,
                    color: _autoRotate
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: _autoRotate
                      ? context.l10n.pauseTurntable
                      : context.l10n.autoRotate,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _autoRotate = !_autoRotate;
                    });
                  },
                ),
                if (_activeModel?.hasCape == true)
                  IconButton(
                    icon: Image.asset(
                      _backEquipment == BackEquipment.elytra
                          ? 'assets/elytra.png'
                          : 'assets/cape.png',
                      width: 18,
                      height: 18,
                    ),
                    tooltip: _backEquipment == BackEquipment.cape
                        ? context.l10n.switchToElytra
                        : context.l10n.switchToCape,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        _backEquipment = _backEquipment == BackEquipment.cape
                            ? BackEquipment.elytra
                            : BackEquipment.cape;
                        _activeModel?.setBackEquipment(_backEquipment);
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.open_in_full, size: 18),
                  tooltip: context.l10n.openFull3DViewer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SkinViewerScreen(personaPieces: [widget.piece]),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
