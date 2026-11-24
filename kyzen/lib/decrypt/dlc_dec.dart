import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart' show debugPrint;
import 'package:path/path.dart' as path;
import 'package:path/path.dart' as p;
import 'aes_256_cfb8.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pool/pool.dart';
import '../services/zip/zip_handler.dart';
import '../services/key_service.dart';
import '../services/download_service.dart';
import '../services/settings_service.dart';

class Decryptor {
  static final DecryptWorker instance = DecryptWorker();

  static void dispose() {
    instance.dispose();
  }
}

class AddonFolderInfo {
  final String path;
  final String type;

  AddonFolderInfo(this.path, this.type);
}

String removeForbiddenChars(String name) {
  // Remove forbidden characters from the name
  final forbiddenChars = [':', '?', '/', '<', '>', '\\', '|', '*', '&'];
  for (var char in forbiddenChars) {
    name = name.replaceAll(char, '');
  }

  // Replace multiple spaces with a single space
  name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

  return name;
}

Future<void> modifySkinJson(String rootDirectory) async {
  final dir = Directory(rootDirectory);

  if (!await dir.exists()) return;

  await for (var entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('skins.json')) {
      try {
        final content = await entity.readAsString();
        final jsonData = json.decode(content);

        if (jsonData is Map && jsonData.containsKey('skins')) {
          final skins = jsonData['skins'];

          if (skins is List) {
            for (var skin in skins) {
              if (skin is Map && skin['type'] == 'paid') {
                skin['type'] = 'free';
              }
            }
          }
        }
        final modifiedContent = jsonEncode(jsonData);
        await entity.writeAsString(modifiedContent);
      } catch (e) {
        debugPrint('Failed to process ${entity.path}: $e');
      }
    }
  }
}

