import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../3d_skins/persona_model_generator.dart';

class PersonaTextures {
  final img.Image body;
  final img.Image head;

  const PersonaTextures({required this.body, required this.head});
}

/// Holds raw PNG byte slices
class PersonaRawTextures {
  final Uint8List body;
  final Uint8List head;

  const PersonaRawTextures({required this.body, required this.head});
}

/// Validation result for an imported Minecraft skin PNG file.
class SkinValidationResult {
  final bool isValid;
  final String? error;
  final int? width;
  final int? height;
  final img.Image? image;

  const SkinValidationResult._({
    required this.isValid,
    this.error,
    this.width,
    this.height,
    this.image,
  });

  factory SkinValidationResult.valid({
    required int width,
    required int height,
    required img.Image image,
  }) => SkinValidationResult._(
    isValid: true,
    width: width,
    height: height,
    image: image,
  );

  factory SkinValidationResult.invalid(String error) =>
      SkinValidationResult._(isValid: false, error: error);
}

/// transform Minecraft skins into Bedrock Persona GLB textures,
/// inject them directly into .glb containers
class PersonaGlbService extends ChangeNotifier {
  static final PersonaGlbService instance = PersonaGlbService._internal();
  PersonaGlbService._internal();
  factory PersonaGlbService() => instance;

  static const int _glbMagic = 0x46546C67; // "glTF"
  static const int _chunkJson = 0x4E4F534A; // "JSON"
  static const int _chunkBin = 0x004E4942; // "BIN\0"

  static const String _customGlbFileName = 'custom_persona.glb';
  static const String _customHeadFileName = 'custom_head.png';
  static const String _metaFileName = 'custom_persona_meta.json';

  Uint8List? _cachedGlbBytes;
  PersonaRawTextures? _cachedRawTextures;
  PersonaRawTextures? _cachedEmoteRawTextures;
  Uint8List? _cachedAvatarBytes;
  Uint8List? _cachedTemplateGlbBytes;
  String? _cachedSkinName;
  bool? _cachedHasCustom;
  Directory? _cachedKyzenDir;

