import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_gpu/gpu.dart' as flutter_gpu;
import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../services/settings_service.dart';

/// nearest-neighbor to get crisp pixel
final gpu.SamplerOptions nearestSamplerOptions = gpu.SamplerOptions(
  minFilter: gpu.MinMagFilter.nearest,
  magFilter: gpu.MinMagFilter.nearest,
  mipFilter: gpu.MipFilter.nearest,
  widthAddressMode: gpu.SamplerAddressMode.clampToEdge,
  heightAddressMode: gpu.SamplerAddressMode.clampToEdge,
);

/// for 2d textures
const TextureSampling nearestTextureSampling = TextureSampling(
  mipmaps: false,
  minFilter: gpu.MinMagFilter.nearest,
  magFilter: gpu.MinMagFilter.nearest,
  mipFilter: gpu.MipFilter.nearest,
  addressMode: gpu.SamplerAddressMode.clampToEdge,
);

/// Wraps a [TextureSource] into a [GpuTextureSource] with nearest-neighbor sampling
TextureSource toNearestGpuTexture(TextureSource tex) {
  if (tex is GpuTextureSource &&
      tex.sampler.minFilter == gpu.MinMagFilter.nearest &&
      tex.sampler.magFilter == gpu.MinMagFilter.nearest) {
    return tex;
  }
  final gpuTex = tex.sampledTexture;
  if (gpuTex == null) return tex;
  return GpuTextureSource(gpuTex, sampler: nearestSamplerOptions);
}

/// Dynamically scales render resolution based on frame timings
/// (for low-end devices)
void configureAdaptiveResolution(Scene scene, {bool? enabled}) {
  final isEnabled =
      enabled ?? SettingsService.instance.getAdaptiveResolutionSync();
  scene.renderQuality.adaptive = isEnabled;
}

void configureUnlitScene(Scene scene, {bool? adaptiveResolution}) {
  // anti aliasing disabled, msaa has some weird artifacts and fxaa makes the model have soft edges
  scene.antiAliasingMode = AntiAliasingMode.none;
  scene.toneMapping = ToneMappingMode.linear;
  scene.environment = EnvironmentMap.empty();
  scene.environmentIntensity = 0.0;
  configureAdaptiveResolution(scene, enabled: adaptiveResolution);
}

/// Unlit (flat lighthing)
void configureUnlitMaterial(PhysicallyBasedMaterial mat) {
  mat.baseColorFactor = vm.Vector4(0.0, 0.0, 0.0, 1.0);
  mat.emissiveFactor = vm.Vector4(1.0, 1.0, 1.0, 1.0);
  mat.roughnessFactor = 1.0;
  mat.metallicFactor = 0.0;
  mat.vertexColorWeight = 0.0;
  if (mat.emissiveTexture == null && mat.baseColorTexture != null) {
    mat.emissiveTexture = mat.baseColorTexture;
  }
}

/// Diffuse lit (matte shading with shadows/lighting)
void configureLitMaterial(PhysicallyBasedMaterial mat) {
  mat.baseColorFactor = vm.Vector4(1.0, 1.0, 1.0, 1.0);
  mat.emissiveFactor = vm.Vector4(0.0, 0.0, 0.0, 1.0);
  mat.roughnessFactor = 1.0;
  mat.metallicFactor = 0.0;
}

/// Metadata describing the unlit_cutout custom material.
const Map<String, Object?> unlitCutoutMetadata = {
  'name': 'unlit_cutout',
  'framework_varying_schema': 2,
  'domain': 'surface',
  'shading_model': 'unlit',
  'blending': 'opaque',
  'culling': 'none',
  'uniform_block': 'MaterialParams',
  'attributes': <Object>[],
  'parameters': [
    {
      'name': 'base_color_factor',
      'type': 'vec4',
      'default': [1.0, 1.0, 1.0, 1.0],
    },
  ],
  'samplers': [
    {
      'name': 'base_color_texture',
      'type': 'sampler2D',
      'hint': {'kind': 'default_white'},
    },
  ],
};

