import 'dart:math' as math;
import 'package:flutter_scene/scene.dart' hide Animation;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../l10n/context_extensions.dart';
import '../models/search_result.dart';
import '../services/download_service.dart';
import '../services/settings_service.dart';
import '../services/skin_service.dart';
import '../widgets/import_dialog.dart';
import '../widgets/interactive_camera_controls.dart';
import 'skin_3d_model.dart';
import 'skin_model_data.dart';
import 'skin_viewer_screen.dart';

/// Interactive view
class SkinPackPreview extends StatefulWidget {
  final SearchResult item;
  final SkinService? skinService;
  final bool autoLoad;
  final bool initiallyExpanded;

  const SkinPackPreview({
    super.key,
    required this.item,
    this.skinService,
    this.autoLoad = false,
    this.initiallyExpanded = false,
  });

  @override
  State<SkinPackPreview> createState() => _SkinPackPreviewState();
}

class _SkinPackPreviewState extends State<SkinPackPreview> {
  Scene? _scene;

  Scene? get _ensureScene {
    if (_sceneError != null) return null;
    if (_scene == null) {
      if (!is3DPreviewSupported()) {
        _sceneError = k3DUnsupportedMessage;
        return null;
      }
      try {
        final s = Scene();
        configureUnlitScene(s);
        _scene = s;
      } catch (e, stack) {
        debugPrint('SkinPackPreview: Scene creation failed: $e\n$stack');
        _sceneError = k3DUnsupportedMessage;
        return null;
      }
    }
    return _scene;
  }

  Node? _activeModelNode;
  SkinData? _skinData;
  List<MinecraftSkinEntry> _skins = [];
  int _selectedIndex = 0;

  late bool _isExpanded;

  // Camera and scene
  Node? _cameraNode;
  OrbitCameraController? _orbitController;

  int _modelBuildId = 0;
  bool _isBuildingModel = false;
  String? _sceneError;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;

    if (!SettingsService.instance.get3DPreviewSync()) {
      return;
    }