/// Used to bypass the occasional "pack required to be purchased"
/// Generates a deterministic RFC 4122 Version 4 UUID from an input string and salt
/// the same pack/UUID always produces the same UUID this is to ensure when
/// re-importing the same pack is recognizedn by Minecraft as duplicate
String generateDeterministicUuidV4(String input, {String salt = ''}) {
  final normalizedInput = input.trim().toLowerCase();
  final seed = salt.isNotEmpty
      ? 'kyzen:$salt:$normalizedInput'
      : 'kyzen:$normalizedInput';
  final bytes = sha256.convert(utf8.encode(seed)).bytes.sublist(0, 16);

  // Set version to 4: 0100xxxx
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Set variant to RFC 4122: 10xxxxxx (8, 9, a, or b)
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

Future<void> replaceUuidsInManifest(
  String manifestPath, {
  String? originalUuid,
}) async {
  final file = File(manifestPath);
  if (!await file.exists()) {
    debugPrint('Manifest file not found: $manifestPath');
    return;
  }

  try {
    final manifestData = jsonDecode(await file.readAsString());
    if (manifestData is! Map) return;

    final header = manifestData['header'];
    if (header is Map) {
      final oldHeaderUuid = originalUuid ?? header['uuid']?.toString();
      header['uuid'] = generateDeterministicUuidV4(
        oldHeaderUuid ?? const Uuid().v4(),
        salt: 'header',
      );
    }

    // When packs depend on companion packs (eg BP depending on RP in an addon),
    // update the dependency pack UUID so mc links them properly
    if (manifestData.containsKey('dependencies') &&
        manifestData['dependencies'] is List) {
      final dependencies = manifestData['dependencies'] as List;
      for (var dep in dependencies) {
        if (dep is Map &&
            dep['uuid'] != null &&
            dep['uuid'].toString().isNotEmpty) {
          final oldDepUuid = dep['uuid'].toString();
          dep['uuid'] = generateDeterministicUuidV4(oldDepUuid, salt: 'header');
        }
      }
    }

    await file.writeAsString(jsonEncode(manifestData));
  } catch (e) {
    debugPrint('Failed to replace UUID in manifest at $manifestPath: $e');
  }
}

/// This is used mainly for Mashup DLC (eg texture uuid needs to be linked to the rp json of the world template)
/// Updates external pack UUID references in `world_resource_packs.json` and
/// `world_behavior_packs.json` inside a world template dir
Future<void> updateWorldTemplatePackReferences(String worldTemplateDir) async {
  try {
    final resourcePacksFile = File(
      path.join(worldTemplateDir, 'world_resource_packs.json'),
    );
    final behaviorPacksFile = File(
      path.join(worldTemplateDir, 'world_behavior_packs.json'),
    );

    final hasResourcePacks = await resourcePacksFile.exists();
    final hasBehaviorPacks = await behaviorPacksFile.exists();

    if (!hasResourcePacks && !hasBehaviorPacks) {
      return;
    }

    // Gather internal subpack header UUIDs
    final internalUuids = <String>{};
    for (final subDirName in ['behavior_packs', 'resource_packs']) {
      final subDir = Directory(path.join(worldTemplateDir, subDirName));
      if (await subDir.exists()) {
        final directManifest = File(path.join(subDir.path, 'manifest.json'));
        if (await directManifest.exists()) {
          await _extractUuidFromManifest(directManifest, internalUuids);
        }

        await for (final entity in subDir.list(
          recursive: false,
          followLinks: false,
        )) {
          if (entity is Directory) {
            final subManifest = File(path.join(entity.path, 'manifest.json'));
            if (await subManifest.exists()) {
              await _extractUuidFromManifest(subManifest, internalUuids);
            }
          }
        }
      }
    }

    if (hasResourcePacks) {
      await _updateWorldPackFile(resourcePacksFile, internalUuids);
    }

    if (hasBehaviorPacks) {
      await _updateWorldPackFile(behaviorPacksFile, internalUuids);
    }
  } catch (e) {
    debugPrint(
      'Failed to update world template pack references at $worldTemplateDir: $e',
    );
  }
}

Future<void> _extractUuidFromManifest(
  File file,
  Set<String> internalUuids,
) async {
  try {
    final content = await file.readAsString();
    final json = jsonDecode(content);
    final uuid = json['header']?['uuid']?.toString().toLowerCase().trim();
    if (uuid != null && uuid.isNotEmpty) {
      internalUuids.add(uuid);
    }
  } catch (e) {
    debugPrint('Failed to read subpack manifest at ${file.path}: $e');
  }
}

Future<void> _updateWorldPackFile(File file, Set<String> internalUuids) async {
  try {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is List) {
      bool changed = false;
      for (final item in decoded) {
        if (item is Map) {
          final rawId = (item['pack_id'] ?? item['uuid'])?.toString().trim();
          if (rawId != null &&
              rawId.isNotEmpty &&
              !internalUuids.contains(rawId.toLowerCase())) {
            final newId = generateDeterministicUuidV4(rawId, salt: 'header');
            if (item.containsKey('pack_id')) item['pack_id'] = newId;
            if (item.containsKey('uuid')) item['uuid'] = newId;
            changed = true;
          }
        }
      }
      if (changed) {
        await file.writeAsString(jsonEncode(decoded));
      }
    }
  } catch (e) {
    debugPrint('Failed to update world pack file at ${file.path}: $e');
  }
}

Future<Map<String, String?>?> processManifest(String manifestPath) async {
  final file = File(manifestPath);
  if (!await file.exists()) return null;

  try {
    final content = await file.readAsString();
    final dynamic manifestData = jsonDecode(content);

    if (manifestData is! Map) {
      return null;
    }

    final uuid = manifestData['header']?['uuid']?.toString();
    final type = ((manifestData['modules'] as List?)?.firstWhere(
      (mod) => mod is Map && mod['type'] != null,
      orElse: () => null,
    )?['type'])?.toString();

    final productType = manifestData['metadata']?['product_type']?.toString();

    bool modified = false;

    // only mario mashup use platform_lock
    // inside header
    if (manifestData['header'] is Map &&
        (manifestData['header']['platform_locked'] == true ||
            manifestData['header']['platform_locked'] == 'true')) {
      manifestData['header']['platform_locked'] = false;
      modified = true;
    }

    // top-level
    if (manifestData['platform_locked'] == true ||
        manifestData['platform_locked'] == 'true') {
      manifestData['platform_locked'] = false;
      modified = true;
    }

    if (modified) {
      await file.writeAsString(jsonEncode(manifestData));
    }

    return {'uuid': uuid, 'type': type, 'product_type': productType};
  } catch (e) {
    debugPrint('Failed to process manifest at $manifestPath: $e');
    return null;
  }
}