  Future<Directory> _getKyzenDir() async {
    if (_cachedKyzenDir != null) return _cachedKyzenDir!;
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'kyzen'));
    _cachedKyzenDir = dir;
    return dir;
  }

  /// Retrieves the destination file for the custom persona GLB.
  Future<File> getCustomPersonaFile() async {
    final dir = await _getKyzenDir();
    return File(p.join(dir.path, _customGlbFileName));
  }

  /// Retrieves the file for the pre-extracted custom head avatar image.
  Future<File> getCustomHeadFile() async {
    final dir = await _getKyzenDir();
    return File(p.join(dir.path, _customHeadFileName));
  }

  /// Returns bytes of custom_head.png if it exists, or null.
  Future<Uint8List?> getCustomHeadBytes() async {
    if (_cachedAvatarBytes != null) return _cachedAvatarBytes;
    if (_cachedHasCustom == false) return null;
    try {
      final headFile = await getCustomHeadFile();
      if (await headFile.exists()) {
        final bytes = await headFile.readAsBytes();
        _cachedAvatarBytes = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('Error reading custom_head.png: $e');
    }
    return null;
  }

  Future<File> _getMetaFile() async {
    final dir = await _getKyzenDir();
    return File(p.join(dir.path, _metaFileName));
  }

  /// Loads and cache
  Future<Uint8List> _getTemplateGlbBytes() async {
    if (_cachedTemplateGlbBytes != null) return _cachedTemplateGlbBytes!;
    final byteData = await rootBundle.load('assets/persona.glb');
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    _cachedTemplateGlbBytes = bytes;
    return bytes;
  }

  /// Whether a custom persona GLB currently exists
  Future<bool> hasCustomPersona() async {
    if (_cachedHasCustom != null) return _cachedHasCustom!;
    final file = await getCustomPersonaFile();
    final exists = await file.exists();
    _cachedHasCustom = exists;
    return exists;
  }

  Future<Map<String, dynamic>?> getCustomSkinMetadata() async {
    try {
      final metaFile = await _getMetaFile();
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error reading custom persona metadata: $e');
    }
    return null;
  }

  /// Returns the custom skin name, or null if using the default skin.
  Future<String?> getCustomSkinName() async {
    if (_cachedSkinName != null) return _cachedSkinName;
    if (_cachedHasCustom == false) return null;
    final meta = await getCustomSkinMetadata();
    _cachedSkinName = meta?['skinName'] as String?;
    return _cachedSkinName;
  }

  /// Loads the active persona GLB bytes (custom persona if present, otherwise default)
  Future<Uint8List> getPersonaGlbBytes() async {
    if (_cachedGlbBytes != null) return _cachedGlbBytes!;

    final customFile = await getCustomPersonaFile();
    if (await customFile.exists()) {
      try {
        final bytes = await customFile.readAsBytes();
        _cachedGlbBytes = bytes;
        _cachedHasCustom = true;
        return bytes;
      } catch (e) {
        debugPrint('Error reading custom_persona.glb: $e');
      }
    }

    _cachedHasCustom = false;
    final bytes = await _getTemplateGlbBytes();
    _cachedGlbBytes = bytes;
    return bytes;
  }

  Future<Node> loadPersonaNode() async {
    final bytes = await getPersonaGlbBytes();
    return Node.fromGlbBytes(bytes);
  }

  /// Returns the base body and head PNG bytes extracted from the active persona GLB.
  Future<PersonaRawTextures> getBasePersonaPngBytes() async {
    if (_cachedRawTextures != null) return _cachedRawTextures!;
    final bytes = await getPersonaGlbBytes();
    final textures = extractRawTexturesFromGlb(bytes);
    _cachedRawTextures = textures;
    return textures;
  }

  /// Returns the body and head PNG bytes for [EmotePlayer], where front and back are
  /// flipped 180 degrees so the skin renders facing the camera without needing to rotate
  /// the pivot node (which would invert the unrotated Bedrock animation)
  Future<PersonaRawTextures> getEmotePersonaPngBytes() async {
    if (_cachedEmoteRawTextures != null) return _cachedEmoteRawTextures!;
    final baseTextures = await getBasePersonaPngBytes();
    final decodedBody = img.decodePng(baseTextures.body);
    final decodedHead = img.decodePng(baseTextures.head);
    if (decodedBody == null || decodedHead == null) {
      return baseTextures;
    }
    final flipped = flipPersonaTexturesForEmote(
      PersonaTextures(body: decodedBody, head: decodedHead),
    );
    final emoteTextures = PersonaRawTextures(
      body: Uint8List.fromList(img.encodePng(flipped.body)),
      head: Uint8List.fromList(img.encodePng(flipped.head)),
    );
    _cachedEmoteRawTextures = emoteTextures;
    return emoteTextures;
  }

  /// Generates a 2D front-facing head avatar image by compositing the hat outer layer face
  /// on top of the base head face from a Persona head texture.
  static img.Image extractHeadAvatarFromHeadTexture(
    img.Image headTex, {
    int targetSize = 64,
  }) {
    final int s = headTex.width ~/ 32;
    final int faceSize = 8 * s;
    // crop the base face
    final avatar = img.copyCrop(
      headTex,
      x: 8 * s,
      y: 8 * s,
      width: faceSize,
      height: faceSize,
    );
    // hat layer face
    img.compositeImage(
      avatar,
      headTex,
      srcX: 8 * s,
      srcY: 24 * s,
      srcW: faceSize,
      srcH: faceSize,
      dstX: 0,
      dstY: 0,
      dstW: faceSize,
      dstH: faceSize,
    );

    if (targetSize > 0 && targetSize != faceSize) {
      return img.copyResize(
        avatar,
        width: targetSize,
        height: targetSize,
        interpolation: img.Interpolation.nearest,
      );
    }
    return avatar;
  }

  Future<Uint8List> getPersonaHeadAvatarBytes() async {
    final customBytes = await getCustomHeadBytes();
    if (customBytes != null) return customBytes;

    final byteData = await rootBundle.load('assets/persona_head.png');
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    _cachedAvatarBytes = bytes;
    return bytes;
  }

  static SkinValidationResult validateSkinBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      return SkinValidationResult.invalid('File is empty.');
    }

    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return SkinValidationResult.invalid(
        'Selected file is not a valid PNG image.',
      );
    }

    final int w = decoded.width;
    final int h = decoded.height;

    // Supported formats:
    // 64x64 standard modern Minecraft skin
    // 64x32 legacy Minecraft skin (pre-1.8)
    // 128x128 HD Minecraft skin
    // Any multiple of 64 with 1:1 ratio (e.g. 256x256) or 2:1 ratio (e.g. 128x64)
    final bool isSquare = (w == h);
    final bool isLegacyRatio = (w == h * 2);
    final bool isMultipleOf64 = (w >= 64 && w % 64 == 0);

    if (!isMultipleOf64 || (!isSquare && !isLegacyRatio)) {
      return SkinValidationResult.invalid(
        'Unsupported skin dimensions (${w}x$h). '
        'Minecraft skins must be 64x64, 128x128, or 64x32.',
      );
    }

    final bool slim = isSlimSkin(decoded);
    if (slim) {
      return SkinValidationResult.invalid(
        'Slim (Alex) skins with 3-pixel arms are not supported. '
        'Please use a standard classic (Steve) skin with 4-pixel arms.',
      );
    }

    return SkinValidationResult.valid(width: w, height: h, image: decoded);
  }

  Future<void> saveCustomSkin(
    Uint8List skinBytes, {
    String? skinName,
    bool standardSize = false,
  }) async {
    final validation = validateSkinBytes(skinBytes);
    if (!validation.isValid || validation.image == null) {
      throw ArgumentError(validation.error);
    }

    final decodedSkin = validation.image!;

    final textures = skinToPersonaTextures(
      decodedSkin,
      standardSize: standardSize,
    );

    final bodyPngBytes = Uint8List.fromList(img.encodePng(textures.body));
    final headPngBytes = Uint8List.fromList(img.encodePng(textures.head));

    final avatarImg = extractHeadAvatarFromHeadTexture(
      textures.head,
      targetSize: 64,
    );
    final avatarBytes = Uint8List.fromList(img.encodePng(avatarImg));

    final headFile = await getCustomHeadFile();
    if (!await headFile.parent.exists()) {
      await headFile.parent.create(recursive: true);
    }
    await headFile.writeAsBytes(avatarBytes, flush: true);

    final baseGlbBytes = await _getTemplateGlbBytes();

    final newGlbBytes = replaceGlbTextures(
      baseGlbBytes,
      bodyPngBytes,
      headPngBytes,
    );

    final targetFile = await getCustomPersonaFile();
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    await targetFile.writeAsBytes(newGlbBytes, flush: true);

    final name = skinName ?? 'Custom Skin';
    final metaFile = await _getMetaFile();
    await metaFile.writeAsString(json.encode({'skinName': name}));

    _cachedGlbBytes = newGlbBytes;
    _cachedRawTextures = PersonaRawTextures(
      body: bodyPngBytes,
      head: headPngBytes,
    );
    _cachedEmoteRawTextures = null;
    _cachedAvatarBytes = avatarBytes;
    _cachedSkinName = name;
    _cachedHasCustom = true;
    PersonaModel.invalidateBaseTextures();

    notifyListeners();
  }

  Future<void> resetToDefault() async {
    try {
      final file = await getCustomPersonaFile();
      if (await file.exists()) {
        await file.delete();
      }
      final headFile = await getCustomHeadFile();
      if (await headFile.exists()) {
        await headFile.delete();
      }
      final meta = await _getMetaFile();
      if (await meta.exists()) {
        await meta.delete();
      }
    } catch (e) {
      debugPrint('Error deleting custom persona files: $e');
    }

    _cachedGlbBytes = null;
    _cachedRawTextures = null;
    _cachedEmoteRawTextures = null;
    _cachedAvatarBytes = null;
    _cachedSkinName = null;
    _cachedHasCustom = false;
    PersonaModel.invalidateBaseTextures();

    notifyListeners();
  }

  static Uint8List applySkinToGlb(
    Uint8List glbBytes,
    Uint8List skinBytes, {
    bool standardSize = false,
  }) {
    final img.Image? decodedSkin = img.decodeImage(skinBytes);
    if (decodedSkin == null) {
      throw ArgumentError('Failed to decode skin PNG image.');
    }

    final textures = skinToPersonaTextures(
      decodedSkin,
      standardSize: standardSize,
    );

    final Uint8List bodyPng = Uint8List.fromList(img.encodePng(textures.body));
    final Uint8List headPng = Uint8List.fromList(img.encodePng(textures.head));

    return replaceGlbTextures(glbBytes, bodyPng, headPng);
  }

  /// Converts a Minecraft skin into the two Persona textures:
  /// - [PersonaTextures.body] (128x128 standard or 256x256)
  /// - [PersonaTextures.head] (32x32 standard or 64x64)
  /// By default, [standardSize] is false to preserve native HD skin resolution and
  /// prevent dropping sub-pixel details
  static PersonaTextures skinToPersonaTextures(
    img.Image inputSkin, {
    bool standardSize = false,
  }) {
    img.Image skin = inputSkin.convert(numChannels: 4);
    int w = skin.width;
    int h = skin.height;
    int scale = w ~/ 64;
    if (scale < 1) scale = 1;

    // Handle legacy 64x32 or scaled legacy (128x64)
    if (w == 64 * scale && h == 32 * scale) {
      final expanded = img.Image(
        width: 64 * scale,
        height: 64 * scale,
        numChannels: 4,
      );
      img.compositeImage(expanded, skin, dstX: 0, dstY: 0);

      // Copy and flip right arm, left arm
      final rArm = img.copyCrop(
        skin,
        x: 40 * scale,
        y: 16 * scale,
        width: 16 * scale,
        height: 16 * scale,
      );
      final lArm = img.copyFlip(rArm, direction: img.FlipDirection.horizontal);
      img.compositeImage(expanded, lArm, dstX: 32 * scale, dstY: 48 * scale);

      // Copy and flip right leg, left leg
      final rLeg = img.copyCrop(
        skin,
        x: 0,
        y: 16 * scale,
        width: 16 * scale,
        height: 16 * scale,
      );
      final lLeg = img.copyFlip(rLeg, direction: img.FlipDirection.horizontal);
      img.compositeImage(expanded, lLeg, dstX: 16 * scale, dstY: 48 * scale);

      skin = expanded;
      w = 64 * scale;
      h = 64 * scale;
    }

    if (standardSize && scale > 1) {
      skin = img.copyResize(
        skin,
        width: 64,
        height: 64,
        interpolation: img.Interpolation.nearest,
      );
      scale = 1;
    }

    final int s = scale;

    // Generate Head Texture (image1): (32*s x 32*s)
    final headTex = img.Image(width: 32 * s, height: 32 * s, numChannels: 4);
    // Head layer 1
    img.compositeImage(
      headTex,
      skin,
      srcX: 0,
      srcY: 0,
      srcW: 32 * s,
      srcH: 16 * s,
      dstX: 0,
      dstY: 0,
      dstW: 32 * s,
      dstH: 16 * s,
    );
    // Hat layer 2
    img.compositeImage(
      headTex,
      skin,
      srcX: 32 * s,
      srcY: 0,
      srcW: 32 * s,
      srcH: 16 * s,
      dstX: 0,
      dstY: 16 * s,
      dstW: 32 * s,
      dstH: 16 * s,
    );

    // Generate Body Texture (image0): (128*s x 128*s)
    final bodyTex = img.Image(width: 128 * s, height: 128 * s, numChannels: 4);

    // Coordinate mapping: [srcX, srcY, srcW, srcH, dstX, dstY] in 64-grid units
    const mappings = [
      // Row 0: rightArm, body, leftArm
      [40, 16, 16, 16, 0, 0],
      [16, 16, 24, 16, 16, 0],
      [32, 48, 16, 16, 40, 0],
      // Row 1: rightSleeve, jacket, leftSleeve
      [40, 32, 16, 16, 0, 16],
      [16, 32, 24, 16, 16, 16],
      [48, 48, 16, 16, 40, 16],
      // Row 2: rightPants, rightLeg, leftLeg, leftPants
      [0, 32, 16, 16, 0, 32],
      [0, 16, 16, 16, 16, 32],
      [16, 48, 16, 16, 32, 32],
      [0, 48, 16, 16, 48, 32],
    ];

    for (final m in mappings) {
      final int pw = m[2] * s;
      final int ph = m[3] * s;
      img.compositeImage(
        bodyTex,
        skin,
        srcX: m[0] * s,
        srcY: m[1] * s,
        srcW: pw,
        srcH: ph,
        dstX: m[4] * s,
        dstY: m[5] * s,
        dstW: pw,
        dstH: ph,
      );
    }

    return PersonaTextures(body: bodyTex, head: headTex);
  }

  /// Transforms standard Persona textures into emote-compatible textures by rotating each
  /// cuboid 180 degrees around Y, allowing [loadScene] to render the front of the skin
  /// on the side facing the camera without needing to rotate the model pivot (which would invert
  /// emote animations).
  static PersonaTextures flipPersonaTexturesForEmote(PersonaTextures standard) {
    final body = standard.body;
    final head = standard.head;
    final int sHead = head.width ~/ 32;
    final int sBody = body.width ~/ 128;

    // Flip Head
    final emoteHead = img.Image(
      width: head.width,
      height: head.height,
      numChannels: 4,
    );
    for (int layer = 0; layer < 2; layer++) {
      final int yBase = layer * 16 * sHead;

      // 4 side faces (Right, Front, Left, Back): horizontally shift by 16*sHead
      for (int y = yBase + 8 * sHead; y < yBase + 16 * sHead; y++) {
        for (int x = 0; x < 32 * sHead; x++) {
          final int newX = (x + 16 * sHead) % (32 * sHead);
          emoteHead.setPixel(newX, y, head.getPixel(x, y));
        }
      }

      // Top face: [8*sHead, yBase, 8*sHead, 8*sHead] rotated 180 in place
      for (int dy = 0; dy < 8 * sHead; dy++) {
        for (int dx = 0; dx < 8 * sHead; dx++) {
          emoteHead.setPixel(
            8 * sHead + dx,
            yBase + dy,
            head.getPixel(
              8 * sHead + (8 * sHead - 1 - dx),
              yBase + (8 * sHead - 1 - dy),
            ),
          );
        }
      }

      // Bottom face: [16*sHead, yBase, 8*sHead, 8*sHead] rotated 180 in place
      for (int dy = 0; dy < 8 * sHead; dy++) {
        for (int dx = 0; dx < 8 * sHead; dx++) {
          emoteHead.setPixel(
            16 * sHead + dx,
            yBase + dy,
            head.getPixel(
              16 * sHead + (8 * sHead - 1 - dx),
              yBase + (8 * sHead - 1 - dy),
            ),
          );
        }
      }
    }

    // Flip Body
    final emoteBody = img.Image(
      width: body.width,
      height: body.height,
      numChannels: 4,
    );

    void flipBox({
      required int srcDstX,
      required int srcDstY,
      required int targetDstX,
      required int targetDstY,
      required int w,
      required int h,
      required int d,
    }) {
      final int s = sBody;
      final int totalSideW = 2 * (w + d) * s;
      final int halfSideW = (w + d) * s;
      final int sideH = h * s;
      final int topH = d * s;

      // 4 side faces
      for (int y = 0; y < sideH; y++) {
        final int srcY = (srcDstY + d) * s + y;
        final int dstY = (targetDstY + d) * s + y;
        for (int x = 0; x < totalSideW; x++) {
          final int newX = (x + halfSideW) % totalSideW;
          emoteBody.setPixel(
            targetDstX * s + newX,
            dstY,
            body.getPixel(srcDstX * s + x, srcY),
          );
        }
      }

      // Top face: [d*s, topH] rotated 180 in place
      for (int dy = 0; dy < topH; dy++) {
        for (int dx = 0; dx < w * s; dx++) {
          emoteBody.setPixel(
            (targetDstX + d) * s + dx,
            targetDstY * s + dy,
            body.getPixel(
              (srcDstX + d) * s + (w * s - 1 - dx),
              srcDstY * s + (topH - 1 - dy),
            ),
          );
        }
      }

      // Bottom face: [(d+w)*s, topH] rotated 180 in place
      for (int dy = 0; dy < topH; dy++) {
        for (int dx = 0; dx < w * s; dx++) {
          emoteBody.setPixel(
            (targetDstX + d + w) * s + dx,
            targetDstY * s + dy,
            body.getPixel(
              (srcDstX + d + w) * s + (w * s - 1 - dx),
              srcDstY * s + (topH - 1 - dy),
            ),
          );
        }
      }
    }

    // Body (Torso inner layer)
    flipBox(
      srcDstX: 16,
      srcDstY: 0,
      targetDstX: 16,
      targetDstY: 0,
      w: 8,
      h: 12,
      d: 4,
    );

    // Jacket (Torso outer layer)
    flipBox(
      srcDstX: 16,
      srcDstY: 16,
      targetDstX: 16,
      targetDstY: 16,
      w: 8,
      h: 12,
      d: 4,
    );

    // Arms swap left, right when viewed from 180 deg
    // rightArm (0, 0), leftArm (40, 0)
    flipBox(
      srcDstX: 0,
      srcDstY: 0,
      targetDstX: 40,
      targetDstY: 0,
      w: 4,
      h: 12,
      d: 4,
    );
    flipBox(
      srcDstX: 40,
      srcDstY: 0,
      targetDstX: 0,
      targetDstY: 0,
      w: 4,
      h: 12,
      d: 4,
    );

    // Sleeves swap left, right
    // rightSleeve (0, 16), leftSleeve (40, 16)
    flipBox(
      srcDstX: 0,
      srcDstY: 16,
      targetDstX: 40,
      targetDstY: 16,
      w: 4,
      h: 12,
      d: 4,
    );
    flipBox(
      srcDstX: 40,
      srcDstY: 16,
      targetDstX: 0,
      targetDstY: 16,
      w: 4,
      h: 12,
      d: 4,
    );

    // Legs swap left, right
    // rightLeg (16, 32), leftLeg (32, 32)
    flipBox(
      srcDstX: 16,
      srcDstY: 32,
      targetDstX: 32,
      targetDstY: 32,
      w: 4,
      h: 12,
      d: 4,
    );
    flipBox(
      srcDstX: 32,
      srcDstY: 32,
      targetDstX: 16,
      targetDstY: 32,
      w: 4,
      h: 12,
      d: 4,
    );

    // Pants swap left, right
    // rightPants (0, 32), leftPants (48, 32)
    flipBox(
      srcDstX: 0,
      srcDstY: 32,
      targetDstX: 48,
      targetDstY: 32,
      w: 4,
      h: 12,
      d: 4,
    );
    flipBox(
      srcDstX: 48,
      srcDstY: 32,
      targetDstX: 0,
      targetDstY: 32,
      w: 4,
      h: 12,
      d: 4,
    );

    return PersonaTextures(body: emoteBody, head: emoteHead);
  }

  static bool isSlimSkin(img.Image skin) {
    final int s = skin.width ~/ 64;
    if (s < 1 || skin.height < 64 * s) return false;

    // Check right arm outer columns (54..55)
    bool hasRightPixels = false;
    for (int y = 20 * s; y < 32 * s; y++) {
      for (int x = 54 * s; x < 56 * s; x++) {
        if (skin.getPixel(x, y).a > 0) {
          hasRightPixels = true;
          break;
        }
      }
      if (hasRightPixels) break;
    }

    // Check left arm outer columns (46..47)
    bool hasLeftPixels = false;
    for (int y = 52 * s; y < 64 * s; y++) {
      for (int x = 46 * s; x < 48 * s; x++) {
        if (skin.getPixel(x, y).a > 0) {
          hasLeftPixels = true;
          break;
        }
      }
      if (hasLeftPixels) break;
    }

    return !hasRightPixels && !hasLeftPixels;
  }

  static Uint8List replaceGlbTextures(
    Uint8List glbBytes,
    Uint8List bodyPngBytes,
    Uint8List headPngBytes,
  ) {
    final ByteData bd = ByteData.sublistView(glbBytes);
    final int magic = bd.getUint32(0, Endian.little);
    if (magic != _glbMagic) {
      throw FormatException(
        'Invalid GLB magic header: 0x${magic.toRadixString(16)}',
      );
    }

    // Parse Chunk 0 (JSON)
    final int jsonLen = bd.getUint32(12, Endian.little);
    final int jsonType = bd.getUint32(16, Endian.little);
    if (jsonType != _chunkJson) {
      throw const FormatException('Chunk 0 is not JSON.');
    }

    final String jsonStr = utf8.decode(glbBytes.sublist(20, 20 + jsonLen));
    final Map<String, dynamic> gltf =
        json.decode(jsonStr) as Map<String, dynamic>;

    // Parse Chunk 1 (BIN)
    final int binHeaderOffset = 20 + jsonLen;
    final int binType = bd.getUint32(binHeaderOffset + 4, Endian.little);
    if (binType != _chunkBin) {
      throw const FormatException('Chunk 1 is not BIN.');
    }

    final int binDataStart = binHeaderOffset + 8;

    // Identify image buffer views
    final List<dynamic> images = gltf['images'] as List<dynamic>;
    final int img0BvIdx = images[0]['bufferView'] as int;
    final int img1BvIdx = images[1]['bufferView'] as int;

    final List<dynamic> bufferViews = gltf['bufferViews'] as List<dynamic>;
    final int offset0 = bufferViews[img0BvIdx]['byteOffset'] as int;
    final int offset1 = bufferViews[img1BvIdx]['byteOffset'] as int;
    final int firstImgOffset = offset0 < offset1 ? offset0 : offset1;

    // Retain mesh geometry
    final BytesBuilder newBinBuilder = BytesBuilder();
    newBinBuilder.add(
      Uint8List.sublistView(
        glbBytes,
        binDataStart,
        binDataStart + firstImgOffset,
      ),
    );

    void pad4(BytesBuilder builder) {
      final rem = builder.length % 4;
      if (rem > 0) {
        builder.add(List.filled(4 - rem, 0));
      }
    }

    // Append Image 0 (Body)
    pad4(newBinBuilder);
    final int newOffset0 = newBinBuilder.length;
    newBinBuilder.add(bodyPngBytes);

    // Append Image 1 (Head)
    pad4(newBinBuilder);
    final int newOffset1 = newBinBuilder.length;
    newBinBuilder.add(headPngBytes);

    pad4(newBinBuilder);
    final Uint8List newBinBlob = newBinBuilder.toBytes();

    // Update GLTF JSON structures
    bufferViews[img0BvIdx]['byteOffset'] = newOffset0;
    bufferViews[img0BvIdx]['byteLength'] = bodyPngBytes.length;

    bufferViews[img1BvIdx]['byteOffset'] = newOffset1;
    bufferViews[img1BvIdx]['byteLength'] = headPngBytes.length;

    final List<dynamic> buffers = gltf['buffers'] as List<dynamic>;
    buffers[0]['byteLength'] = newBinBlob.length;

    // Re-encode JSON and pad with spaces (0x20)
    final List<int> newJsonBytes = utf8.encode(json.encode(gltf));
    final int jsonPadding = (4 - (newJsonBytes.length % 4)) % 4;
    final BytesBuilder finalJsonBuilder = BytesBuilder();
    finalJsonBuilder.add(newJsonBytes);
    if (jsonPadding > 0) {
      finalJsonBuilder.add(List.filled(jsonPadding, 0x20));
    }
    final Uint8List paddedJsonBytes = finalJsonBuilder.toBytes();

    // Build final GLB file
    final int totalLength =
        12 + (8 + paddedJsonBytes.length) + (8 + newBinBlob.length);
    final BytesBuilder glbBuilder = BytesBuilder();

    // 12-byte header
    final ByteData headerBd = ByteData(12);
    headerBd.setUint32(0, _glbMagic, Endian.little);
    headerBd.setUint32(4, 2, Endian.little); // version 2
    headerBd.setUint32(8, totalLength, Endian.little);
    glbBuilder.add(headerBd.buffer.asUint8List());

    // Chunk 0 (JSON)
    final ByteData chunk0Bd = ByteData(8);
    chunk0Bd.setUint32(0, paddedJsonBytes.length, Endian.little);
    chunk0Bd.setUint32(4, _chunkJson, Endian.little);
    glbBuilder.add(chunk0Bd.buffer.asUint8List());
    glbBuilder.add(paddedJsonBytes);

    // Chunk 1 (BIN)
    final ByteData chunk1Bd = ByteData(8);
    chunk1Bd.setUint32(0, newBinBlob.length, Endian.little);
    chunk1Bd.setUint32(4, _chunkBin, Endian.little);
    glbBuilder.add(chunk1Bd.buffer.asUint8List());
    glbBuilder.add(newBinBlob);

    return glbBuilder.toBytes();
  }

  /// Extracts embedded image 0 and image 1 raw PNG bytes directly from [glbBytes].
  static PersonaRawTextures extractRawTexturesFromGlb(Uint8List glbBytes) {
    final ByteData bd = ByteData.sublistView(glbBytes);
    final int magic = bd.getUint32(0, Endian.little);
    if (magic != _glbMagic) {
      throw FormatException(
        'Invalid GLB magic header: 0x${magic.toRadixString(16)}',
      );
    }

    final int jsonLen = bd.getUint32(12, Endian.little);
    final String jsonStr = utf8.decode(glbBytes.sublist(20, 20 + jsonLen));
    final Map<String, dynamic> gltf =
        json.decode(jsonStr) as Map<String, dynamic>;

    final int binHeaderOffset = 20 + jsonLen;
    final int binDataStart = binHeaderOffset + 8;

    final bufferViews = gltf['bufferViews'] as List<dynamic>;
    final images = gltf['images'] as List<dynamic>;

    final bv0 =
        bufferViews[images[0]['bufferView'] as int] as Map<String, dynamic>;
    final off0 = binDataStart + ((bv0['byteOffset'] as int?) ?? 0);
    final len0 = bv0['byteLength'] as int;

    final bv1 =
        bufferViews[images[1]['bufferView'] as int] as Map<String, dynamic>;
    final off1 = binDataStart + ((bv1['byteOffset'] as int?) ?? 0);
    final len1 = bv1['byteLength'] as int;

    return PersonaRawTextures(
      body: glbBytes.sublist(off0, off0 + len0),
      head: glbBytes.sublist(off1, off1 + len1),
    );
  }
}
