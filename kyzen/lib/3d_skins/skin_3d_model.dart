import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../flutter_gpu/texture_utils.dart';
import 'bedrock_geometry.dart';
import 'bedrock_model_generator.dart';
import 'minecraft_skin_generator.dart';
import 'persona.dart';
import 'persona_model_generator.dart';
import 'skin_model_data.dart';

export 'persona.dart';
export 'persona_model_generator.dart';
export '../flutter_gpu/texture_utils.dart';

enum BackEquipment { cape, elytra }

/// Common interface
/// (both standard and custom geo)
abstract class Skin3DModel {
  Node get rootNode;
  Node? get capeNode;
  double get scale;
  set scale(double value);
  void setTexture(TextureSource texture);
  void attachCape(TextureSource capeTexture);
  void removeCape();
  void resetPose();
  void applyWalkAnimation(double t, {double speed = 4.0});

  BackEquipment? get backEquipment;

  bool get hasCape;

  TextureSource? get capeTexture;

  void setBackEquipment(BackEquipment equipment);
}

const double defaultCameraYaw = 0.4;
const double defaultCameraPitch = 0.08;
const double defaultCameraDistance = 45.0;
const double maxCameraPitch = math.pi / 2;

/// Default azimuth (horizontal angle) for front 3/4 orbit camera
const double defaultOrbitAzimuth = math.pi + defaultCameraYaw;

/// Default azimuth for viewing the back (cape)
const double defaultCapeOrbitAzimuth = 0.42;
const double defaultCapeOrbitPolar = 0.22;

/// Default polar (elevation) angle for orbit camera
const double defaultOrbitPolar = defaultCameraPitch;

/// rotation speed for orbit camera (radians per view-height of drag)
const double defaultOrbitRotateSpeed = math.pi * 2.0;

class SkinOrbitCameraController extends OrbitCameraController {
  double currentAzimuth;
  double currentPolar;
  double currentDistance;

  SkinOrbitCameraController({
    super.target,
    super.distance,
    super.azimuth,
    super.polar,
    super.minDistance,
    super.maxDistance,
    super.minPolar,
    super.maxPolar,
    super.rotateSpeed,
    super.dollySpeed,
    super.panSpeed = 0.0,
    super.scrollSensitivity,
    super.smoothing,
  }) : currentAzimuth = azimuth,
       currentPolar = polar,
       currentDistance = distance;

  @override
  void orbitBy(double deltaAzimuth, double deltaPolar) {
    currentAzimuth += deltaAzimuth;
    currentPolar = (currentPolar + deltaPolar).clamp(minPolar, maxPolar);
    super.orbitBy(deltaAzimuth, deltaPolar);
  }

  @override
  void dollyBy(double amount) {
    currentDistance = (currentDistance * math.exp(-amount * dollySpeed)).clamp(
      minDistance,
      maxDistance,
    );
    super.dollyBy(amount);
  }

  @override
  void handleDragUpdate(Offset delta) {
    final k = rotateSpeed / viewportSize.height;
    // inverted horizontal rotation
    orbitBy(delta.dx * k, delta.dy * k);
  }

  @override
  void panBy(Offset fraction) {
    // Disabled: keep camera target locked at model center
  }

  @override
  void handleSecondaryDragUpdate(Offset delta) {
    // Disabled: right-click pan disabled
  }

  @override
  void handleScaleUpdate(double scaleFactor, Offset focalDelta) {
    if (scaleFactor != 1.0) dollyBy(scaleFactor - 1.0);
  }
}

OrbitCameraController createSkinOrbitCameraController({
  vm.Vector3? target,
  double distance = defaultCameraDistance,
  double azimuth = defaultOrbitAzimuth,
  double polar = defaultOrbitPolar,
  double minDistance = 12.0,
  double maxDistance = 150.0,
  double rotateSpeed = defaultOrbitRotateSpeed,
  double smoothing = 0.08,
}) {
  return SkinOrbitCameraController(
    target: target ?? vm.Vector3.zero(),
    distance: distance,
    azimuth: azimuth,
    polar: polar,
    minDistance: minDistance,
    maxDistance: maxDistance,
    rotateSpeed: rotateSpeed,
    smoothing: smoothing,
  );
}