Future<void> _cleanupPack(Directory dir) async {
  if (!await dir.exists()) return;

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      final name = p.basename(entity.path).toLowerCase();
      if (name == 'contents.json' || name == 'signatures.json') {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('Error deleting file ${entity.path}: $e');
        }
      }
    }
  }
}

Future<void> _cleanupPacks(List<Directory> dirs) async {
  for (final dir in dirs) {
    await _cleanupPack(dir);
  }
}

Future<void> _addKeyToLangFile(String folderPath, String key) async {
  final textsDir = Directory(path.join(folderPath, 'texts'));

  if (!await textsDir.exists()) {
    return;
  }

  final langFilePath = path.join(folderPath, 'texts', 'en_US.lang');
  final langFile = File(langFilePath);

  try {
    final base64Key = base64Encode(utf8.encode(key));
    String content = '';
    if (await langFile.exists()) {
      content = await langFile.readAsString();
      if (content.isNotEmpty && !content.endsWith('\n')) {
        content += '\n';
      }
    }

    content += 'contentKey=$base64Key\n';

    await langFile.writeAsString(content);
  } catch (e) {
    debugPrint('Error: $e');
  }
}

Future<String> compressToZip(String folderPath, String zipFileName) async {
  final sourceDir = Directory(folderPath);
  final zipFile = File(zipFileName);

  if (!await sourceDir.exists()) {
    debugPrint('Error: Folder to compress does not exist');
    return zipFileName; // original as fallback
  }

  try {
    await _cleanupPack(sourceDir);
    final actualPath = await ZipHandler.createFromDirectory(
      sourceDir: sourceDir,
      zipFile: zipFile,
    );
    return actualPath;
  } catch (e) {
    debugPrint('Error compressing folder: $e');
    rethrow;
  }
}

Future<List<Directory>> _renameAddonFolders(
  List<AddonFolderInfo> addonInfos,
  String baseName,
) async {
  final renamedDirectories = <Directory>[];

  for (final addonInfo in addonInfos) {
    final packDir = Directory(addonInfo.path);

    String suffix = '';
    if (addonInfo.type == 'data') {
      suffix = ' BP';
    } else if (addonInfo.type == 'resources') {
      suffix = ' RP';
    }

    final parentDir = packDir.parent;
    final newDirName = '$baseName$suffix';
    final newDirPath = path.join(parentDir.path, newDirName);

    if (packDir.path != newDirPath) {
      final newDir = await packDir.rename(newDirPath);
      renamedDirectories.add(newDir);
    } else {
      renamedDirectories.add(packDir);
    }
  }

  return renamedDirectories;
}

Future<String> compressAddonsZip({
  required List<AddonFolderInfo> addonInfos,
  required File outputMcAddonFile,
  required String baseName,
}) async {
  if (addonInfos.isEmpty) {
    throw ArgumentError('No addon folders provided.');
  }

  try {
    final renamedDirectories = await _renameAddonFolders(addonInfos, baseName);

    await _cleanupPacks(renamedDirectories);
    final actualPath = await ZipHandler.createFromMultipleDirectories(
      sourceDirs: renamedDirectories,
      zipFile: outputMcAddonFile,
    );
    return actualPath;
  } catch (e) {
    debugPrint('Error compressing addons: $e');
    rethrow;
  }
}

Future<void> modifyLevelDatFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    debugPrint('Error: $filePath does not exist.');
    return;
  }

  Uint8List fileData = await file.readAsBytes();
  final pridSearch = utf8.encode('prid');
  final priaReplacement = utf8.encode('pria');
  _replaceBytesInPlace(fileData, pridSearch, priaReplacement);

  // Set MinimumCompatibleClientVersion elements to 0
  // mario mashup use minclientversion set to 1.26.60 which is still not released (only on preview)
  // downgrade so it can be loaded on any mc version
  _zeroIntListTag(fileData, 'MinimumCompatibleClientVersion');

  await file.writeAsBytes(fileData);
}

