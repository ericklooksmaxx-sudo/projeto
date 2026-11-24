# Decryptor Worker & aes_256_cfb8

Dart FFI client wrapper that maps the native C functions and runs file decryption inside a separate Dart Isolate.

## FFI Struct Mapping

The Dart FFI binding maps the C `FileOperationResult` structure using a subclass of `Struct`:

```dart
final class FileOperationResultNative extends Struct {
  @Int32()
  external int success;
  external Pointer<Utf8> errorMessage;
}
```

## Decryption Isolates

To prevent the main application thread from stuttering or blocking when decrypting large amount of files, `DecryptWorker` initializes a persistent background worker:

- Uses `Isolate.spawn()` to execute the native library calls on a background CPU thread.
- Sends file paths and decryption keys via a `SendPort` and receives results asynchronously on a response `ReceivePort`.
- Frees the native resources after each run by calling `free_file_operation_result`.

## Dart Isolate Implementation

```dart
// Isolate Worker Loop
void _decryptIsolate(SendPort sendPort) {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  port.listen((message) async {
    final map = message as Map;
    final reply = map['replyPort'];
    
    final error = await _decryptFileInternal(
      map['inputPath'], 
      map['outputPath'], 
      map['key']
    );
    reply.send({'success': error == null, 'error': error});
  });
}
```