/// Sets up or updates an orbit camera on a [Scene]
/// Ensures [cameraNode] has a [CameraComponent] mounted in [scene], removes
/// [oldController] if present, and attaches a new [OrbitCameraController]
/// If [target] is not provided, it falls back to the center of [modelNode]s bounds
({Node cameraNode, OrbitCameraController controller}) setupOrbitCamera({
  required Scene scene,
  Node? cameraNode,
  OrbitCameraController? oldController,
  Node? modelNode,
  vm.Vector3? target,
  double? distance,
  double? azimuth,
  double? polar,
  bool isCape = false,
  bool forceReset = false,
  double minDistance = 16.0,
  double maxDistance = 150.0,
  double rotateSpeed = defaultOrbitRotateSpeed,
  double smoothing = 0.08,
}) {
  final camNode = cameraNode ?? (Node()..name = 'orbit_camera');

  var cameraComponent = camNode.getComponent<CameraComponent>();
  if (cameraComponent == null) {
    cameraComponent = CameraComponent(
      projection: PerspectiveProjection(
        fovRadiansY: 45 * vm.degrees2Radians,
        near: 0.5,
        far: 500.0,
      ),
    );
    camNode.addComponent(cameraComponent);
  } else {
    final proj = cameraComponent.projection;
    if (proj is PerspectiveProjection) {
      proj.near = 0.5;
      proj.far = 500.0;
    }
  }

  if (cameraNode == null) {
    scene.add(camNode);
  }

  if (oldController != null) {
    camNode.removeComponent(oldController);
  }

  final bounds = modelNode?.combinedLocalBounds;
  final targetCenter =
      target ?? (bounds != null ? bounds.center : vm.Vector3.zero());

  // Prevent camera from penetrating the model by keeping minDistance safe relative to bounds
  final boundRadius = bounds != null
      ? math.max((bounds.max - bounds.min).length * 0.5, 4.0)
      : 16.0;
  final safeMinDistance = math.max(minDistance, boundRadius * 0.70);

  final double effectiveAzimuth;
  final double effectivePolar;
  final double effectiveDistance;

  if (!forceReset && oldController is SkinOrbitCameraController) {
    effectiveAzimuth = azimuth ?? oldController.currentAzimuth;
    effectivePolar = polar ?? oldController.currentPolar;
    effectiveDistance = distance ?? oldController.currentDistance;
  } else {
    effectiveAzimuth =
        azimuth ?? (isCape ? defaultCapeOrbitAzimuth : defaultOrbitAzimuth);
    effectivePolar =
        polar ?? (isCape ? defaultCapeOrbitPolar : defaultOrbitPolar);
    effectiveDistance = distance ?? defaultCameraDistance;
  }

  final newController = createSkinOrbitCameraController(
    target: targetCenter,
    distance: effectiveDistance,
    azimuth: effectiveAzimuth,
    polar: effectivePolar,
    minDistance: safeMinDistance,
    maxDistance: maxDistance,
    rotateSpeed: rotateSpeed,
    smoothing: smoothing,
  );
  if (oldController != null) {
    newController.viewportSize = oldController.viewportSize;
  }
  camNode.addComponent(newController);

  return (cameraNode: camNode, controller: newController);
}

/// Calculates an optimal camera distance so the 3D skin model fills the viewport
/// without being cropped horizontally (on narrow screens) or vertically
double calculateCameraDistance({
  required double viewportWidth,
  required double viewportHeight,
  double modelHeight = 32.0,
  double modelWidth = 20.0,
  double verticalFill = 0.85,
  double horizontalFill = 0.80,
  double fovRadiansY = 45.0 * math.pi / 180.0,
}) {
  if (viewportWidth <= 0 || viewportHeight <= 0) return defaultCameraDistance;

  final tanHalfFov = math.tan(fovRadiansY / 2.0);
  final aspectRatio = viewportWidth / viewportHeight;

  final distV = modelHeight / (2.0 * tanHalfFov * verticalFill);
  final distH = modelWidth / (2.0 * tanHalfFov * aspectRatio * horizontalFill);

  return math.max(distV, distH);
}

Future<({Skin3DModel model, BedrockGeometry? geometry})> buildSkin3DModel({
  required MinecraftSkinEntry skin,
}) async {
  await initUnlitMaterials();
  Skin3DModel? model;
  BedrockGeometry? geometry;

  if (skin.isCustomGeometry) {
    try {
      geometry = await skin.loadGeometry();
      model = BedrockCustomModel(geometry: geometry);
    } catch (e) {
      debugPrint('Failed to load custom geometry: $e');
    }
  }

  // Fallback to standard model if not custom or if geo load failed
  model ??= MinecraftSkinModel(isSlim: skin.isSlim);

  try {
    final texture = await loadSkinTexture(skin.texturePath);
    model.setTexture(texture);
  } catch (e) {
    debugPrint('Failed to load skin texture ${skin.texturePath}: $e');
  }

  if (skin.hasCape && skin.capePath != null) {
    try {
      final capeTexture = await loadSkinTexture(skin.capePath!);
      model.attachCape(capeTexture);
    } catch (e) {
      debugPrint('Failed to load cape texture ${skin.capePath}: $e');
    }
  }

  return (model: model, geometry: geometry);
}

Future<Skin3DModel> buildPersona3DModel({required PersonaPiece piece}) async {
  await initUnlitMaterials();
  return await PersonaModel.create(piece: piece);
}
