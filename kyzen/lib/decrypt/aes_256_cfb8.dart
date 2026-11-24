import 'dart:async';
import 'dart:isolate';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'brarchive.dart';

enum AesCipherMode {
  cfb8(0),
  ctr(1);

  final int value;
  const AesCipherMode(this.value);
}

// Load dynamic library
final DynamicLibrary _dylib = _loadLibrary();

DynamicLibrary _loadLibrary() {
  if (Platform.isAndroid) return DynamicLibrary.open('libdecrypt.so');
  if (Platform.isWindows) return DynamicLibrary.open('decrypt.dll');
  if (Platform.isLinux) return DynamicLibrary.open('libdecrypt.so');
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

// File operation result struct
final class FileOperationResultNative extends Struct {
  @Int32()
  external int success;
  external Pointer<Utf8> errorMessage;
}

typedef CDecryptFile =
    FileOperationResultNative Function(
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
      Pointer<Utf8> key,
    );

typedef DartDecryptFile =
    FileOperationResultNative Function(
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
      Pointer<Utf8> key,
    );

typedef CDecryptFileEx =
    FileOperationResultNative Function(
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
      Pointer<Utf8> key,
      Int32 cipherMode,
    );

typedef DartDecryptFileEx =
    FileOperationResultNative Function(
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
      Pointer<Utf8> key,
      int cipherMode,
    );

typedef CDecryptBuffer =
    FileOperationResultNative Function(
      Pointer<Uint8> data,
      IntPtr length,
      Pointer<Utf8> key,
    );

typedef DartDecryptBuffer =
    FileOperationResultNative Function(
      Pointer<Uint8> data,
      int length,
      Pointer<Utf8> key,
    );

typedef CDecryptBufferEx =
    FileOperationResultNative Function(
      Pointer<Uint8> data,
      IntPtr length,
      Pointer<Utf8> key,
      Int32 cipherMode,
    );

typedef DartDecryptBufferEx =
    FileOperationResultNative Function(
      Pointer<Uint8> data,
      int length,
      Pointer<Utf8> key,
      int cipherMode,
    );

typedef CFreeFileResult = Void Function(Pointer<FileOperationResultNative>);
typedef DartFreeFileResult = void Function(Pointer<FileOperationResultNative>);

// Load native functions
final DartDecryptFile _decryptFile = _dylib
    .lookup<NativeFunction<CDecryptFile>>('decrypt_file')
    .asFunction();

final DartDecryptFileEx _decryptFileEx =
    _dylib.providesSymbol('decrypt_file_ex')
    ? _dylib
          .lookup<NativeFunction<CDecryptFileEx>>('decrypt_file_ex')
          .asFunction()
    : ((inputPath, outputPath, key, cipherMode) =>
          _decryptFile(inputPath, outputPath, key));

final DartDecryptBuffer _decryptBuffer = _dylib
    .lookup<NativeFunction<CDecryptBuffer>>('decrypt_buffer')
    .asFunction();

final DartDecryptBufferEx _decryptBufferEx =
    _dylib.providesSymbol('decrypt_buffer_ex')
    ? _dylib
          .lookup<NativeFunction<CDecryptBufferEx>>('decrypt_buffer_ex')
          .asFunction()
    : ((data, length, key, cipherMode) => _decryptBuffer(data, length, key));

final DartFreeFileResult _freeFileResult = _dylib
    .lookup<NativeFunction<CFreeFileResult>>('free_file_operation_result')
    .asFunction();

// Function run inside isolate
// isolate is recommended to not cause UI slow down when doing decryption
void _decryptIsolate(SendPort sendPort) {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  port.listen((message) async {
    final map = message as Map<String, dynamic>;
    final SendPort replyPort = map['replyPort'];
    final String operation = map['operation'];

    try {
      if (operation == 'decrypt_file') {
        final String inputPath = map['inputPath'];
        final String outputPath = map['outputPath'];
        final String key = map['key'];
        final int cipherMode = map['cipherMode'] ?? AesCipherMode.cfb8.value;
        final error = await _decryptFileInternal(
          inputPath,
          outputPath,
          key,
          cipherMode,
        );
        replyPort.send({'success': error == null, 'error': error});
      } else if (operation == 'decrypt_bytes') {
        final Uint8List data = map['data'];
        final String key = map['key'];
        final int cipherMode = map['cipherMode'] ?? AesCipherMode.cfb8.value;
        final resultBytes = await _decryptBytesInternal(data, key, cipherMode);
        replyPort.send({'success': true, 'data': resultBytes});
      } else if (operation == 'decrypt_brarchive') {
        final String filePath = map['filePath'];
        final String archiveRelPath = map['archiveRelPath'];
        final Map<String, String> keyMap = Map<String, String>.from(
          map['keyMap'],
        );
        final Map<String, String>? typeMap = map['typeMap'] != null
            ? Map<String, String>.from(map['typeMap'])
            : null;
        final count = await _decryptBrArchiveInternal(
          filePath,
          archiveRelPath,
          keyMap,
          typeMap,
        );
        replyPort.send({'success': true, 'decryptedCount': count});
      }
    } catch (e) {
      replyPort.send({'success': false, 'error': e.toString()});
    }
  });
}

Future<String?> _decryptFileInternal(
  String inputPath,
  String outputPath,
  String key, [
  int cipherMode = 0,
]) async {
  final inputPathPtr = inputPath.toNativeUtf8();
  final outputPathPtr = outputPath.toNativeUtf8();
  final keyPtr = key.toNativeUtf8();

  try {
    final result = _decryptFileEx(
      inputPathPtr,
      outputPathPtr,
      keyPtr,
      cipherMode,
    );

    String? error;
    if (result.success == 0 && result.errorMessage != nullptr) {
      error = result.errorMessage.toDartString();
    }

    final resultPtr = calloc<FileOperationResultNative>();
    resultPtr.ref.success = result.success;
    resultPtr.ref.errorMessage = result.errorMessage;
    _freeFileResult(resultPtr);
    calloc.free(resultPtr);

    return error;
  } catch (e) {
    return 'Exception during decryption: $e';
  } finally {
    calloc.free(inputPathPtr);
    calloc.free(outputPathPtr);
    calloc.free(keyPtr);
  }
}

Future<Uint8List> _decryptBytesInternal(
  Uint8List data,
  String key, [
  int cipherMode = 0,
]) async {
  if (data.isEmpty) return data;
  final keyPtr = key.toNativeUtf8();
  final dataPtr = malloc<Uint8>(data.length);
  final nativeBytes = dataPtr.asTypedList(data.length);
  nativeBytes.setAll(0, data);

  try {
    final result = _decryptBufferEx(dataPtr, data.length, keyPtr, cipherMode);

    if (result.success == 0 && result.errorMessage != nullptr) {
      final error = result.errorMessage.toDartString();
      final resultPtr = calloc<FileOperationResultNative>();
      resultPtr.ref.success = result.success;
      resultPtr.ref.errorMessage = result.errorMessage;
      _freeFileResult(resultPtr);
      calloc.free(resultPtr);
      throw Exception(error);
    }

    return Uint8List.fromList(nativeBytes);
  } finally {
    malloc.free(dataPtr);
    calloc.free(keyPtr);
  }
}

Future<int> _decryptBrArchiveInternal(
  String filePath,
  String archiveRelPath,
  Map<String, String> keyMap, [
  Map<String, String>? typeMap,
]) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('BrArchive file not found: $filePath');
  }

  final bytes = await file.readAsBytes();
  final archive = BrArchive.fromBytes(bytes);

  final keyPtrMap = <String, Pointer<Utf8>>{};
  final matchedEntries =
      <
        ({
          BrArchiveEntry entry,
          String key,
          Pointer<Utf8> keyPtr,
          int cipherMode,
        })
      >[];

  try {
    for (final entry in archive.entries) {
      final logicalPath = BrArchive.resolveEntryLogicalPath(
        archiveRelPath,
        entry.name,
      );
      final key = keyMap[logicalPath] ?? keyMap[logicalPath.toLowerCase()];
      final type = typeMap?[logicalPath] ?? typeMap?[logicalPath.toLowerCase()];
      final cipherMode = (type == 'stream')
          ? AesCipherMode.ctr.value
          : AesCipherMode.cfb8.value;

      if (key != null && key.isNotEmpty && entry.size > 0) {
        final keyPtr = keyPtrMap.putIfAbsent(key, () => key.toNativeUtf8());
        matchedEntries.add((
          entry: entry,
          key: key,
          keyPtr: keyPtr,
          cipherMode: cipherMode,
        ));
      }
    }

    if (matchedEntries.isEmpty) {
      return 0;
    }

    final dataPtr = malloc<Uint8>(bytes.length);
    final nativeBytes = dataPtr.asTypedList(bytes.length);
    nativeBytes.setAll(0, bytes);

    try {
      for (final match in matchedEntries) {
        final offset = archive.dataOffset + match.entry.offset;
        if (offset + match.entry.size <= bytes.length) {
          final entryPtr = dataPtr + offset;
          final result = _decryptBufferEx(
            entryPtr,
            match.entry.size,
            match.keyPtr,
            match.cipherMode,
          );

          if (result.success == 0 && result.errorMessage != nullptr) {
            final error = result.errorMessage.toDartString();
            final resultPtr = calloc<FileOperationResultNative>();
            resultPtr.ref.success = result.success;
            resultPtr.ref.errorMessage = result.errorMessage;
            _freeFileResult(resultPtr);
            calloc.free(resultPtr);
            throw Exception(
              'Failed to decrypt BrArchive entry ${match.entry.name}: $error',
            );
          }
        }
      }

      await file.writeAsBytes(nativeBytes);
      return matchedEntries.length;
    } finally {
      malloc.free(dataPtr);
    }
  } finally {
    for (final ptr in keyPtrMap.values) {
      calloc.free(ptr);
    }
  }
}