gpu.Shader? _unlitCutoutShader;
Future<void>? _initUnlitMaterialsFuture;

/// Preloads and caches the compiled unlit_cutout shader bundle on demand.
Future<void> initUnlitMaterials() {
  if (_unlitCutoutShader != null) return Future.value();
  return _initUnlitMaterialsFuture ??= () async {
    try {
      final mat = await loadFmatMaterial('assets/materials/unlit_cutout.fmat');
      _unlitCutoutShader = mat.fragmentShader;
    } catch (e) {
      debugPrint("fallback to PhysicallyBasedMaterial");
      // Falls back to PhysicallyBasedMaterial if shaders are unavailable
    }
  }();
}

/// Sets [texture] on [mat], handling both [PreprocessedMaterial] and [PhysicallyBasedMaterial].
void setMaterialTexture(Material mat, TextureSource texture) {
  if (mat is PreprocessedMaterial) {
    final gpuTex = texture.sampledTexture;
    if (gpuTex != null) {
      mat.parameters.setTexture(
        'base_color_texture',
        gpuTex,
        sampler: nearestSamplerOptions,
      );
    }
  } else if (mat is PhysicallyBasedMaterial) {
    final nearest = toNearestGpuTexture(texture);
    mat.baseColorTexture = nearest;
    mat.emissiveTexture = nearest;
  }
}

Material createUnlitSkinMaterial({
  TextureSource? texture,
  bool doubleSided = true,
  double alphaCutoff = 0.5,
  AlphaMode alphaMode = AlphaMode.mask,
  int depthLayer = 0,
}) {
  if (_unlitCutoutShader != null) {
    final mat = PreprocessedMaterial(
      fragmentShader: _unlitCutoutShader!,
      metadata: unlitCutoutMetadata,
    );
    mat.depthLayer = depthLayer;
    mat.doubleSided = doubleSided;
    if (texture != null && texture.sampledTexture != null) {
      mat.parameters.setTexture(
        'base_color_texture',
        texture.sampledTexture!,
        sampler: nearestSamplerOptions,
      );
    }
    return mat;
  }

  final material = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.0, 0.0, 0.0, 1.0)
    ..emissiveFactor = vm.Vector4(1.0, 1.0, 1.0, 1.0)
    ..roughnessFactor = 1.0
    ..metallicFactor = 0.0
    ..vertexColorWeight = 0.0
    ..alphaMode = alphaMode
    ..alphaCutoff = alphaCutoff
    ..depthLayer = depthLayer
    ..doubleSided = doubleSided;

  if (texture != null) {
    final nearest = toNearestGpuTexture(texture);
    material.baseColorTexture = nearest;
    material.emissiveTexture = nearest;
  }

  return material;
}

/// Creates a matte, diffuse lit material with nearest-neighbor texture sampling.
Material createLitSkinMaterial({
  TextureSource? texture,
  bool doubleSided = true,
  double alphaCutoff = 0.5,
  AlphaMode alphaMode = AlphaMode.mask,
  int depthLayer = 0,
}) {
  final material = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(1.0, 1.0, 1.0, 1.0)
    ..emissiveFactor = vm.Vector4(0.0, 0.0, 0.0, 1.0)
    ..roughnessFactor = 1.0
    ..metallicFactor = 0.0
    ..alphaMode = alphaMode
    ..alphaCutoff = alphaCutoff
    ..depthLayer = depthLayer
    ..doubleSided = doubleSided;

  if (texture != null) {
    material.baseColorTexture = toNearestGpuTexture(texture);
  }

  return material;
}

/// Applies unlit material settings to all materials in [rootNode]
void applyUnlitMaterials(Node rootNode, {bool? doubleSided, int? depthLayer}) {
  for (final meshNode in rootNode.meshNodes) {
    final mesh = meshNode.mesh;
    if (mesh == null) continue;
    for (final primitive in mesh.primitives) {
      final mat = primitive.material;
      if (mat is PhysicallyBasedMaterial) {
        configureUnlitMaterial(mat);
      }
      if (doubleSided != null) {
        mat.doubleSided = doubleSided;
      }
      if (depthLayer != null) {
        mat.depthLayer = depthLayer;
      }
    }
  }
}