void _zeroIntListTag(Uint8List data, String tagName) {
  final nameBytes = utf8.encode(tagName);
  final nameLen = nameBytes.length;
  final searchBytes = <int>[
    0x09, // TAG_List
    nameLen & 0xFF,
    (nameLen >> 8) & 0xFF,
    ...nameBytes,
    0x03, // TAG_Int element type
  ];

  int offset = _findBytes(data, searchBytes, 0);
  while (offset != -1) {
    final countOffset = offset + searchBytes.length;
    if (countOffset + 4 <= data.length) {
      final count =
          data[countOffset] |
          (data[countOffset + 1] << 8) |
          (data[countOffset + 2] << 16) |
          (data[countOffset + 3] << 24);

      final elementsOffset = countOffset + 4;
      final elementsEnd = elementsOffset + (count * 4);
      if (elementsEnd <= data.length) {
        data.fillRange(elementsOffset, elementsEnd, 0);
      }
    }
    offset = _findBytes(data, searchBytes, countOffset + 4);
  }
}

void _replaceBytesInPlace(
  Uint8List data,
  List<int> searchBytes,
  List<int> replacementBytes,
) {
  assert(searchBytes.length == replacementBytes.length);
  int offset = _findBytes(data, searchBytes, 0);
  while (offset != -1) {
    data.setRange(offset, offset + replacementBytes.length, replacementBytes);
    offset = _findBytes(data, searchBytes, offset + replacementBytes.length);
  }
}

