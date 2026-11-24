import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:kyzen/decrypt/aes_256_cfb8.dart';
import 'package:kyzen/decrypt/brarchive.dart';
import 'package:kyzen/decrypt/dlc_dec.dart';

// flutter test integration_test/files_brarchive_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DecryptWorker worker;

  setUpAll(() {
    worker = Decryptor.instance;
  });

  tearDownAll(() {
  });

  const packPath = 'integration_test/test_brarchive';
  const packKey = 'yH44xGLayNlcn55svY7W39j9m8cDyhmc';

  Future<void> copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      final relative = path.relative(entity.path, from: source.path);
      final destPath = path.join(destination.path, relative);

      if (entity is Directory) {
        await Directory(destPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(path.dirname(destPath)).create(recursive: true);
        await entity.copy(destPath);
      }
    }
  }

  test('decrypt OK', () async {

    final packDir = Directory(packPath);
    if (!packDir.existsSync()) {
      debugPrint('Pack directory not found at $packPath, skipping test.');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp('brarchive_test_');

    try {
      debugPrint('Copying test pack to ${tempDir.path}...');
      await copyDirectory(packDir, tempDir);

      final contentsFiles = await findContentsJsonFiles(tempDir.path);
      expect(contentsFiles.isNotEmpty, true, reason: 'Should find contents.json in pack');


      for (final contentsPath in contentsFiles) {
        debugPrint('Decrypting contents.json at $contentsPath...');
        final decryptedTempPath = '$contentsPath.decrypted.json';

        await worker.decryptFile(
          inputPath: contentsPath,
          outputPath: decryptedTempPath,
          key: packKey,
        );

        final decryptedJsonString = await File(decryptedTempPath).readAsString();
        expect(() => jsonDecode(decryptedJsonString), returnsNormally);

        debugPrint('Processing decrypted contents and BrArchives for ${path.dirname(contentsPath)}...');
        await processDecryptedContentsJson(
          decryptedJsonString,
          contentsPath,
        );
      }

      final brFiles = <File>[];
      await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.brarchive')) {
          brFiles.add(entity);
        }
      }

      expect(brFiles.isNotEmpty, true, reason: 'Pack should contain .brarchive files to verify');

      int verifiedEntries = 0;

      for (final brFile in brFiles) {
        final bytes = await brFile.readAsBytes();
        final archive = BrArchive.fromBytes(bytes);

        for (final entry in archive.entries) {
          if (entry.size == 0) continue;

          final offset = archive.dataOffset + entry.offset;
          final entryBytes = Uint8List.view(
            bytes.buffer,
            bytes.offsetInBytes + offset,
            entry.size,
          );

          final nameLower = entry.name.toLowerCase();

          if (nameLower.endsWith('.json') ||
              nameLower.endsWith('.item.json') ||
              nameLower.endsWith('.geo.json') ||
              nameLower.endsWith('.material') ||
              nameLower.endsWith('.lang')) {
            // Verify valid decrypted JSON/text
            try {
              if (nameLower.endsWith('.lang')) {
                utf8.decode(entryBytes);
              } else {
                final jsonStr = utf8.decode(entryBytes);
                jsonDecode(jsonStr);
              }
              verifiedEntries++;
            } catch (e) {
              fail('Failed to parse decrypted text/JSON in ${entry.name} from ${brFile.path}: $e');
            }
          } else if (nameLower.endsWith('.png')) {
            // Verify PNG header magic: 0x89 'P' 'N' 'G' 0x0D 0x0A 0x1A 0x0A
            if (entryBytes.length >= 8) {
              expect(entryBytes[0], 0x89, reason: 'PNG magic byte 0 for ${entry.name}');
              expect(entryBytes[1], 0x50, reason: 'PNG magic byte 1 for ${entry.name}');
              expect(entryBytes[2], 0x4E, reason: 'PNG magic byte 2 for ${entry.name}');
              expect(entryBytes[3], 0x47, reason: 'PNG magic byte 3 for ${entry.name}');
              verifiedEntries++;
            }
          } else if (nameLower.endsWith('.ogg')) {
            // Verify Ogg header magic: 'O' 'g' 'g' 'S'
            if (entryBytes.length >= 4) {
              expect(entryBytes[0], 0x4F, reason: 'Ogg magic byte 0 for ${entry.name}');
              expect(entryBytes[1], 0x67, reason: 'Ogg magic byte 1 for ${entry.name}');
              expect(entryBytes[2], 0x67, reason: 'Ogg magic byte 2 for ${entry.name}');
              expect(entryBytes[3], 0x53, reason: 'Ogg magic byte 3 for ${entry.name}');
              verifiedEntries++;
            }
          } else if (nameLower.endsWith('.wav')) {
            // Verify WAV header magic: 'R' 'I' 'F' 'F'
            if (entryBytes.length >= 4) {
              expect(entryBytes[0], 0x52, reason: 'WAV magic byte 0 for ${entry.name}');
              expect(entryBytes[1], 0x49, reason: 'WAV magic byte 1 for ${entry.name}');
              expect(entryBytes[2], 0x46, reason: 'WAV magic byte 2 for ${entry.name}');
              expect(entryBytes[3], 0x46, reason: 'WAV magic byte 3 for ${entry.name}');
              verifiedEntries++;
            }
          }

        }
      }

      expect(
        verifiedEntries,
        greaterThan(0),
        reason: 'Should successfully verify decrypted asset',
      );
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('decrypt legacy whole-archive encrypted pack OK', () async {
    const legacyPackPath = 'integration_test/legacy_brarchive_test';
    const legacyKey = 'hQ6AqLjKfufI1u4gAAwHX8qzGyoWOjOB';

    final packDir = Directory(legacyPackPath);
    if (!packDir.existsSync()) {
      debugPrint('Legacy pack directory not found at $legacyPackPath, skipping test.');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp('legacy_brarchive_test_');

    try {
      debugPrint('Copying legacy test pack to ${tempDir.path}...');
      await copyDirectory(packDir, tempDir);

      final contentsFiles = await findContentsJsonFiles(tempDir.path);
      expect(contentsFiles.isNotEmpty, true, reason: 'Should find contents.json in legacy pack');

      for (final contentsPath in contentsFiles) {
        debugPrint('Decrypting contents.json at $contentsPath...');
        final decryptedTempPath = '$contentsPath.decrypted.json';

        await worker.decryptFile(
          inputPath: contentsPath,
          outputPath: decryptedTempPath,
          key: legacyKey,
        );

        final decryptedJsonString = await File(decryptedTempPath).readAsString();
        expect(() => jsonDecode(decryptedJsonString), returnsNormally);

        debugPrint('Processing decrypted contents for ${path.dirname(contentsPath)}...');
        await processDecryptedContentsJson(
          decryptedJsonString,
          contentsPath,
        );
      }

      final brFiles = <File>[];
      await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.brarchive')) {
          brFiles.add(entity);
        }
      }

      expect(brFiles.isNotEmpty, true, reason: 'Legacy pack should contain .brarchive files');

      int verifiedEntries = 0;

      for (final brFile in brFiles) {
        final bytes = await brFile.readAsBytes();
        final archive = BrArchive.fromBytes(bytes);

        for (final entry in archive.entries) {
          if (entry.size == 0) continue;

          final offset = archive.dataOffset + entry.offset;
          final entryBytes = Uint8List.view(
            bytes.buffer,
            bytes.offsetInBytes + offset,
            entry.size,
          );

          final nameLower = entry.name.toLowerCase();

          if (nameLower.endsWith('.json') ||
              nameLower.endsWith('.item.json') ||
              nameLower.endsWith('.geo.json') ||
              nameLower.endsWith('.material') ||
              nameLower.endsWith('.lang')) {
            try {
              if (nameLower.endsWith('.lang')) {
                utf8.decode(entryBytes);
              } else {
                final jsonStr = utf8.decode(entryBytes);
                jsonDecode(jsonStr);
              }
              verifiedEntries++;
            } catch (e) {
              fail('Failed to parse decrypted text/JSON in ${entry.name} from ${brFile.path}: $e');
            }
          } else if (nameLower.endsWith('.png')) {
            if (entryBytes.length >= 8) {
              expect(entryBytes[0], 0x89, reason: 'PNG magic byte 0 for ${entry.name}');
              expect(entryBytes[1], 0x50, reason: 'PNG magic byte 1 for ${entry.name}');
              expect(entryBytes[2], 0x4E, reason: 'PNG magic byte 2 for ${entry.name}');
              expect(entryBytes[3], 0x47, reason: 'PNG magic byte 3 for ${entry.name}');
              verifiedEntries++;
            }
          } else if (nameLower.endsWith('.ogg')) {
            if (entryBytes.length >= 4) {
              expect(entryBytes[0], 0x4F, reason: 'Ogg magic byte 0 for ${entry.name}');
              expect(entryBytes[1], 0x67, reason: 'Ogg magic byte 1 for ${entry.name}');
              expect(entryBytes[2], 0x67, reason: 'Ogg magic byte 2 for ${entry.name}');
              expect(entryBytes[3], 0x53, reason: 'Ogg magic byte 3 for ${entry.name}');
              verifiedEntries++;
            }
          } else if (nameLower.endsWith('.wav')) {
            if (entryBytes.length >= 4) {
              expect(entryBytes[0], 0x52, reason: 'WAV magic byte 0 for ${entry.name}');
              expect(entryBytes[1], 0x49, reason: 'WAV magic byte 1 for ${entry.name}');
              expect(entryBytes[2], 0x46, reason: 'WAV magic byte 2 for ${entry.name}');
              expect(entryBytes[3], 0x46, reason: 'WAV magic byte 3 for ${entry.name}');
              verifiedEntries++;
            }
          }
        }
      }

      expect(
        verifiedEntries,
        greaterThan(0),
        reason: 'Should successfully verify decrypted asset legacy',
      );
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