/// Applies diffuse lit material settings to all materials in [rootNode].
void applyLitMaterials(Node rootNode, {bool? doubleSided, int? depthLayer}) {
  for (final meshNode in rootNode.meshNodes) {
    final mesh = meshNode.mesh;
    if (mesh == null) continue;
    for (final primitive in mesh.primitives) {
      final mat = primitive.material;
      if (mat is PhysicallyBasedMaterial) {
        configureLitMaterial(mat);
      }
      if (doubleSided != null) {
        mat.doubleSided = doubleSided;
      }
      if (depthLayer != null) {
        mat.depthLayer = depthLayer;
      }
    }
  }
}

/// Applies nearest-neighbor texture filtering to all PBR materials in [rootNode].
/// Otherwise they can appear very blurry on "low res" glb models...
void applyNearestTextureFiltering(Node rootNode) {
  for (final meshNode in rootNode.meshNodes) {
    final mesh = meshNode.mesh;
    if (mesh == null) continue;
    for (final primitive in mesh.primitives) {
      final mat = primitive.material;
      if (mat is PhysicallyBasedMaterial) {
        final currentSource = mat.baseColorTexture;
        if (currentSource != null) {
          mat.baseColorTexture = toNearestGpuTexture(currentSource);
        }
        final currentEmissive = mat.emissiveTexture ?? currentSource;
        if (currentEmissive != null) {
          mat.emissiveTexture = toNearestGpuTexture(currentEmissive);
        }
      }
    }
  }
}

/// Helper to load a skin/model texture from a file or asset path with nearest-neighbor filtering.
Future<Texture2D> loadSkinTexture(String path, {bool nearest = true}) async {
  await initUnlitMaterials();
  final sampling = nearest
      ? nearestTextureSampling
      : const TextureSampling(
          mipmaps: false,
          minFilter: gpu.MinMagFilter.linear,
          magFilter: gpu.MinMagFilter.linear,
          mipFilter: gpu.MipFilter.linear,
          addressMode: gpu.SamplerAddressMode.clampToEdge,
        );

  final file = File(path);
  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    return await Texture2D.fromEncodedBytes(bytes, sampling: sampling);
  }

  return await Texture2D.fromAsset(path, sampling: sampling);
}

bool? _is3DSupported;

const String k3DUnsupportedMessage =
    '3D preview for this device is unsupported';

/// Checks whether Flutter GPU / Impeller 3D rendering is supported on this device
bool is3DPreviewSupported() {
  if (_is3DSupported != null) return _is3DSupported!;

  // Direct engine check: is Impeller running? (False on Skia)
  if (!ui.ImageFilter.isShaderFilterSupported) {
    debugPrint('3D rendering is not supported: Impeller is not enabled');
    _is3DSupported = false;
    unawaited(SettingsService.instance.set3DPreview(false));
    return false;
  }

  // Impeller is active; verify Flutter GPU context
  try {
    final _ = flutter_gpu.gpuContext;
    _is3DSupported = true;
  } catch (e) {
    debugPrint('3D rendering is not supported on this device: $e');
    _is3DSupported = false;
    unawaited(SettingsService.instance.set3DPreview(false));
  }
  return _is3DSupported!;
}

/// Helper to detect if an exception is caused by Flutter GPU / Impeller unavailability
bool isImpellerOrGpuException(dynamic error) {
  if (error == null) return false;
  final str = error.toString().toLowerCase();
  final isGpuError =
      str.contains('impeller') ||
      str.contains('flutter gpu') ||
      str.contains('gpucontext') ||
      str.contains('unsupported');
  if (isGpuError) {
    _is3DSupported = false;
    unawaited(SettingsService.instance.set3DPreview(false));
  }
  return isGpuError;
}