int _findBytes(Uint8List data, List<int> searchBytes, int start) {
  if (searchBytes.isEmpty) return -1;
  final searchLen = searchBytes.length;
  final maxStart = data.length - searchLen;
  for (int i = start; i <= maxStart; i++) {
    bool match = true;
    for (int j = 0; j < searchLen; j++) {
      if (data[i + j] != searchBytes[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1; // Not found
}

Future<void> decryptDbFolder(String dbFolderPath, String key) async {
  final dir = Directory(dbFolderPath);
  await for (var entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      // Skip empty files and files in "lost" folder
      if (await entity.length() == 0 || entity.path.contains('lost')) continue;

      try {
        await decryptFileWithKey(entity.path, key);
      } catch (e) {
        debugPrint('Error decrypting DB file ${entity.path}: $e');
      }
    }
  }
}

Future<String> compressPackBasedOnType(
  String folderPath,
  String dlcPackName,
  String outputDir,
  String key,
  String manifestPath, {
  String? type,
  String? variantLabel,
  productType,
  String? originalUuid,
}) async {
  final levelDatPath = '$folderPath/level.dat';
  String baseName;
  String extension;
  final suffix = (variantLabel != null && variantLabel.isNotEmpty)
      ? '_$variantLabel'
      : '';

  if (await File(levelDatPath).exists()) {
    // world_template
    await modifyLevelDatFile(levelDatPath);

    // Decrypt DB
    final dbFolderPath = path.join(folderPath, 'db');
    if (await Directory(dbFolderPath).exists()) {
      await decryptDbFolder(dbFolderPath, key);
    }

    // Update external pack UUID references in world_resource_packs.json / world_behavior_packs.json
    await updateWorldTemplatePackReferences(folderPath);

    baseName = '$outputDir/$dlcPackName (world_template$suffix)';
    extension = '.mctemplate';
  } else {
    if (type == 'skin_pack') {
      // Modify skins.json
      await modifySkinJson(folderPath);

      baseName = '$outputDir/$dlcPackName (skin_pack$suffix)';
      extension = '.mcpack';
    } else if (type == 'persona_piece') {
      baseName = '$outputDir/$dlcPackName (persona$suffix)';
      extension = '.zip';
    } else if (productType == 'addon') {
      baseName = '$outputDir/$dlcPackName (addon$suffix)';
      extension = '.mcaddon';
    } else {
      baseName = '$outputDir/$dlcPackName (resources$suffix)';
      extension = '.mcpack';
    }
  }

  /// bypass the "plz buy dlc"
  await replaceUuidsInManifest(manifestPath, originalUuid: originalUuid);

  final zipFileName = '$baseName$extension';
  final actualPath = await compressToZip(folderPath, zipFileName);
  debugPrint('Pack successfully compressed as: $actualPath');
  return actualPath;
}

Future<List<String>> extractZip(String zipFilePath, String outputDir) async {
  final zipFile = File(zipFilePath);
  final destinationDir = Directory(outputDir);
  final List<String> validExtractedDirs = [];

  try {
    await ZipHandler.extractToDirectory(
      zipFile: zipFile,
      destinationDir: destinationDir,
    );
    // Process extracted files
    final extractedFiles = await destinationDir.list(recursive: true).toList();
    final originalZipName = p.basename(zipFilePath);

    // First handle nested zip files
    for (final fileEntity in extractedFiles) {
      if (fileEntity is File &&
          p.extension(fileEntity.path).toLowerCase() == '.zip') {
        final file = fileEntity;

        // Skip the original outer zip file
        if (p.basename(file.path) == originalZipName) {
          continue;
        }

        final nestedOutputDir = p.join(
          outputDir,
          p.basenameWithoutExtension(file.path),
        );
        final nestedDestinationDir = Directory(nestedOutputDir);

        try {
          await ZipHandler.extractToDirectory(
            zipFile: file,
            destinationDir: nestedDestinationDir,
          );
          // Check if this directory has a manifest before adding it
          if (await _hasManifest(nestedOutputDir)) {
            validExtractedDirs.add(nestedOutputDir);
          }
        } catch (e) {
          debugPrint('Error extracting nested zip ${file.path}: $e');
        }
      }
    }

    // Then check the root directory for valid content
    if (await _hasManifest(outputDir)) {
      validExtractedDirs.add(outputDir);
    }
  } catch (e) {
    debugPrint('Error extracting main zip: $e');
    rethrow;
  }

  return validExtractedDirs;
}

Future<bool> _hasManifest(String dirPath) async {
  final manifestPath = p.join(dirPath, 'manifest.json');
  final manifestFile = File(manifestPath);
  if (await manifestFile.exists()) {
    try {
      final content = await manifestFile.readAsString();
      final json = jsonDecode(content);
      return json['header']?['uuid'] != null || json['uuid'] != null;
    } catch (e) {
      debugPrint('Error checking manifest at $manifestPath: $e');
      return false;
    }
  }
  return false;
}

// Decrypts file (contents.json and .db files header are automatically skipped)
Future<void> decryptFileWithKey(
  String filePath,
  String key, {
  AesCipherMode cipherMode = AesCipherMode.cfb8,
}) async {
  try {
    await Decryptor.instance.decryptFile(
      inputPath: filePath,
      outputPath: filePath, // Decrypt in-place
      key: key,
      cipherMode: cipherMode,
    );
  } catch (e) {
    debugPrint('Error decrypting file $filePath: $e');
    rethrow;
  }
}

// Finds all contents.json files in a directory and its subdirectories
Future<List<String>> findContentsJsonFiles(String rootDirectory) async {
  List<String> contentsJsonFiles = [];
  final dir = Directory(rootDirectory);

  // Traverse the directory and find all contents.json files
  await for (var entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('contents.json')) {
      contentsJsonFiles.add(entity.path);
    }
  }
  return contentsJsonFiles;
}

Future<int> determineOptimalPoolSize() async {
  // Default fallback values
  int poolSize = 4; // Reasonable default for most modern devices
  final deviceInfo = DeviceInfoPlugin();

  try {
    final cores = Platform.numberOfProcessors;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;

      // Base pool size on processor cores
      poolSize = cores;

      // Adjust based on device characteristics
      if (androidInfo.isLowRamDevice) {
        // Low RAM devices get reduced concurrency
        poolSize = (poolSize * 0.5).ceil().clamp(2, 3);
      } else {
        // Heuristic for higher-end devices
        if (androidInfo.version.sdkInt >= 23) {
          // Marshmallow+
          // Newer devices can handle more threads
          poolSize = poolSize.clamp(3, 6);
        }
      }

      // Special cases for known problematic chipsets
      final hardware = androidInfo.hardware.toLowerCase();
      if (hardware.contains("mt6") || // Mediatek
          hardware.contains("kirin")) {
        // Huawei
        poolSize = poolSize.clamp(2, 4);
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      poolSize = cores;
      // Use 50% of cores
      poolSize = (cores * 0.5).ceil().clamp(4, 12);
    }
  } catch (e) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      poolSize = Platform.numberOfProcessors.clamp(4, 8);
    } else {
      poolSize = 4; // Mobile fallback
    }
  }

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return poolSize.clamp(4, 16); // Desktop: higher limits
  } else {
    return poolSize.clamp(2, 8); // Mobile: conservative limits
  }
}

