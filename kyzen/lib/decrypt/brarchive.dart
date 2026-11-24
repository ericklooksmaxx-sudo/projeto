/// BrArchive container format parser
///
/// Binary Layout:
/// - File Header (16 bytes):
///   - Bytes 0-7   (8B): Magic uint64 (0x267052A0B125277D)
///   - Bytes 8-11  (4B): totalFiles uint32
///   - Bytes 12-15 (4B): version int32 (currently 1)
///
/// - Table of Contents (totalFiles * 256 bytes):
///   - Bytes 0-247   (248B): Filename (VarInt length-prefixed / null-terminated UTF-8)
///   - Bytes 248-251 (4B):   dataOffset uint32 (relative to data section start)
///   - Bytes 252-255 (4B):   dataSize uint32 (byte length of entry)
///
/// - Data Section (starts at offset: 16 + totalFiles * 256):
///   - Entry payload slices (encrypted in-place)
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

class BrArchiveEntry {
  final String name;
  final int offset;
  final int size;

  BrArchiveEntry({
    required this.name,
    required this.offset,
    required this.size,
  });

  @override
  String toString() =>
      'BrArchiveEntry(name: $name, offset: $offset, size: $size)';
}

class BrArchive {
  static const int magic = 0x267052A0B125277D;
  static const int currentVersion = 1;
  static const int headerSize = 16;
  static const int entrySize = 256; // 0x100
  static const int filenameFieldSize = 248;

  final List<BrArchiveEntry> entries;
  final int dataOffset;

  BrArchive({required this.entries, required this.dataOffset});

  static BrArchive fromBytes(Uint8List bytes) {
    if (bytes.length < headerSize) {
      throw FormatException(
        'BrArchive: file too small for header (${bytes.length} bytes)',
      );
    }

    final byteData = ByteData.sublistView(bytes);
    final readMagic = byteData.getUint64(0, Endian.little);
    if (readMagic != magic) {
      throw FormatException(
        'BrArchive: Wrong magic number (expected 0x${magic.toRadixString(16)}, got 0x${readMagic.toRadixString(16)})',
      );
    }

    final totalFiles = byteData.getUint32(8, Endian.little);
    final version = byteData.getInt32(12, Endian.little);
    if (version != currentVersion) {
      throw FormatException(
        'BrArchive: Wrong Version Number ($version, expected $currentVersion)',
      );
    }

    final expectedTocSize = headerSize + totalFiles * entrySize;
    if (bytes.length < expectedTocSize) {
      throw FormatException(
        'BrArchive: file too small for TOC ($totalFiles entries, ${bytes.length} bytes)',
      );
    }

    final entries = <BrArchiveEntry>[];
    for (int i = 0; i < totalFiles; i++) {
      final entryOffset = headerSize + i * entrySize;
      final filenameBytes = bytes.sublist(
        entryOffset,
        entryOffset + filenameFieldSize,
      );
      final filename = parseFilename(filenameBytes);

      final offset = byteData.getUint32(
        entryOffset + filenameFieldSize,
        Endian.little,
      );
      final size = byteData.getUint32(
        entryOffset + filenameFieldSize + 4,
        Endian.little,
      );

      entries.add(BrArchiveEntry(name: filename, offset: offset, size: size));
    }

    return BrArchive(entries: entries, dataOffset: expectedTocSize);
  }

  static String parseFilename(Uint8List buffer) {
    if (buffer.isEmpty) return '';

    // standard VarInt / LEB128 length prefix
    int len = 0;
    int shift = 0;
    int pos = 0;
    while (pos < buffer.length) {
      final byte = buffer[pos++];
      len |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift >= 32) break; // Exceeded 32-bit int bounds
    }

    if (len > 0 && pos + len <= buffer.length) {
      try {
        final stringBytes = buffer.sublist(pos, pos + len);
        // Valid length-prefixed strings will not contain null terminators
        if (!stringBytes.contains(0)) {
          final str = utf8.decode(stringBytes);
          if (str.isNotEmpty) {
            return str;
          }
        }
      } catch (_) {}
    }

    // fallback, null-terminated UTF-8 string
    final nullIndex = buffer.indexOf(0);
    final endIndex = (nullIndex != -1) ? nullIndex : buffer.length;
    if (endIndex > 0) {
      try {
        return utf8.decode(buffer.sublist(0, endIndex));
      } catch (_) {
        return utf8.decode(buffer.sublist(0, endIndex), allowMalformed: true);
      }
    }

    return '';
  }

  static String resolveEntryLogicalPath(
    String archiveRelPathInsideBrDir,
    String entryName,
  ) {
    final cleanRelPath = archiveRelPathInsideBrDir.replaceAll('\\', '/');
    final dirPart = p.withoutExtension(cleanRelPath);
    String cleanEntryName = entryName.replaceAll('\\', '/');
    while (cleanEntryName.startsWith('/')) {
      cleanEntryName = cleanEntryName.substring(1);
    }
    if (cleanEntryName.startsWith('$dirPart/')) {
      return cleanEntryName;
    }
    return p.posix.join(dirPart, cleanEntryName);
  }
}
