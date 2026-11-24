import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_scene/scene.dart';
import 'package:path/path.dart' as p;

import '../../3d_skins/cape_mesh.dart';
import '../../flutter_gpu/texture_utils.dart';
import '../../services/settings_service.dart';

/// Result of validating a Minecraft cape texture.
class CapeValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int width;
  final int height;

  const CapeValidationResult({
    required this.isValid,
    this.errorMessage,
    required this.width,
    required this.height,
  });

  const CapeValidationResult.valid({required this.width, required this.height})
    : isValid = true,
      errorMessage = null;

  const CapeValidationResult.invalid({
    required this.errorMessage,
    this.width = 0,
    this.height = 0,
  }) : isValid = false;
}

/// Validated cape texture bundle.
class LoadedCapeData {
  final String path;
  final String title;
  final Uint8List bytes;
  final TextureSource texture;
  final int width;
  final int height;

  const LoadedCapeData({
    required this.path,
    required this.title,
    required this.bytes,
    required this.texture,
    required this.width,
    required this.height,
  });
}

/// Service for cape validation, loading, 3D mesh creation, and offscreen export
class CapeRenderExportService {
  CapeRenderExportService._internal();
  static final CapeRenderExportService instance =
      CapeRenderExportService._internal();
  factory CapeRenderExportService() => instance;

  /// Validates whether [bytes] is a standard (64x32) or HD Minecraft cape texture
  Future<CapeValidationResult> validateCapeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;

      if (width < 22 || height < 17) {
        image.dispose();
        codec.dispose();
        return CapeValidationResult.invalid(
          errorMessage:
              'Image is too small ($width×$height). Minecraft capes must be at least 64×32.',
          width: width,
          height: height,
        );
      }

      if (width == height) {
        image.dispose();
        codec.dispose();
        return CapeValidationResult.invalid(
          errorMessage:
              'Selected image ($width×$height) has a 1:1 aspect ratio (standard for player skins or icons). Minecraft capes require a 2:1 ratio (e.g. 64×32, 512×256, 1024×512).',
          width: width,
          height: height,
        );
      }

      if (width != height * 2) {
        image.dispose();
        codec.dispose();
        return CapeValidationResult.invalid(
          errorMessage:
              'Invalid cape aspect ratio ($width×$height). Minecraft capes must have a 2:1 aspect ratio (width must be exactly twice the height).',
          width: width,
          height: height,
        );
      }

      // Verify visible cape pixels and ensure lower-right quadrant is transparent (legacy skins are opaque here).
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      codec.dispose();

      if (byteData == null) {
        return CapeValidationResult.valid(width: width, height: height);
      }

      final pixels = byteData.buffer.asUint8List();

      int capeVisiblePixels = 0;
      int bottomRightOpaquePixels = 0;
      int bottomRightSampleCount = 0;

      final minCapeX = (width * (1 / 64)).floor();
      final maxCapeX = (width * (22 / 64)).floor();
      final minCapeY = (height * (1 / 32)).floor();
      final maxCapeY = (height * (17 / 32)).floor();

      final stepX = math.max(1, (width / 64).floor());
      final stepY = math.max(1, (height / 32).floor());

      for (int y = minCapeY; y < maxCapeY; y += stepY) {
        for (int x = minCapeX; x < maxCapeX; x += stepX) {
          final index = (y * width + x) * 4;
          if (index + 3 < pixels.length) {
            final alpha = pixels[index + 3];
            if (alpha > 10) {
              capeVisiblePixels++;
            }
          }
        }
      }

      if (capeVisiblePixels == 0) {
        return CapeValidationResult.invalid(
          errorMessage:
              'The selected image appears to be completely empty or transparent.',
          width: width,
          height: height,
        );
      }

      final minBrX = (width * 0.75).floor();
      final minBrY = (height * 0.58).floor();

      for (int y = minBrY; y < height; y += stepY) {
        for (int x = minBrX; x < width; x += stepX) {
          final index = (y * width + x) * 4;
          if (index + 3 < pixels.length) {
            bottomRightSampleCount++;
            final alpha = pixels[index + 3];
            if (alpha > 128) {
              bottomRightOpaquePixels++;
            }
          }
        }
      }