    if (!is3DPreviewSupported()) {
      _sceneError = k3DUnsupportedMessage;
    } else if (_isExpanded || widget.autoLoad) {
      if (_ensureScene != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final service = _effectiveSkinService;
          if (service.hasSkin) {
            _onSkinDataChanged(service.skinData);
          } else if (!service.isLoading) {
            _loadSkinWithFeedback();
          }
        });
      }
    }
  }

  SkinService get _effectiveSkinService =>
      widget.skinService ?? context.read<SkinService>();

  @override
  void didUpdateWidget(covariant SkinPackPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.dlcId != oldWidget.item.dlcId) {
      _isExpanded = widget.initiallyExpanded;
      _modelBuildId++;
      _clearScene();
      if (!SettingsService.instance.get3DPreviewSync()) {
        return;
      }
      if (!is3DPreviewSupported()) {
        _sceneError = k3DUnsupportedMessage;
      } else if (_isExpanded || widget.autoLoad) {
        if (_ensureScene != null) {
          final service = _effectiveSkinService;
          if (widget.autoLoad && !service.isLoading) {
            _loadSkinWithFeedback();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _clearScene();
    releaseTransientRenderTargets();
    _scene?.dispose();
    super.dispose();
  }

  void _onSkinDataChanged(SkinData? data) {
    if (data == null || data == _skinData) return;
    _skinData = data;
    final pack = data.primaryPack;
    if (pack != null && pack.skins.isNotEmpty) {
      _skins = pack.skins;
      _selectedIndex = 0;
      if (_isExpanded || widget.autoLoad) {
        _rebuildActiveModel();
      }
    }
  }

  void _clearScene() {
    if (_activeModelNode != null && _scene != null) {
      _scene!.remove(_activeModelNode!);
      _activeModelNode = null;
    }
  }

  Future<void> _rebuildActiveModel() async {
    if (_skins.isEmpty || _selectedIndex >= _skins.length || !mounted) return;
    final skin = _skins[_selectedIndex];
    final buildId = ++_modelBuildId;

    setState(() {
      _isBuildingModel = true;
      _sceneError = null;
    });

    try {
      await Scene.initializeStaticResources();
      final (:model, geometry: _) = await buildSkin3DModel(skin: skin);

      final node = Node()..add(model.rootNode);
      node.position = vm.Vector3(0, 0, 0);
      node.rotation = vm.Quaternion.identity();

      if (!mounted || buildId != _modelBuildId) return;

      final s = _ensureScene;
      if (s == null) return;
      final oldNode = _activeModelNode;
      _activeModelNode = node;
      s.add(node);
      if (oldNode != null) {
        s.remove(oldNode);
      }
      _setupOrbitCamera();
    } catch (e) {
      debugPrint('SkinPackPreview: error building active model: $e');
      _sceneError = isImpellerOrGpuException(e)
          ? k3DUnsupportedMessage
          : e.toString();
    } finally {
      if (mounted && buildId == _modelBuildId) {
        setState(() {
          _isBuildingModel = false;
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
    final s = _ensureScene;
    if (s == null) return;
    final isCape =
        _skins.isNotEmpty &&
        _selectedIndex < _skins.length &&
        _skins[_selectedIndex].hasCape;

    final res = setupOrbitCamera(
      scene: s,
      cameraNode: _cameraNode,
      oldController: _orbitController,
      modelNode: _activeModelNode,
      target: target,
      distance: distance ?? defaultCameraDistance,
      azimuth: azimuth,
      polar: polar,
      isCape: isCape,
    );
    _cameraNode = res.cameraNode;
    _orbitController = res.controller;
  }

  void _selectSkin(int index) {
    if (index < 0 || index >= _skins.length || index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
    _rebuildActiveModel();
  }

  @override
  Widget build(BuildContext context) {
    if (!SettingsService.instance.get3DPreviewSync()) {
      return const SizedBox.shrink();
    }
    final skinService = _effectiveSkinService;

    return ListenableBuilder(
      listenable: skinService,
      builder: (context, _) {
        if (skinService.hasSkin && skinService.skinData != _skinData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onSkinDataChanged(skinService.skinData);
          });
        }

        final selectedSkin = _skins.isNotEmpty && _selectedIndex < _skins.length
            ? _skins[_selectedIndex]
            : null;

        final headerText = selectedSkin != null
            ? selectedSkin.localizationName.toUpperCase()
            : (widget.item.packType == 'SkinPack'
                  ? '${widget.item.title.toUpperCase()}: ${context.l10n.skins.toUpperCase()}'
                  : context.l10n.includedSkins.toUpperCase());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, headerText, selectedSkin),
            if (_isExpanded)
              TweenAnimationBuilder<double>(
                key: ValueKey(_isExpanded),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                builder: (context, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    if (skinService.isLoading)
                      _buildLoadingState(context, skinService.progress)
                    else if (_sceneError != null || skinService.error != null)
                      _buildErrorState(
                        context,
                        _sceneError ?? skinService.error!,
                      )
                    else if (_skins.isNotEmpty)
                      _buildViewerBody(context)
                    else
                      _buildLoadingState(context, 0.0),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String headerText,
    MinecraftSkinEntry? selectedSkin,
  ) {
    final hasSkins = _skins.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        if (!is3DPreviewSupported()) {
          setState(() {
            _isExpanded = !_isExpanded;
            _sceneError = k3DUnsupportedMessage;
          });
          return;
        }
        final shouldLoad =
            !_isExpanded && _skins.isEmpty && !_effectiveSkinService.isLoading;
        final willExpand = !_isExpanded;
        setState(() {
          _isExpanded = willExpand;
        });
        if (willExpand) {
          if (_ensureScene == null) {
            setState(() {});
            return;
          }
          if (_skins.isNotEmpty && _activeModelNode == null) {
            _rebuildActiveModel();
          }
        }
        if (shouldLoad) {
          _loadSkinWithFeedback();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.view_in_ar_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          headerText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasSkins &&
                          selectedSkin != null &&
                          selectedSkin.isCustomGeometry) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.8,
                            ),
                            borderRadius: BorderRadius.circular(4),
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
                    ],
                  ),
                  if (!_isExpanded)
                    Text(
                      hasSkins
                          ? context.l10n.tapToExpand3dSkinPreview(
                              _selectedIndex + 1,
                              _skins.length,
                            )
                          : (widget.item.packType == 'SkinPack'
                                ? context.l10n.tapToPreview3dSkins
                                : context.l10n.tapToPreviewIncluded3dSkins),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (hasSkins &&
                _isExpanded &&
                _sceneError == null &&
                is3DPreviewSupported()) ...[
              Text(
                '${_selectedIndex + 1}/${_skins.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.open_in_full, size: 16),
                tooltip: context.l10n.open3dViewer,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SkinViewerScreen(skinPacks: _skinData?.skinPacks),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
            if (widget.item.packType != 'SkinPack' &&
                widget.item.skinBinaryUrl != null) ...[
              _buildSkinDownloadButton(context),
              const SizedBox(width: 4),
            ],
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkinDownloadButton(BuildContext context) {
    final downloadService = context.watch<DownloadService>();
    final colorScheme = Theme.of(context).colorScheme;
    final skinDlcId = '${widget.item.dlcId}_skinpack';

    if (downloadService.isDownloaded(skinDlcId)) {
      final filePaths = downloadService.getDownloadedFilePaths(skinDlcId);
      return IconButton(
        icon: const Icon(
          Icons.check_circle_outline_rounded,
          size: 18,
          color: Colors.green,
        ),
        tooltip: context.l10n.importToMc,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: filePaths.isNotEmpty
            ? () => showImportDialog(context, filePaths)
            : null,
      );
    } else if (downloadService.isFailed(skinDlcId)) {
      return IconButton(
        icon: Icon(Icons.refresh_rounded, size: 18, color: colorScheme.error),
        tooltip: context.l10n.retryDownload,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: () {
          downloadService.downloadSkinPack(
            widget.item,
            strings: DownloadStrings.of(context),
          );
        },
      );
    } else {
      final isBusy =
          downloadService.currentItemId == skinDlcId ||
          downloadService.isInQueue(skinDlcId);
      return IconButton(
        icon: Icon(
          Icons.download_rounded,
          size: 18,
          color: isBusy
              ? colorScheme.onSurface.withValues(alpha: 0.38)
              : colorScheme.primary,
        ),
        tooltip: isBusy
            ? context.l10n.downloading
            : context.l10n.downloadSkinPack,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: isBusy
            ? null
            : () {
                downloadService.downloadSkinPack(
                  widget.item,
                  strings: DownloadStrings.of(context),
                );
              },
      );
    }
  }

  Widget _buildViewerBody(BuildContext context) {
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final effectiveDpr = math.min(dpr, 2.0);
    final size = MediaQuery.sizeOf(context);
    final canGoPrev = _selectedIndex > 0;
    final canGoNext = _selectedIndex < _skins.length - 1;

    final camDist = calculateCameraDistance(
      viewportWidth: size.width,
      viewportHeight: 280.0,
    );

    if (_orbitController == null && _activeModelNode != null) {
      _setupOrbitCamera(distance: camDist);
    }

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          // 3D Scene View
          if (_activeModelNode != null && _orbitController != null)
            Positioned.fill(
              child: InteractiveCameraControls(
                controller: _orbitController!,
                onDoubleTap: () {
                  setState(() {
                    _setupOrbitCamera(distance: camDist);
                  });
                },
                child: TickerMode(
                  enabled: isCurrentRoute,
                  child: _ensureScene != null
                      ? SceneView(
                          _ensureScene!,
                          pixelRatio: effectiveDpr,
                          maxFrameRate: 60,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),

          if (_isBuildingModel || _activeModelNode == null)
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),

          // Left Nav Chevron
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 24),
                  color: Colors.white,
                  tooltip: context.l10n.previousSkin,
                  onPressed: canGoPrev
                      ? () => _selectSkin(_selectedIndex - 1)
                      : null,
                ),
              ),
            ),
          ),

          // Right Nav Chevron
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 24),
                  color: Colors.white,
                  tooltip: context.l10n.nextSkin,
                  onPressed: canGoNext
                      ? () => _selectSkin(_selectedIndex + 1)
                      : null,
                ),
              ),
            ),
          ),

          // Subtle rotation hint
          Positioned(
            bottom: 4,
            right: 12,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.rotate_right,
                    size: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    context.l10n.dragToRotate,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, double progress) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 12),
          Text(
            progress > 0
                ? context.l10n.downloadingAndPreparingSkins(
                    (progress * 100).toInt(),
                  )
                : context.l10n.preparing3dSkins,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (progress > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final isUnsupported = error == k3DUnsupportedMessage;
    return Container(
      height: 160,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUnsupported ? Icons.view_in_ar_outlined : Icons.error_outline,
            color: isUnsupported
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Colors.orange,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            isUnsupported ? error : context.l10n.failedToLoadSkins(error),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (!isUnsupported) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(context.l10n.retry),
              onPressed: () => _loadSkinWithFeedback(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadSkinWithFeedback() async {
    final service = _effectiveSkinService;
    await service.loadSkin(widget.item);
    if (mounted && service.error != null) {
      _showErrorSnackBar(service.error!);
    }
  }

  void _showErrorSnackBar(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}
