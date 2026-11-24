import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:vector_math/vector_math.dart' as vm;

import '../../3d_skins/skin_3d_model.dart';
import '../../services/persona_glb_service.dart';
import '../services/cape_render_export_service.dart';

class CapeRenderExportPage extends StatefulWidget {
  const CapeRenderExportPage({super.key});

  /// Validates whether [bytes] is a valid standard or HD Minecraft cape texture
  static Future<CapeValidationResult> validateCapeImage(Uint8List bytes) =>
      CapeRenderExportService.instance.validateCapeImage(bytes);

  @override
  State<CapeRenderExportPage> createState() => _CapeRenderExportPageState();
}

class _CapeRenderExportPageState extends State<CapeRenderExportPage> {
  final GlobalKey _repaintKey = GlobalKey();
  Scene? _scene;

  Node? _rootPivotNode;
  Node? _cameraNode;
  OrbitCameraController? _orbitController;
  Node? _bodyNode;
  Node? _capeNode;
  Node? _directionalLightNode;
  Node? _baseMannequinNode;

  bool _isLoading = true;
  String? _errorMessage;
  bool _isMannequinInScene = false;
  bool _useLighting = false;
  bool _isLightInScene = false;

  String _capeTitle = 'No Cape Selected';
  TextureSource? _activeCapeTexture;
  Uint8List? _previewCapeBytes;
  int? _capeWidth;
  int? _capeHeight;

  bool _isRendering = false;
  int _exportResolution = 1024;
  String? _lastSavedPath;

  // 3/4 back perspective
  static const double defaultCapeAzimuth = 0.638;
  static const double defaultCapePolar = 0.356;
  static const double defaultCapeDistance = 26.0;
  static final vm.Vector3 defaultCapeTarget = vm.Vector3(-0.09, 1.96, 1.55);

  @override
  void initState() {
    super.initState();
    if (!is3DPreviewSupported()) {
      _isLoading = false;
      _errorMessage = k3DUnsupportedMessage;
      return;
    }
    try {
      final s = Scene();
      configureUnlitScene(s);
      _scene = s;
    } catch (e, stack) {
      debugPrint(
        'CapeRenderExportPage: Failed to initialize Scene: $e\n$stack',
      );
      _isLoading = false;
      _errorMessage = k3DUnsupportedMessage;
      return;
    }
    _initSceneAndLoadModel();
  }

  @override
  void dispose() {
    if (_isMannequinInScene && _rootPivotNode != null) {
      _scene?.remove(_rootPivotNode!);
      _isMannequinInScene = false;
    }
    if (_isLightInScene && _directionalLightNode != null) {
      _scene?.remove(_directionalLightNode!);
      _isLightInScene = false;
    }
    releaseTransientRenderTargets();
    _scene?.dispose();
    super.dispose();
  }

  Future<void> _initSceneAndLoadModel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Scene.initializeStaticResources();
      await initUnlitMaterials();

      final baseNode = await PersonaGlbService.instance.loadPersonaNode();
      _baseMannequinNode = baseNode;
      applyNearestTextureFiltering(baseNode);

      final modelOffsetNode = Node()
        ..name = 'persona_offset'
        ..position = vm.Vector3(0, -16.0, 0)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
      modelOffsetNode.add(baseNode);

      _rootPivotNode = Node()..name = 'root_pivot';
      _rootPivotNode!.add(modelOffsetNode);