// Processes decrypted `contents.json` and decrypts the listed files and BrArchives
Future<void> processDecryptedContentsJson(
  String jsonData,
  String contentsJsonPath, {
  void Function(double progress)? onProgress,
}) async {
  final decoded = jsonDecode(jsonData);
  final contentItems = decoded['content'] as List<dynamic>;
  final contentsDir = path.dirname(contentsJsonPath);

  // Build key map and type map for fast lookup
  final Map<String, String> keyMap = {};
  final Map<String, String> typeMap = {};
  for (var item in contentItems) {
    final relPath = (item['path'] as String?)?.replaceAll('\\', '/');
    final key = item['key'] as String?;
    final type = item['type'] as String?;
    if (relPath != null && key != null && key.isNotEmpty) {
      keyMap[relPath] = key;
      keyMap[relPath.toLowerCase()] = key;
      if (type != null) {
        typeMap[relPath] = type;
        typeMap[relPath.toLowerCase()] = type;
      }
    }
  }

  // Scan for __brarchive directory
  final brArchiveDir = Directory(path.join(contentsDir, '__brarchive'));
  final brArchiveFiles = <({File file, String relPath})>[];
  if (await brArchiveDir.exists()) {
    await for (final entity in brArchiveDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.toLowerCase().endsWith('.brarchive')) {
        final archiveRelPath = path.relative(
          entity.path,
          from: brArchiveDir.path,
        );
        brArchiveFiles.add((file: entity, relPath: archiveRelPath));
      }
    }
  }

  // Determine optimal pool size for the current device
  final poolSize = await determineOptimalPoolSize();
  final pool = Pool(poolSize);

  // Track progress
  int completed = 0;
  final total = contentItems.length + brArchiveFiles.length;
  void updateProgress() {
    final progress = total > 0 ? completed / total : 1.0;
    onProgress?.call(progress);
  }

  // Process files in parallel with optimal concurrency
  final decryptionTasks = <Future>[];

  for (var item in contentItems) {
    final relativePath = item['path'] as String?;
    final key = item['key'] as String?;
    final type = item['type'] as String?;

    if (key != null && relativePath != null && key.isNotEmpty) {
      final filePath = path.join(contentsDir, relativePath);
      final file = File(filePath);
      final cipherMode = (type == 'stream')
          ? AesCipherMode.ctr
          : AesCipherMode.cfb8;

      decryptionTasks.add(
        pool.withResource(() async {
          try {
            if (await file.exists()) {
              await decryptFileWithKey(filePath, key, cipherMode: cipherMode);
            }
          } catch (e) {
            debugPrint('Error decrypting $relativePath: $e');
            rethrow;
          } finally {
            completed++;
            updateProgress();
          }
        }),
      );
    } else {
      completed++;
      updateProgress();
    }
  }

  // BrArchive files
  for (final br in brArchiveFiles) {
    // Check if the entire .brarchive file was already listed in contents.json as a loose encrypted file (mainly used for older brarchive format)
    final relNorm = br.relPath.replaceAll('\\', '/');
    final containerPath1 = '__brarchive/$relNorm';
    final wasWholeArchiveEncrypted =
        (keyMap[containerPath1] != null &&
            keyMap[containerPath1]!.isNotEmpty) ||
        (keyMap[containerPath1.toLowerCase()] != null &&
            keyMap[containerPath1.toLowerCase()]!.isNotEmpty) ||
        (keyMap[relNorm] != null && keyMap[relNorm]!.isNotEmpty) ||
        (keyMap[relNorm.toLowerCase()] != null &&
            keyMap[relNorm.toLowerCase()]!.isNotEmpty);

    if (wasWholeArchiveEncrypted) {
      // The entire .brarchive file was already decrypted as a single whole file
      // skipping decrypting internal entries (if not skipped, they would double-decrypt and get corrupted).
      completed++;
      updateProgress();
      continue;
    }

    decryptionTasks.add(
      pool.withResource(() async {
        try {
          await Decryptor.instance.decryptBrArchive(
            filePath: br.file.path,
            archiveRelPath: br.relPath,
            keyMap: keyMap,
            typeMap: typeMap,
          );
        } catch (e) {
          debugPrint('Error decrypting BrArchive ${br.relPath}: $e');
          rethrow;
        } finally {
          completed++;
          updateProgress();
        }
      }),
    );
  }

  try {
    // Wait for all decryptions to complete
    await Future.wait(decryptionTasks);
  } finally {
    await pool.close();
  }
}