      if (bottomRightSampleCount > 0 &&
          (bottomRightOpaquePixels / bottomRightSampleCount) > 0.35) {
        return CapeValidationResult.invalid(
          errorMessage:
              'This image appears to be a legacy player skin ($width×$height), not a cape. Cape textures have an empty lower-right section.',
          width: width,
          height: height,
        );
      }

      return CapeValidationResult.valid(width: width, height: height);
    } catch (e) {
      return CapeValidationResult.invalid(
        errorMessage: 'Failed to read image: $e',
      );
    }
  }

  /// Prompts the user to pick a PNG cape, validates it, and loads its GPU texture
  Future<LoadedCapeData?> pickAndLoadCape() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Select Minecraft Cape (.png)',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (file == null || file.path == null) {
      return null;
    }

    return loadCapeFromPath(file.path!);
  }

  Future<LoadedCapeData> loadCapeFromPath(String path) async {
    final bytes = await File(path).readAsBytes();
    final validation = await validateCapeImage(bytes);

    if (!validation.isValid) {
      throw Exception(validation.errorMessage ?? 'Invalid cape texture file.');
    }

    final texture = await loadSkinTexture(path);
    final title = p.basenameWithoutExtension(path);

    return LoadedCapeData(
      path: path,
      title: title,
      bytes: bytes,
      texture: texture,
      width: validation.width,
      height: validation.height,
    );
  }

  Node createCapeNode(TextureSource capeTexture, {bool lit = false}) =>
      buildCapeNode(capeTexture, lit: lit);

  /// Renders [scene] offscreen to a transparent PNG
  /// Automatically applies super-sampling anti-aliasing (SSAA) by rendering at
  /// a minimum of 2048px and downscaling with high-quality bicubic filtering
  Future<String> renderAndSaveToDownloads({
    required Scene scene,
    required Camera? camera,
    required int resolution,
    required String capeTitle,
    RenderRepaintBoundary? fallbackBoundary,
  }) async {
    if (camera == null) {
      throw Exception('Camera is not ready for rendering.');
    }

    final internalResolution = math.max(2048, resolution);

    ui.Image image;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final targetRect = ui.Rect.fromLTWH(
        0,
        0,
        internalResolution.toDouble(),
        internalResolution.toDouble(),
      );

      scene.render(camera, canvas, viewport: targetRect, pixelRatio: 1.0);

      final picture = recorder.endRecording();
      image = await picture.toImage(internalResolution, internalResolution);
      picture.dispose();
    } catch (renderError) {
      debugPrint(
        'Direct offscreen render failed: $renderError. Falling back to RepaintBoundary.',
      );
      if (fallbackBoundary == null) {
        throw Exception(
          'Direct render failed and boundary is unavailable: $renderError',
        );
      }
      final scale = internalResolution / fallbackBoundary.size.width;
      image = await fallbackBoundary.toImage(pixelRatio: scale);
    }

    if (internalResolution != resolution) {
      final downscaleRecorder = ui.PictureRecorder();
      final downscaleCanvas = ui.Canvas(downscaleRecorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
      downscaleCanvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          0,
          0,
          internalResolution.toDouble(),
          internalResolution.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, resolution.toDouble(), resolution.toDouble()),
        paint,
      );
      final downscaledPicture = downscaleRecorder.endRecording();
      final downscaledImage = await downscaledPicture.toImage(
        resolution,
        resolution,
      );
      downscaledPicture.dispose();
      image.dispose();
      image = downscaledImage;
    }

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to generate PNG image data.');
    }

    final pngBytes = byteData.buffer.asUint8List();

    final downloadPath = await SettingsService.instance.getDownloadPath();
    final safeName = capeTitle.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${safeName}_cape_${resolution}_$timestamp.png';

    final targetPath = p.join(downloadPath, fileName);
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(pngBytes);

    return targetPath;
  }
}
