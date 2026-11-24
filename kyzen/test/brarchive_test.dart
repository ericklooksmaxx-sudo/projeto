import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyzen/decrypt/brarchive.dart';

Uint8List createMockBrArchiveBytes({
  int magic = BrArchive.magic,
  int version = 1,
  required List<({String name, Uint8List data, bool useVarInt})> files,
}) {
  final headerSize = 16;
  final entrySize = 256;
  final totalFiles = files.length;
  final tocSize = headerSize + totalFiles * entrySize;

  // Calculate data offsets
  int currentDataOffset = 0;
  final entriesMeta =
      <({String name, int offset, int size, Uint8List data, bool useVarInt})>[];
  for (final file in files) {
    entriesMeta.add((
      name: file.name,
      offset: currentDataOffset,
      size: file.data.length,
      data: file.data,
      useVarInt: file.useVarInt,
    ));
    currentDataOffset += file.data.length;
  }

  final totalSize = tocSize + currentDataOffset;
  final buffer = Uint8List(totalSize);
  final byteData = ByteData.sublistView(buffer);

  // Write header
  byteData.setUint64(0, magic, Endian.little);
  byteData.setUint32(8, totalFiles, Endian.little);
  byteData.setInt32(12, version, Endian.little);

  // Write TOC
  for (int i = 0; i < totalFiles; i++) {
    final entry = entriesMeta[i];
    final entryOffset = headerSize + i * entrySize;

    // Write filename field (248 bytes)
    final nameBytes = utf8.encode(entry.name);
    if (entry.useVarInt) {
      // VarInt / LEB128 length prefix
      int len = nameBytes.length;
      int varIntPos = entryOffset;
      while (len >= 0x80) {
        buffer[varIntPos++] = (len & 0x7F) | 0x80;
        len >>= 7;
      }
      buffer[varIntPos++] = len & 0x7F;
      buffer.setRange(varIntPos, varIntPos + nameBytes.length, nameBytes);
    } else {
      // null-terminated
      buffer.setRange(entryOffset, entryOffset + nameBytes.length, nameBytes);
      buffer[entryOffset + nameBytes.length] = 0;
    }

    // Offset (4 bytes)
    byteData.setUint32(entryOffset + 248, entry.offset, Endian.little);
    // Size (4 bytes)
    byteData.setUint32(entryOffset + 252, entry.size, Endian.little);

    // Write file payload in data section
    final payloadAbsOffset = tocSize + entry.offset;
    buffer.setRange(
      payloadAbsOffset,
      payloadAbsOffset + entry.size,
      entry.data,
    );
  }

  return buffer;
}

void main() {
  group('BrArchive parsing tests', () {
    test('parses mock BrArchive with VarInt length-prefixed filenames', () {
      final file1Data = Uint8List.fromList(utf8.encode('Hello World 1'));
      final file2Data = Uint8List.fromList(
        utf8.encode('Texture data binary content'),
      );

      final bytes = createMockBrArchiveBytes(
        files: [
          (name: 'entity/zombie.png', data: file1Data, useVarInt: true),
          (name: 'blocks/stone.png', data: file2Data, useVarInt: true),
        ],
      );

      final archive = BrArchive.fromBytes(bytes);
      expect(archive.entries.length, 2);

      expect(archive.entries[0].name, 'entity/zombie.png');
      expect(archive.entries[0].offset, 0);
      expect(archive.entries[0].size, file1Data.length);

      expect(archive.entries[1].name, 'blocks/stone.png');
      expect(archive.entries[1].offset, file1Data.length);
      expect(archive.entries[1].size, file2Data.length);

      expect(archive.dataOffset, 16 + 2 * 256);

      // Verify payload slice
      final slice1 = bytes.sublist(
        archive.dataOffset + archive.entries[0].offset,
        archive.dataOffset +
            archive.entries[0].offset +
            archive.entries[0].size,
      );
      expect(utf8.decode(slice1), 'Hello World 1');
    });

    test('parses mock BrArchive with null-terminated filenames', () {
      final file1Data = Uint8List.fromList([1, 2, 3, 4, 5]);

      final bytes = createMockBrArchiveBytes(
        files: [
          (
            name: 'models/entity/steve.geo.json',
            data: file1Data,
            useVarInt: false,
          ),
        ],
      );

      final archive = BrArchive.fromBytes(bytes);
      expect(archive.entries.length, 1);
      expect(archive.entries[0].name, 'models/entity/steve.geo.json');
      expect(archive.entries[0].size, 5);
    });

    test('throws FormatException on wrong magic number', () {
      final bytes = createMockBrArchiveBytes(
        magic: 0x1234567890ABCDEF,
        files: [(name: 'test.txt', data: Uint8List(0), useVarInt: true)],
      );

      expect(() => BrArchive.fromBytes(bytes), throwsFormatException);
    });

    test('throws FormatException on unsupported version', () {
      final bytes = createMockBrArchiveBytes(
        version: 2,
        files: [(name: 'test.txt', data: Uint8List(0), useVarInt: true)],
      );

      expect(() => BrArchive.fromBytes(bytes), throwsFormatException);
    });

    test('throws FormatException on truncated file', () {
      final truncatedBytes = Uint8List(8);
      expect(() => BrArchive.fromBytes(truncatedBytes), throwsFormatException);
    });
  });

  group('BrArchive path resolution tests', () {
    test('resolves standard single-level archive path', () {
      final resolved = BrArchive.resolveEntryLogicalPath(
        'textures.brarchive',
        'entity/zombie.png',
      );
      expect(resolved, 'textures/entity/zombie.png');
    });

    test('resolves nested archive path', () {
      final resolved = BrArchive.resolveEntryLogicalPath(
        'models/entity.brarchive',
        'zombie.geo.json',
      );
      expect(resolved, 'models/entity/zombie.geo.json');
    });

    test('handles Windows backslashes in paths', () {
      final resolved = BrArchive.resolveEntryLogicalPath(
        'textures\\subfolder\\pack.brarchive',
        'entity\\steve.png',
      );
      expect(resolved, 'textures/subfolder/pack/entity/steve.png');
    });

    test('handles entry name that already includes dir prefix', () {
      final resolved = BrArchive.resolveEntryLogicalPath(
        'textures.brarchive',
        'textures/entity/zombie.png',
      );
      expect(resolved, 'textures/entity/zombie.png');
    });

    test('strips leading slashes in entry name', () {
      final resolved = BrArchive.resolveEntryLogicalPath(
        'sounds.brarchive',
        '/ambient/cave/cave1.fsb',
      );
      expect(resolved, 'sounds/ambient/cave/cave1.fsb');
    });
  });
}