// Decrypt Worker Class
class DecryptWorker {
  late Isolate _isolate;
  late SendPort _sendPort;
  final Completer<void> _ready = Completer<void>();
  final ReceivePort _receivePort = ReceivePort();

  DecryptWorker() {
    _init();
  }

  Future<void> _init() async {
    _isolate = await Isolate.spawn(_decryptIsolate, _receivePort.sendPort);
    _sendPort = await _receivePort.first as SendPort;
    _ready.complete();
  }

  Future<void> decryptFile({
    required String inputPath,
    required String outputPath,
    required String key,
    AesCipherMode cipherMode = AesCipherMode.cfb8,
  }) async {
    await _ready.future;
    final responsePort = ReceivePort();
    _sendPort.send({
      'operation': 'decrypt_file',
      'inputPath': inputPath,
      'outputPath': outputPath,
      'key': key,
      'cipherMode': cipherMode.value,
      'replyPort': responsePort.sendPort,
    });
    final response = await responsePort.first as Map<String, dynamic>;
    responsePort.close();
    if (!response['success']) {
      throw Exception(response['error'] ?? 'File decryption failed');
    }
  }

  Future<Uint8List> decryptBytes({
    required Uint8List data,
    required String key,
    AesCipherMode cipherMode = AesCipherMode.cfb8,
  }) async {
    await _ready.future;
    final responsePort = ReceivePort();
    _sendPort.send({
      'operation': 'decrypt_bytes',
      'data': data,
      'key': key,
      'cipherMode': cipherMode.value,
      'replyPort': responsePort.sendPort,
    });
    final response = await responsePort.first as Map<String, dynamic>;
    responsePort.close();
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Byte decryption failed');
    }
    return response['data'] as Uint8List;
  }

  Future<int> decryptBrArchive({
    required String filePath,
    required String archiveRelPath,
    required Map<String, String> keyMap,
    Map<String, String>? typeMap,
  }) async {
    await _ready.future;
    final responsePort = ReceivePort();
    _sendPort.send({
      'operation': 'decrypt_brarchive',
      'filePath': filePath,
      'archiveRelPath': archiveRelPath,
      'keyMap': keyMap,
      'typeMap': typeMap,
      'replyPort': responsePort.sendPort,
    });
    final response = await responsePort.first as Map<String, dynamic>;
    responsePort.close();
    if (!response['success']) {
      throw Exception(response['error'] ?? 'BrArchive decryption failed');
    }
    return (response['decryptedCount'] as int?) ?? 0;
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
    _receivePort.close();
  }
}
