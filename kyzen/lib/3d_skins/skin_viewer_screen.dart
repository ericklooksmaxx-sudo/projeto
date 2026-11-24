import 'dart:io';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_scene/scene.dart';
import 'package:path/path.dart' as p;
import 'package:vector_math/vector_math.dart' as vm;

import 'skin_3d_model.dart';
import 'skin_model_data.dart';
import '../l10n/context_extensions.dart';
import '../services/settings_service.dart';

/// Interactive 3D Skin viewer
class SkinViewerScreen extends StatefulWidget {
  final List<String>? folderPaths;
  final String? folderPath;
  final List<SkinPack>? skinPacks;
  final SkinPack? skinPack;
  final List<PersonaPiece>? personaPieces;
  final PersonaPiece? personaPiece;

  const SkinViewerScreen({
    super.key,
    this.folderPaths,
    this.folderPath,
    this.skinPacks,
    this.skinPack,
    this.personaPieces,
    this.personaPiece,
  });

  @override
  State<SkinViewerScreen> createState() => _SkinViewerScreenState();
}

class _SkinViewerScreenState extends State<SkinViewerScreen> {
  Scene? _scene;
  Node? _pivotNode;
  Node? _cameraNode;
  OrbitCameraController? _orbitController;

  Skin3DModel? _activeModel;

  // Skin pack data
  final List<SkinPack> _loadedPacks = [];
  int _selectedPackIndex = 0;
  List<MinecraftSkinEntry> _skins = [];
  int _selectedSkinIndex = 0;

  // Persona data
  final List<PersonaPiece> _loadedPersonaPieces = [];
  int _selectedPersonaIndex = 0;
  bool _isViewingPersona = false;

  bool _isLoading = true;
  String? _errorMessage;

  double? _optimalDistance;
  bool _autoRotate = false;

  String _pose = 'walking'; // 'standing' or 'walking'
  BackEquipment _backEquipment = BackEquipment.cape;
  double _animTime = 0.0;
  bool _highQualityMode = false;