      _bodyNode = _findNodeByName(baseNode, 'body') ?? baseNode;
      _setupCamera(forceReset: true);
      _applyLightingSettings();
    } catch (e, stack) {
      debugPrint('Error loading persona.glb cape renderer: $e\n$stack');
      _errorMessage = isImpellerOrGpuException(e)
          ? k3DUnsupportedMessage
          : 'Failed to load persona model: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

  void _attachCapeMesh() {
    if (_capeNode != null) {
      _capeNode!.parent?.remove(_capeNode!);
      _capeNode = null;
    }

    if (_activeCapeTexture == null || _bodyNode == null) {
      if (_isMannequinInScene && _rootPivotNode != null) {
        _scene?.remove(_rootPivotNode!);
        _isMannequinInScene = false;
      }
      return;
    }

    final node = CapeRenderExportService.instance.createCapeNode(
      _activeCapeTexture!,
      lit: _useLighting,
    );
    _capeNode = node;
    _bodyNode!.add(node);

    if (_rootPivotNode != null && !_isMannequinInScene) {
      _scene?.add(_rootPivotNode!);
      _isMannequinInScene = true;
    }
  }

  void _clearCape() {
    setState(() {
      _capeTitle = 'No Cape Selected';
      _previewCapeBytes = null;
      _activeCapeTexture = null;
      _capeWidth = null;
      _capeHeight = null;
      _lastSavedPath = null;
    });
    _attachCapeMesh();
  }

  void _applyLightingSettings() {
    if (_scene == null) return;
    if (_useLighting) {
      _scene!.antiAliasingMode = AntiAliasingMode.none;
      _scene!.toneMapping = ToneMappingMode.linear;
      _scene!.environment = null;
      _scene!.environmentIntensity = 0.55;

      if (_directionalLightNode == null) {
        final light = DirectionalLight(
          color: vm.Vector3(1.0, 1.0, 1.0),
          intensity: 1.8,
          castsShadow: true,
        );
        _directionalLightNode = Node()
          ..name = 'studio_light'
          ..addComponent(
            DirectionalLightComponent.aimed(
              light,
              vm.Vector3(-0.35, -0.85, 0.95),
            ),
          );
      }
      if (!_isLightInScene) {
        _scene!.add(_directionalLightNode!);
        _isLightInScene = true;
      }

      if (_baseMannequinNode != null) {
        applyLitMaterials(
          _baseMannequinNode!,
          doubleSided: false,
          depthLayer: 0,
        );
      }
    } else {
      if (_isLightInScene && _directionalLightNode != null) {
        _scene!.remove(_directionalLightNode!);
        _isLightInScene = false;
      }
      configureUnlitScene(_scene!);
      if (_baseMannequinNode != null) {
        applyUnlitMaterials(
          _baseMannequinNode!,
          doubleSided: false,
          depthLayer: 0,
        );
      }
    }

    if (_activeCapeTexture != null) {
      _attachCapeMesh();
    }
  }

  void _setupCamera({
    double? azimuth,
    double? polar,
    double? distance,
    vm.Vector3? target,
    bool forceReset = false,
  }) {
    if (_scene == null) return;
    final res = setupOrbitCamera(
      scene: _scene!,
      cameraNode: _cameraNode,
      oldController: _orbitController,
      modelNode: _rootPivotNode,
      target: target ?? defaultCapeTarget,
      distance: distance ?? defaultCapeDistance,
      azimuth: azimuth ?? defaultCapeAzimuth,
      polar: polar ?? defaultCapePolar,
      forceReset: forceReset,
    );
    _cameraNode = res.cameraNode;
    _orbitController = res.controller;
    _orbitController?.update(0.016);
    if (mounted) setState(() {});
  }

  void _resetCameraToDefault() {
    _rootPivotNode?.rotation = vm.Quaternion.identity();
    _setupCamera(
      azimuth: defaultCapeAzimuth,
      polar: defaultCapePolar,
      distance: defaultCapeDistance,
      target: defaultCapeTarget,
      forceReset: true,
    );
  }

  Future<void> _pickCustomCapeFile() async {
    try {
      final loadedCape = await CapeRenderExportService.instance
          .pickAndLoadCape();
      if (loadedCape == null) return;

      setState(() {
        _capeTitle = loadedCape.title;
        _previewCapeBytes = loadedCape.bytes;
        _activeCapeTexture = loadedCape.texture;
        _capeWidth = loadedCape.width;
        _capeHeight = loadedCape.height;
      });

      _attachCapeMesh();
      _resetCameraToDefault();
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _showToast(msg, isError: true);
    }
  }

  Future<void> _renderAndSaveToDownloads() async {
    if (_isRendering || _isLoading || _activeCapeTexture == null) return;

    setState(() {
      _isRendering = true;
    });

    try {
      if (_scene == null) throw Exception(k3DUnsupportedMessage);
      final camera =
          _cameraNode?.getComponent<CameraComponent>()?.toCamera() ??
          _scene!.camera;
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      final targetPath = await CapeRenderExportService.instance
          .renderAndSaveToDownloads(
            scene: _scene!,
            camera: camera,
            resolution: _exportResolution,
            capeTitle: _capeTitle,
            fallbackBoundary: boundary,
          );

      if (mounted) {
        setState(() {
          _lastSavedPath = targetPath;
        });

        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads: ${p.basename(targetPath)}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rendering cape to downloads: $e');
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _showToast('Failed to save render: $msg', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRendering = false;
        });
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError
                ? colorScheme.onErrorContainer
                : colorScheme.onInverseSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? colorScheme.errorContainer : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasCape = _activeCapeTexture != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cape 3D Renderer'),
        actions: [
          IconButton(
            tooltip: 'Reset to Cape View',
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: hasCape ? _resetCameraToDefault : null,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 720;

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildViewport(dpr, colorScheme),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _buildControlPanel(colorScheme),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildViewport(dpr, colorScheme),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: _buildControlPanel(colorScheme),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildViewport(double dpr, ColorScheme colorScheme) {
    final hasCape = _activeCapeTexture != null;

    return Center(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CapeCheckerboardPainter(
                    color1: colorScheme.surfaceContainerHighest,
                    color2: colorScheme.surfaceContainer,
                  ),
                ),
              ),
              if (hasCape &&
                  !_isLoading &&
                  _errorMessage == null &&
                  _scene != null &&
                  _rootPivotNode != null &&
                  _orbitController != null)
                Positioned.fill(
                  child: CameraControls(
                    key: ValueKey(_orbitController),
                    controller: _orbitController!,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: SceneView(
                        _scene!,
                        pixelRatio: dpr,
                        maxFrameRate: 60,
                      ),
                    ),
                  ),
                ),
              if (!hasCape && _errorMessage == null)
                Positioned.fill(child: _buildEmptyViewport(colorScheme)),
              if (_isLoading && hasCape)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Preparing Mannequin...',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null)
                Center(
                  child: Card(
                    color: colorScheme.errorContainer,
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                ),
              if (hasCape && !_isLoading && _errorMessage == null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.85,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _resetCameraToDefault,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.crop_free_rounded,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reset Angle',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasCape && !_isLoading && _errorMessage == null)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.85,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Drag to rotate • Scroll to zoom',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyViewport(ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.65),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Image.asset('assets/cape.png', width: 40, height: 40),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Cape Selected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Supports standard 64×32 or HD 128×64 PNG textures',
              style: TextStyle(fontSize: 11, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(ColorScheme colorScheme) {
    final hasCape = _activeCapeTexture != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCapeCard(colorScheme, hasCape),
        const SizedBox(height: 14),
        _buildResolutionCard(colorScheme),
        const SizedBox(height: 14),
        _buildLightingCard(colorScheme),
        const SizedBox(height: 14),
        if (hasCape) ...[
          _buildCameraCard(colorScheme),
          const SizedBox(height: 14),
        ],
        _buildExportAction(colorScheme, hasCape),
      ],
    );
  }

  Widget _buildCapeCard(ColorScheme colorScheme, bool hasCape) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/cape.png', width: 20, height: 20),
                const SizedBox(width: 8),
                Text(
                  'Cape Texture',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (hasCape && _capeWidth != null && _capeHeight != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_capeWidth×$_capeHeight',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasCape) ...[
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 28,
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CapeCheckerboardPainter(
                              squareSize: 7.0,
                              color1: colorScheme.surfaceContainerHighest,
                              color2: colorScheme.surfaceContainer,
                            ),
                          ),
                        ),
                        if (_previewCapeBytes != null)
                          Positioned.fill(
                            child: Image.memory(
                              _previewCapeBytes!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _capeTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Change Cape'),
                      onPressed: _pickCustomCapeFile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Clear'),
                    onPressed: _clearCape,
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 20),
                  label: const Text(
                    'Select Cape Texture (.png)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _pickCustomCapeFile,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_size_select_actual_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Export Resolution',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_exportResolution×$_exportResolution px',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 256, label: Text('256×256')),
                  ButtonSegment(value: 512, label: Text('512×512')),
                  ButtonSegment(value: 1024, label: Text('1024×1024')),
                  ButtonSegment(value: 2048, label: Text('2048×2048')),
                ],
                selected: {_exportResolution},
                onSelectionChanged: (set) {
                  setState(() {
                    _exportResolution = set.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _exportResolution < 2048
                  ? 'Super-sampled at 2048px (SSAA) for smooth anti-aliased edges'
                  : 'Native 2K res with high-fidelity',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightingCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.wb_sunny_outlined, size: 20, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shadows & Lighting',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _useLighting
                        ? 'Directional shading and depth'
                        : 'Flat unlit texture mode',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _useLighting,
              onChanged: (val) {
                setState(() {
                  _useLighting = val;
                });
                _applyLightingSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.view_in_ar_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Camera Angle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Default 3/4 back cape perspective',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              icon: const Icon(Icons.crop_free_rounded, size: 16),
              label: const Text('Reset Angle', style: TextStyle(fontSize: 12)),
              onPressed: _resetCameraToDefault,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportAction(ColorScheme colorScheme, bool hasCape) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _isRendering
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 22),
          label: Text(
            _isRendering
                ? 'Rendering PNG...'
                : hasCape
                ? 'Render & Save to Downloads'
                : 'Select a Cape to Export',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: _isRendering || !hasCape
              ? null
              : _renderAndSaveToDownloads,
        ),
        if (_lastSavedPath != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Saved: ${p.basename(_lastSavedPath!)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class CapeCheckerboardPainter extends CustomPainter {
  final double squareSize;
  final Color color1;
  final Color color2;

  CapeCheckerboardPainter({
    this.squareSize = 14.0,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = color1;
    final p2 = Paint()..color = color2;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven =
            ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? p1 : p2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CapeCheckerboardPainter oldDelegate) =>
      color1 != oldDelegate.color1 || color2 != oldDelegate.color2;
}