Future<List<String>> processDlc(
  String zipFilePath,
  String tempDirPath, {
  required String itemTitle,
  String? variantLabel,
  required Function(double progress, String message) onProgress,
  required ProcessDlcStrings strings,
}) async {
  final String outputFolder;
  try {
    outputFolder = await SettingsService.instance.getDownloadPath();
  } catch (e) {
    debugPrint('Failed to get Downloads folder: $e');
    return [];
  }

  final List<AddonFolderInfo> addonFolders = [];
  String? addonName;
  final List<String> outputPaths = [];

  final keysService = KeysService.instance;

  try {
    await keysService.loadKeys();
    if (!keysService.isInitialized) {
      debugPrint('Failed to initialize keys service');
      return [];
    }
  } catch (e) {
    debugPrint('Failed to load keys: $e');
    return [];
  }

  try {
    final tempDir = Directory(tempDirPath);
    onProgress(0.0, strings.extractingZipFile);
    final nestedFolders = await extractZip(zipFilePath, tempDir.path);

    if (nestedFolders.isEmpty) {
      throw Exception('No valid addon folders found in zip.');
    }

    double progress = 0.2;
    final progressIncrement = 0.6 / nestedFolders.length;

    for (final nestedDir in nestedFolders) {
      final manifestPath = path.join(nestedDir, 'manifest.json');
      final manifestInfo = await processManifest(manifestPath);

      if (manifestInfo == null || manifestInfo['uuid'] == null) {
        debugPrint('Skipping directory $nestedDir - no valid manifest found');
        continue;
      }

      final uuid = manifestInfo['uuid']!;
      final type = manifestInfo['type'] ?? 'unknown';
      final productType = manifestInfo['product_type'] ?? 'unknown';

      String? key;

      if (type == 'skin_pack' || type == 'persona_piece') {
        key = 's5s5ejuDru4uchuF2drUFuthaspAbepE';
      } else {
        key = await keysService.getKeyForUuid(uuid);
        if (key == null) {
          debugPrint('Error: Decryption key not found for UUID: $uuid');
          continue;
        }
      }

      onProgress(
        progress + (progressIncrement * 0.5),
        strings.decryptingContents,
      );
      final contentsJsonPaths = await findContentsJsonFiles(nestedDir);

      for (final contentsFilePath in contentsJsonPaths) {
        try {
          await decryptFileWithKey(contentsFilePath, key);
          final decryptedContent = await File(contentsFilePath).readAsBytes();
          await processDecryptedContentsJson(
            utf8.decode(decryptedContent),
            contentsFilePath,
          );
        } catch (e) {
          debugPrint('Error processing $contentsFilePath: $e');
          throw Exception('Error processing $contentsFilePath: $e');
        }
      }

      final dlcPackName = removeForbiddenChars(itemTitle);

      if (productType == 'addon') {
        addonFolders.add(AddonFolderInfo(nestedDir, type));
        addonName ??= dlcPackName;
        await _addKeyToLangFile(nestedDir, key);
        await replaceUuidsInManifest(manifestPath, originalUuid: uuid);
      } else {
        onProgress(
          progress + (progressIncrement * 0.7),
          strings.compressingPack,
        );

        if (type != 'persona_piece' && type != 'skin_pack') {
          await _addKeyToLangFile(nestedDir, key);
        }

        final outPath = await compressPackBasedOnType(
          nestedDir,
          dlcPackName,
          outputFolder,
          key,
          manifestPath,
          type: type,
          productType: productType,
          variantLabel: variantLabel,
          originalUuid: uuid,
        );
        outputPaths.add(outPath);
      }

      progress += progressIncrement;
    }

    if (addonFolders.isNotEmpty && addonName != null) {
      final suffix = (variantLabel != null && variantLabel.isNotEmpty)
          ? '_$variantLabel'
          : '';
      final combinedAddonPath =
          '$outputFolder/$addonName (addon$suffix).mcaddon';
      final actualAddonPath = await compressAddonsZip(
        addonInfos: addonFolders,
        outputMcAddonFile: File(combinedAddonPath),
        baseName: addonName,
      );
      outputPaths.add(actualAddonPath);
      debugPrint('Addon: $actualAddonPath');
    }

    onProgress(1.0, strings.cleaningUp);
    return outputPaths;
  } catch (e) {
    debugPrint('An error occurred: $e');
    rethrow;
  }
}
