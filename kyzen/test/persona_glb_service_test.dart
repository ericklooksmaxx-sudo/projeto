import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kyzen/services/persona_glb_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('PersonaGlbService skin validation', () {
    test('Validates 64x64 standard classic skin', () {
      final image = img.Image(width: 64, height: 64, numChannels: 4);
      image.setPixelRgba(54, 25, 255, 0, 0, 255); // Classic arm pixel (column 54)
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final result = PersonaGlbService.validateSkinBytes(pngBytes);
      expect(result.isValid, isTrue);
      expect(result.width, equals(64));
      expect(result.height, equals(64));
    });

    test('Validates 128x128 HD classic skin', () {
      final image = img.Image(width: 128, height: 128, numChannels: 4);
      image.setPixelRgba(54 * 2, 25 * 2, 255, 0, 0, 255); // Classic arm pixel
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final result = PersonaGlbService.validateSkinBytes(pngBytes);
      expect(result.isValid, isTrue);
      expect(result.width, equals(128));
      expect(result.height, equals(128));
    });

    test('Rejects slim (Alex) skin with 3-pixel arms', () {
      final image = img.Image(width: 64, height: 64, numChannels: 4);
      // All arm outer columns (54..55 and 46..47) are transparent -> slim skin
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final result = PersonaGlbService.validateSkinBytes(pngBytes);
      expect(result.isValid, isFalse);
      expect(result.error, contains('Slim (Alex) skins'));
    });

    test('Validates 64x32 legacy skin', () {
      final image = img.Image(width: 64, height: 32, numChannels: 4);
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final result = PersonaGlbService.validateSkinBytes(pngBytes);
      expect(result.isValid, isTrue);
      expect(result.width, equals(64));
      expect(result.height, equals(32));
    });

    test('Rejects invalid dimensions', () {
      final image = img.Image(width: 100, height: 100, numChannels: 4);
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final result = PersonaGlbService.validateSkinBytes(pngBytes);
      expect(result.isValid, isFalse);
      expect(result.error, contains('Unsupported skin dimensions'));
    });

    test('Rejects empty or non-image bytes', () {
      final result1 = PersonaGlbService.validateSkinBytes(Uint8List(0));
      expect(result1.isValid, isFalse);

      final result2 = PersonaGlbService.validateSkinBytes(
        Uint8List.fromList([1, 2, 3, 4, 5]),
      );
      expect(result2.isValid, isFalse);
    });
  });

  group('PersonaGlbService skin slicing and slim conversion', () {
    test('Detects slim skin vs classic skin', () {
      final skinClassic = img.Image(width: 64, height: 64, numChannels: 4);
      skinClassic.setPixelRgba(54, 25, 255, 0, 0, 255);
      expect(PersonaGlbService.isSlimSkin(skinClassic), isFalse);

      final skinSlim = img.Image(width: 64, height: 64, numChannels: 4);
      expect(PersonaGlbService.isSlimSkin(skinSlim), isTrue);
    });

    test('Slices 64x64 skin to 128x128 body and 32x32 head', () {
      final skin = img.Image(width: 64, height: 64, numChannels: 4);
      final textures = PersonaGlbService.skinToPersonaTextures(skin);

      expect(textures.body.width, equals(128));
      expect(textures.body.height, equals(128));
      expect(textures.head.width, equals(32));
      expect(textures.head.height, equals(32));
    });

    test('Slices 64x32 legacy skin into modern persona textures', () {
      final skin = img.Image(width: 64, height: 32, numChannels: 4);
      skin.setPixelRgba(42, 18, 0, 255, 0, 255);

      final textures = PersonaGlbService.skinToPersonaTextures(skin);
      expect(textures.body.width, equals(128));
      expect(textures.body.height, equals(128));
      expect(textures.head.width, equals(32));
      expect(textures.head.height, equals(32));
    });
  });

  group('PersonaGlbService GLB texture injection', () {
    test('Replaces textures and creates a valid 4-byte aligned GLB', () async {
      final glbFile = File('assets/persona.glb');
      expect(glbFile.existsSync(), isTrue);

      final glbBytes = await glbFile.readAsBytes();

      final bodyImg = img.Image(width: 128, height: 128, numChannels: 4);
      bodyImg.setPixelRgba(10, 10, 255, 128, 0, 255);
      final bodyPng = Uint8List.fromList(img.encodePng(bodyImg));

      final headImg = img.Image(width: 32, height: 32, numChannels: 4);
      headImg.setPixelRgba(5, 5, 0, 128, 255, 255);
      final headPng = Uint8List.fromList(img.encodePng(headImg));

      final newGlbBytes = PersonaGlbService.replaceGlbTextures(
        glbBytes,
        bodyPng,
        headPng,
      );

      expect(newGlbBytes.length % 4, equals(0));

      final bd = ByteData.sublistView(newGlbBytes);
      expect(bd.getUint32(0, Endian.little), equals(0x46546C67)); // "glTF"
      expect(bd.getUint32(4, Endian.little), equals(2)); // version 2
      expect(bd.getUint32(8, Endian.little), equals(newGlbBytes.length));

      final jsonLen = bd.getUint32(12, Endian.little);
      expect(jsonLen % 4, equals(0));
      expect(bd.getUint32(16, Endian.little), equals(0x4E4F534A)); // "JSON"

      final jsonStr = utf8.decode(newGlbBytes.sublist(20, 20 + jsonLen));
      final gltf = jsonDecode(jsonStr) as Map<String, dynamic>;

      final binHeaderOffset = 20 + jsonLen;
      final binLen = bd.getUint32(binHeaderOffset, Endian.little);
      expect(binLen % 4, equals(0));
      expect(
        bd.getUint32(binHeaderOffset + 4, Endian.little),
        equals(0x004E4942),
      ); // "BIN"

      final buffers = gltf['buffers'] as List<dynamic>;
      expect(buffers[0]['byteLength'], equals(binLen));

      final extracted = PersonaGlbService.extractRawTexturesFromGlb(
        newGlbBytes,
      );
      expect(extracted.body, equals(bodyPng));
      expect(extracted.head, equals(headPng));
    });

    test('Full applySkinToGlb flow with 64x64 skin', () async {
      final glbFile = File('assets/persona.glb');
      final glbBytes = await glbFile.readAsBytes();

      final dummy = img.Image(width: 64, height: 64, numChannels: 4);
      final skinBytes = Uint8List.fromList(img.encodePng(dummy));

      final resultGlb = PersonaGlbService.applySkinToGlb(glbBytes, skinBytes);
      expect(resultGlb.length % 4, equals(0));

      final extracted = PersonaGlbService.extractRawTexturesFromGlb(resultGlb);
      final decodedBody = img.decodeImage(extracted.body);
      final decodedHead = img.decodeImage(extracted.head);

      expect(decodedBody, isNotNull);
      expect(decodedBody!.width, equals(128));
      expect(decodedBody.height, equals(128));

      expect(decodedHead, isNotNull);
      expect(decodedHead!.width, equals(32));
      expect(decodedHead.height, equals(32));
    });

    test('flipPersonaTexturesForEmote correctly swaps front and back for emote player', () {
      final head = img.Image(width: 32, height: 32, numChannels: 4);
      final body = img.Image(width: 128, height: 128, numChannels: 4);

      // Front face of head is at x = 8..16, y = 8..16
      head.setPixelRgba(12, 12, 255, 0, 0, 255);
      // Back face of head is at x = 24..32, y = 8..16
      head.setPixelRgba(28, 12, 0, 0, 255, 255);

      // Torso front face is at x = 20, y = 8
      body.setPixelRgba(20, 8, 0, 255, 0, 255);
      // Torso back face is at x = 36, y = 8
      body.setPixelRgba(36, 8, 255, 255, 0, 255);
      // Right arm front face
      body.setPixelRgba(2, 8, 100, 100, 100, 255);

      final flipped = PersonaGlbService.flipPersonaTexturesForEmote(
        PersonaTextures(body: body, head: head),
      );

      final pixelAt28 = flipped.head.getPixel(28, 12);
      expect(pixelAt28.r, equals(255));
      expect(pixelAt28.g, equals(0));
      expect(pixelAt28.b, equals(0));

      final pixelAt12 = flipped.head.getPixel(12, 12);
      expect(pixelAt12.r, equals(0));
      expect(pixelAt12.g, equals(0));
      expect(pixelAt12.b, equals(255));

      final pixelAt32 = flipped.body.getPixel(32, 8);
      expect(pixelAt32.g, equals(255));

      final pixelAt24 = flipped.body.getPixel(24, 8);
      expect(pixelAt24.r, equals(255));

      final pixelArm = flipped.body.getPixel(50, 8);
      expect(pixelArm.r, equals(100));
    });

    test('Preserves single-pixel odd coordinate details in 128x128 HD skins without downsampling', () async {
      final glbFile = File('assets/persona.glb');
      final glbBytes = await glbFile.readAsBytes();

      // Create a 128x128 HD skin with single-pixel details at odd coordinates on hat face
      final skin = img.Image(width: 128, height: 128, numChannels: 4);
      // Eye 1 at odd coordinate x=85, y=22
      skin.setPixelRgba(85, 22, 0, 0, 0, 255);
      // Eye 2 at even coordinate x=90, y=22
      skin.setPixelRgba(90, 22, 0, 0, 0, 255);

      final pngBytes = Uint8List.fromList(img.encodePng(skin));
      final resultGlb = PersonaGlbService.applySkinToGlb(glbBytes, pngBytes);

      final extracted = PersonaGlbService.extractRawTexturesFromGlb(resultGlb);
      final decodedHead = img.decodePng(extracted.head)!;
      final decodedBody = img.decodePng(extracted.body)!;

      // Should be HD resolution
      expect(decodedHead.width, equals(64));
      expect(decodedHead.height, equals(64));
      expect(decodedBody.width, equals(256));
      expect(decodedBody.height, equals(256));

      final eye1 = decodedHead.getPixel(21, 54);
      final eye2 = decodedHead.getPixel(26, 54);

      expect(eye1.r, equals(0));
      expect(eye1.a, equals(255));
      expect(eye2.r, equals(0));
      expect(eye2.a, equals(255));
    });

    test('extractHeadAvatarFromHeadTexture correctly composites hat over head face', () {
      final headTex = img.Image(width: 32, height: 32, numChannels: 4);
      // Head base face at (8..15, 8..15) - skin color (255, 200, 150)
      for (int y = 8; y < 16; y++) {
        for (int x = 8; x < 16; x++) {
          headTex.setPixelRgba(x, y, 255, 200, 150, 255);
        }
      }
      // Hat outer layer face at (8..15, 24..31) - mostly transparent, with an eye at (10, 26)
      headTex.setPixelRgba(10, 26, 0, 0, 0, 255);

      final avatar = PersonaGlbService.extractHeadAvatarFromHeadTexture(
        headTex,
        targetSize: 64,
      );
      expect(avatar.width, equals(64));
      expect(avatar.height, equals(64));

      // Pixel corresponding to eye (x: 10, y: 26 -> dx: 2, dy: 2 in 8x8 -> scaled 8x in 64x64)
      final eyePixel = avatar.getPixel(2 * 8 + 4, 2 * 8 + 4);
      expect(eyePixel.r, equals(0));
      expect(eyePixel.g, equals(0));
      expect(eyePixel.b, equals(0));

      // Pixel corresponding to skin (x: 8, y: 8 -> dx: 0, dy: 0 in 8x8)
      final skinPixel = avatar.getPixel(0, 0);
      expect(skinPixel.r, equals(255));
      expect(skinPixel.g, equals(200));
      expect(skinPixel.b, equals(150));
    });

    test('assets/persona_head.png exists and is a valid 64x64 PNG', () async {
      final outFile = File('assets/persona_head.png');
      expect(outFile.existsSync(), isTrue);
      final bytes = await outFile.readAsBytes();
      final decoded = img.decodePng(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(64));
      expect(decoded.height, equals(64));
    });

    test('getCustomHeadFile points to custom_head.png in kyzen directory', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return 'C:\\Users\\utentee\\Documents';
        },
      );
      final headFile = await PersonaGlbService.instance.getCustomHeadFile();
      expect(headFile.path.replaceAll('\\', '/'), endsWith('kyzen/custom_head.png'));
    });
  });
}