  @override
  void initState() {
    super.initState();
    if (!SettingsService.instance.get3DPreviewSync()) {
      _isLoading = false;
      _errorMessage = '3D preview is disabled in settings.';
      return;
    }
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
      debugPrint('Initialization error in SkinViewer: $e\n$stack');
      _isLoading = false;
      _errorMessage = k3DUnsupportedMessage;
      return;
    }
    _initSceneAndLoadSkins();
  }

  @override
  void didUpdateWidget(covariant SkinViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.folderPath != oldWidget.folderPath ||
        widget.folderPaths != oldWidget.folderPaths ||
        widget.skinPack != oldWidget.skinPack ||
        widget.skinPacks != oldWidget.skinPacks ||
        widget.personaPiece != oldWidget.personaPiece ||
        widget.personaPieces != oldWidget.personaPieces) {
      _loadProvidedPacks();
    }
  }

  void _onSceneTick(Duration elapsed, double dt) {
    _animTime += dt;
    if (_pose == 'walking') {
      _activeModel?.applyWalkAnimation(_animTime);
    } else {
      _activeModel?.applyWalkAnimation(_animTime, speed: 0.0);
    }
    if (_autoRotate) {
      _orbitController?.orbitBy(0.015, 0.0);
    }
  }

  Future<void> _initSceneAndLoadSkins() async {
    try {
      await Scene.initializeStaticResources();
      await _loadProvidedPacks();
    } catch (e, stack) {
      debugPrint('Initialization error in SkinViewer: $e\n$stack');
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

  Future<void> _loadProvidedPacks() async {
    _loadedPacks.clear();
    _loadedPersonaPieces.clear();

    if (widget.personaPieces != null && widget.personaPieces!.isNotEmpty) {
      _loadedPersonaPieces.addAll(widget.personaPieces!);
    } else if (widget.personaPiece != null) {
      _loadedPersonaPieces.add(widget.personaPiece!);
    }

    if (widget.skinPacks != null && widget.skinPacks!.isNotEmpty) {
      _loadedPacks.addAll(widget.skinPacks!);
    } else if (widget.skinPack != null) {
      _loadedPacks.add(widget.skinPack!);
    } else if (widget.folderPaths != null && widget.folderPaths!.isNotEmpty) {
      for (final folder in widget.folderPaths!) {
        final skinsJson = File(p.join(folder, 'skins.json'));
        if (await skinsJson.exists()) {
          try {
            final pack = await SkinPack.loadFromDirectory(folder);
            _loadedPacks.add(pack);
          } catch (e) {
            debugPrint('Failed to load skin pack from $folder: $e');
          }
        } else {
          final pieces = await PersonaPiece.findInDirectory(folder);
          _loadedPersonaPieces.addAll(pieces);
        }
      }
    } else if (widget.folderPath != null) {
      final skinsJson = File(p.join(widget.folderPath!, 'skins.json'));
      if (await skinsJson.exists()) {
        final pack = await SkinPack.loadFromDirectory(widget.folderPath!);
        _loadedPacks.add(pack);
      } else {
        final pieces = await PersonaPiece.findInDirectory(widget.folderPath!);
        _loadedPersonaPieces.addAll(pieces);
      }
    }

    if (_loadedPacks.isEmpty && _loadedPersonaPieces.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No skins or persona items found in the provided folder(s).';
        });
      }
      return;
    }

    if (_loadedPersonaPieces.isNotEmpty && _loadedPacks.isEmpty) {
      _isViewingPersona = true;
      await _selectPersonaPiece(0);
    } else {
      _isViewingPersona = false;
      await _selectPack(0);
    }
  }

  Future<void> _selectPack(int packIndex) async {
    if (packIndex < 0 || packIndex >= _loadedPacks.length) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isViewingPersona = false;
      _selectedPackIndex = packIndex;
      _selectedSkinIndex = 0;
    });

    try {
      final pack = _loadedPacks[packIndex];
      _skins = pack.skins;
      await _rebuildModel();
    } catch (e, stack) {
      debugPrint('Failed to load skin pack: $e\n$stack');
      _errorMessage = 'Failed to load skin pack: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectPersonaPiece(int index) async {
    if (index < 0 || index >= _loadedPersonaPieces.length) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isViewingPersona = true;
      _selectedPersonaIndex = index;
    });

    try {
      await _rebuildModel();
    } catch (e, stack) {
      debugPrint('Failed to load persona piece: $e\n$stack');
      _errorMessage = 'Failed to load persona piece: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Rebuilds the active 3D character model (standard, custom Bedrock geo, or persona)
  Future<void> _rebuildModel() async {
    final oldPivotNode = _pivotNode;

    if (_isViewingPersona) {
      final currentPiece =
          _loadedPersonaPieces.isNotEmpty &&
              _selectedPersonaIndex < _loadedPersonaPieces.length
          ? _loadedPersonaPieces[_selectedPersonaIndex]
          : null;

      if (currentPiece != null) {
        try {
          final model = await buildPersona3DModel(piece: currentPiece);
          if (model.hasCape) {
            model.setBackEquipment(_backEquipment);
          }
          _activeModel = model;

          final newPivot = Node()..add(model.rootNode);
          _pivotNode = newPivot;
          _scene?.add(newPivot);
          if (oldPivotNode != null) {
            _scene?.remove(oldPivotNode);
          }
          _setupOrbitCamera();
        } catch (e, stack) {
          debugPrint('Failed to build persona model: $e\n$stack');
          _errorMessage = isImpellerOrGpuException(e)
              ? k3DUnsupportedMessage
              : 'Failed to load persona geometry: $e';
        }
      }
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final currentSkin = _skins.isNotEmpty && _selectedSkinIndex < _skins.length
        ? _skins[_selectedSkinIndex]
        : null;

    if (currentSkin != null) {
      try {
        final (:model, geometry: _) = await buildSkin3DModel(skin: currentSkin);
        if (model.hasCape) {
          model.setBackEquipment(_backEquipment);
        }
        _activeModel = model;

        final newPivot = Node()..add(model.rootNode);
        _pivotNode = newPivot;
        _scene?.add(newPivot);
        if (oldPivotNode != null) {
          _scene?.remove(oldPivotNode);
        }
        _setupOrbitCamera();
      } catch (e, stack) {
        debugPrint('Failed to build custom model: $e\n$stack');
        _errorMessage = isImpellerOrGpuException(e)
            ? k3DUnsupportedMessage
            : 'Failed to load geometry: $e';
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyTexture(String texturePath) async {
    try {
      final texture = await loadSkinTexture(texturePath);
      _activeModel?.setTexture(texture);
    } catch (e) {
      debugPrint('Failed to load texture $texturePath: $e');
    }
  }

  void _setupOrbitCamera({
    vm.Vector3? target,
    double? distance,
    double? azimuth,
    double? polar,
    bool forceReset = false,
  }) {
    final isCape = _isViewingPersona
        ? (_loadedPersonaPieces.isNotEmpty &&
              _selectedPersonaIndex < _loadedPersonaPieces.length &&
              _loadedPersonaPieces[_selectedPersonaIndex].isCape)
        : (_skins.isNotEmpty &&
              _selectedSkinIndex < _skins.length &&
              _skins[_selectedSkinIndex].hasCape);

    if (_scene == null) return;
    final res = setupOrbitCamera(
      scene: _scene!,
      cameraNode: _cameraNode,
      oldController: _orbitController,
      modelNode: _pivotNode,
      target: target,
      distance:
          distance ??
          (_orbitController == null
              ? (_optimalDistance ?? defaultCameraDistance)
              : null),
      azimuth: azimuth,
      polar: polar,
      isCape: isCape,
      forceReset: forceReset,
    );
    _cameraNode = res.cameraNode;
    _orbitController = res.controller;
  }

  void _resetCamera() {
    final isCape = _isViewingPersona
        ? (_loadedPersonaPieces.isNotEmpty &&
              _selectedPersonaIndex < _loadedPersonaPieces.length &&
              _loadedPersonaPieces[_selectedPersonaIndex].isCape)
        : (_skins.isNotEmpty &&
              _selectedSkinIndex < _skins.length &&
              _skins[_selectedSkinIndex].hasCape);

    setState(() {
      _setupOrbitCamera(
        distance: _optimalDistance ?? defaultCameraDistance,
        azimuth: isCape ? defaultCapeOrbitAzimuth : defaultOrbitAzimuth,
        polar: isCape ? defaultCapeOrbitPolar : defaultOrbitPolar,
        forceReset: true,
      );
    });
  }

  @override
  void dispose() {
    releaseTransientRenderTargets();
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSkin =
        !_isViewingPersona &&
            _skins.isNotEmpty &&
            _selectedSkinIndex < _skins.length
        ? _skins[_selectedSkinIndex]
        : null;

    final currentPersonaPiece =
        _isViewingPersona &&
            _loadedPersonaPieces.isNotEmpty &&
            _selectedPersonaIndex < _loadedPersonaPieces.length
        ? _loadedPersonaPieces[_selectedPersonaIndex]
        : null;

    final currentPackTitle = !_isViewingPersona && _loadedPacks.isNotEmpty
        ? (_loadedPacks[_selectedPackIndex].localizationName.isNotEmpty
              ? _loadedPacks[_selectedPackIndex].localizationName
              : _loadedPacks[_selectedPackIndex].serializeName)
        : (_isViewingPersona ? context.l10n.persona : '');

    final screenSize = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final effectiveDpr = Platform.isAndroid
        ? (_highQualityMode ? dpr : math.min(dpr, 2.0))
        : dpr;
    final bodyHeight =
        screenSize.height - kToolbarHeight - MediaQuery.paddingOf(context).top;

    if (_optimalDistance == null && screenSize.width > 0 && bodyHeight > 0) {
      _optimalDistance = calculateCameraDistance(
        viewportWidth: screenSize.width,
        viewportHeight: bodyHeight,
        verticalFill: 0.90,
      );
    }

    if (_orbitController == null &&
        _optimalDistance != null &&
        _pivotNode != null) {
      _setupOrbitCamera(distance: _optimalDistance);
    }

    final hasMultipleCategories =
        _loadedPacks.isNotEmpty && _loadedPersonaPieces.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              context.l10n.viewer3d,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (currentPackTitle.isNotEmpty ||
                currentSkin != null ||
                currentPersonaPiece != null)
              Text(
                _isViewingPersona && currentPersonaPiece != null
                    ? '${context.l10n.persona} • ${currentPersonaPiece.displayName}'
                    : (currentPackTitle.isNotEmpty && currentSkin != null
                          ? '$currentPackTitle • ${currentSkin.localizationName}'
                          : (currentPackTitle.isNotEmpty
                                ? currentPackTitle
                                : currentSkin?.localizationName ?? '')),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_errorMessage == null) ...[
            if (Platform.isAndroid)
              IconButton(
                tooltip: _highQualityMode
                    ? context.l10n.highQualityNativeDpr
                    : context.l10n.balancedModeOptimized,
                icon: Icon(
                  _highQualityMode ? Icons.hd_rounded : Icons.hd_outlined,
                  color: _highQualityMode ? Colors.amberAccent : null,
                ),
                onPressed: () {
                  setState(() {
                    _highQualityMode = !_highQualityMode;
                  });
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.removeCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        _highQualityMode
                            ? context.l10n.highQualityEnabledNative(
                                dpr.toStringAsFixed(2),
                              )
                            : context.l10n.balancedModeEnabled(
                                math.min(dpr, 2.0).toStringAsFixed(2),
                              ),
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            IconButton(
              tooltip: context.l10n.resetView,
              icon: const Icon(Icons.refresh),
              onPressed: _resetCamera,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (!_isLoading &&
              _errorMessage == null &&
              _scene != null &&
              _pivotNode != null &&
              _orbitController != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _resetCamera,
                child: Listener(
                  onPointerDown: (_) {
                    if (_autoRotate) {
                      setState(() {
                        _autoRotate = false;
                      });
                    }
                  },
                  child: CameraControls(
                    key: ValueKey(_orbitController),
                    controller: _orbitController!,
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
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(context.l10n.building3dModel),
                ],
              ),
            ),

          if (_errorMessage != null)
            Center(
              child: Card(
                color: _errorMessage == k3DUnsupportedMessage
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.red.shade900.withAlpha(220),
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _errorMessage == k3DUnsupportedMessage
                            ? Icons.view_in_ar_outlined
                            : Icons.error_outline,
                        size: 48,
                        color: _errorMessage == k3DUnsupportedMessage
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _errorMessage == k3DUnsupportedMessage
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Top Controls (Pack Selector, Poses)
          if (!_isLoading && _errorMessage == null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Pack / Persona Switcher
                    if (_loadedPacks.length > 1 || hasMultipleCategories) ...[
                      SegmentedButton<String>(
                        segments: [
                          ..._loadedPacks.asMap().entries.map((e) {
                            final name = e.value.localizationName.isNotEmpty
                                ? e.value.localizationName
                                : e.value.serializeName;
                            return ButtonSegment<String>(
                              value: 'pack_${e.key}',
                              label: Text(
                                name,
                                style: const TextStyle(fontSize: 11),
                              ),
                              icon: const Icon(Icons.folder, size: 14),
                            );
                          }),
                          if (_loadedPersonaPieces.isNotEmpty)
                            ButtonSegment<String>(
                              value: 'persona',
                              label: Text(
                                context.l10n.persona,
                                style: const TextStyle(fontSize: 11),
                              ),
                              icon: const Icon(Icons.auto_awesome, size: 14),
                            ),
                        ],
                        selected: {
                          _isViewingPersona
                              ? 'persona'
                              : 'pack_$_selectedPackIndex',
                        },
                        onSelectionChanged: (newSelection) async {
                          final val = newSelection.first;
                          if (val == 'persona') {
                            await _selectPersonaPiece(_selectedPersonaIndex);
                          } else {
                            final idx =
                                int.tryParse(val.replaceFirst('pack_', '')) ??
                                0;
                            await _selectPack(idx);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                    ],

                    _buildPoseChip('standing', context.l10n.stand, Icons.man),
                    _buildPoseChip(
                      'walking',
                      context.l10n.walk,
                      Icons.directions_walk,
                    ),

                    if (_activeModel?.hasCape == true) ...[
                      SegmentedButton<BackEquipment>(
                        segments: [
                          ButtonSegment<BackEquipment>(
                            value: BackEquipment.cape,
                            label: Text(
                              context.l10n.cape,
                              style: const TextStyle(fontSize: 11),
                            ),
                            icon: Image.asset(
                              'assets/cape.png',
                              width: 16,
                              height: 16,
                            ),
                          ),
                          ButtonSegment<BackEquipment>(
                            value: BackEquipment.elytra,
                            label: Text(
                              context.l10n.elytra,
                              style: const TextStyle(fontSize: 11),
                            ),
                            icon: Image.asset(
                              'assets/elytra.png',
                              width: 16,
                              height: 16,
                            ),
                          ),
                        ],
                        selected: {_backEquipment},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _backEquipment = newSelection.first;
                            _activeModel?.setBackEquipment(_backEquipment);
                          });
                        },
                      ),
                    ],

                    FilterChip(
                      label: Text(
                        context.l10n.turntable,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _autoRotate,
                      showCheckmark: false,
                      avatar: const Icon(Icons.rotate_right, size: 16),
                      onSelected: (val) {
                        setState(() {
                          _autoRotate = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Navigation Pill
          if (!_isLoading && _errorMessage == null && !_isViewingPersona)
            Positioned(
              bottom: 18 + MediaQuery.paddingOf(context).bottom,
              left: 16,
              right: 16,
              child: _buildSkinNavigationBar(currentSkin),
            ),
        ],
      ),
    );
  }

  Widget _buildSkinNavigationBar(MinecraftSkinEntry? currentSkin) {
    if (_skins.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 22),
              color: colorScheme.onSurface,
              tooltip: context.l10n.previousSkin,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _selectedSkinIndex > 0
                  ? () => _selectSkin(_selectedSkinIndex - 1)
                  : null,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      currentSkin?.localizationName ?? context.l10n.skin,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${_selectedSkinIndex + 1}/${_skins.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (currentSkin != null && currentSkin.isCustomGeometry) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Custom Geo',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 22),
              color: colorScheme.onSurface,
              tooltip: context.l10n.nextSkin,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _selectedSkinIndex < _skins.length - 1
                  ? () => _selectSkin(_selectedSkinIndex + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoseChip(String poseKey, String label, IconData icon) {
    final isSelected = _pose == poseKey;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: Icon(icon, size: 16),
      showCheckmark: false,
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _pose = poseKey;
            if (_pose == 'standing') {
              _activeModel?.resetPose();
            }
          });
        }
      },
    );
  }

  Future<void> _selectSkin(int index) async {
    if (index < 0 || index >= _skins.length) return;
    final previousSkin = _skins[_selectedSkinIndex];
    final nextSkin = _skins[index];
    setState(() {
      _selectedSkinIndex = index;
    });

    // If the geometry or cape changed, rebuild the 3D model
    if (nextSkin.geometry != previousSkin.geometry ||
        nextSkin.isCustomGeometry != previousSkin.isCustomGeometry ||
        nextSkin.isSlim != previousSkin.isSlim ||
        nextSkin.cape != previousSkin.cape) {
      await _rebuildModel();
      return;
    }

    // Otherwise texture swap
    await _applyTexture(nextSkin.texturePath);
  }
}
