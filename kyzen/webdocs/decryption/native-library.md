# openssl/decrypt.c (Native Library)

This native C library utilizes OpenSSL EVP APIs to get good performance. To get further decent speed and minimize FFI overhead, Kyzen does not pass the actual data between Dart and C, but rather just the file paths.

## Decryption Cipher Details

The implementation supports two cipher modes:
1. **AES-256-CFB8** (`cipher_mode = 0`, default): . The 16-byte IV is derived directly from the decryption key itself (first 16 bytes of the 32-byte key).
2. **AES-CTR** (`cipher_mode = 1`): Used for files marked with `"type": "stream"` in `contents.json` (such as audio/music `.ogg` files).

## C Functions Exposed via FFI

### `decrypt_file_ex(const char* input_path, const char* output_path, const char* key_str, int cipher_mode)` → `FileOperationResult`

Decrypts an encrypted file in a specified path using the provided AES key and cipher mode (`0` = CFB8, `1` = CTR). `decrypt_file(...)` is retained as a backwards-compatible wrapper defaulting to CFB8.

### `decrypt_buffer_ex(unsigned char* data, size_t length, const char* key_str, int cipher_mode)` → `FileOperationResult`

Decrypts an in-memory byte buffer in-place using the specified cipher mode. Used for decrypting packed entries inside `.brarchive` container files. `decrypt_buffer(...)` is retained as a backwards-compatible wrapper defaulting to CFB8.

**Special Operations:**

- **Windows Unicode Path Handling:** Path strings are converted from UTF-8 to UTF-16 wide strings using `MultiByteToWideChar`, then opened using wide-character file descriptors (`_wfopen`) to support system paths with special characters.
- **File Header Skip:** Checks the first 8 bytes of the file. If the first 4 bytes equal `0` and the second 4 bytes match magic `0x9BCFB9FC`, it skips the first 256 bytes (`0x100` header block) and decrypts only the remaining payload. (header is generally found on files like contents.json, or db files.)
- **Null-Terminator Key Safety:** Accepts both 32-character string keys and 64-character hexadecimal keys (which are parsed into 32-byte arrays via `hex_to_bytes`). Using hex keys prevents zero-byte values (`\x00`) inside the key from being truncated as C null-string terminators. (hex keys primarily used for `.ent` files)
- **BrArchive Container Handling:** Modern Minecraft Bedrock packs store assets in `__brarchive/*.brarchive` files. Each entry in the archive TOC has its payload decrypted in-place using `decrypt_buffer_ex` according to its declared type.

## C Function Signatures

```c
// C Struct for FFI return
typedef struct {
    int success;        // 1 = ok, 0 = fail
    char* error_message; // malloc'd string
} FileOperationResult;

// Native signatures
FileOperationResult decrypt_file_ex(
    const char* input_path,
    const char* output_path,
    const char* key_str,
    int cipher_mode
);

FileOperationResult decrypt_file(
    const char* input_path,
    const char* output_path,
    const char* key_str
);

FileOperationResult decrypt_buffer_ex(
    unsigned char* data,
    size_t length,
    const char* key_str,
    int cipher_mode
);

FileOperationResult decrypt_buffer(
    unsigned char* data,
    size_t length,
    const char* key_str
);
```
