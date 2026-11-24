# Entitlement Decryption

Extracts decryption keys from local Minecraft Bedrock entitlement files (`.ent`) stored in UWP or GDK directories.

## Decryption and Obfuscation Keys

- **Entitlement XOR Key:** `"X(nG*ejm&E8)m+8c;-SkLTjF)*QdN6_Y"`
- **Ent File Format:** Starts with an 8-byte header `Version2`, followed by base64-encoded encrypted bytes.

## Entitlement Key Derivation Algorithm

To decrypt an `.ent` file:

1. Locates the game directory (e.g. `AppData/Local/Packages/Microsoft.MinecraftUWP_.../LocalState/games/com.mojang/minecraftpe/`).
2. Reads the user's Minecraft options file (`options.txt`) to extract the active account ID: `last_title_account_id:[id]`.
3. Derives a 32-byte AES key:
   ```
   AESKey[i] = TitleAccountId[i % TitleAccountId.length] ^ XORKey[i]
   ```
4. Decrypts the base64 payload. The decrypted content is a JSON structure containing a `receipt` block.
5. Decodes the receipt to retrieve the `DeviceId`, `EntityId`, and an array of `EntitlementReceipts` containing obfuscated content keys.

## Dart Key Derivation Snippet

```dart
static Uint8List _getEntKey(String titleAccountId) {
  final entKey = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    entKey[i] =
        titleAccountId.codeUnitAt(i % titleAccountId.length) ^
        _entXorKey.codeUnitAt(i);
  }
  return entKey;
}
```
