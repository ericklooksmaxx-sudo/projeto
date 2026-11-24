# ReceiptProcessor

Processes base64 entitlement receipts, derives unique client user keys, and deobfuscates content keys.

## Key Derivation Formulas

### 1. User Key Derivation

Derives a key by XORing the Unicode UTF-16LE representations of the `DeviceId` and `EntityId`:

```
DeviceBytes = UTF16LE_Encode(DeviceId)
EntityBytes = UTF16LE_Encode(EntityId)

UserKey[i] = DeviceBytes[i] ^ EntityBytes[i]
```

### 2. Content Key Deobfuscation

Obtains the final AES key for the DLC by XORing the obfuscated receipt content key with the user key:

```
ObfuscatedBytes = Base64_Decode(ContentKey)

DeobfuscatedKey[i] = ObfuscatedBytes[i] ^ UserKey[i]
```

## Implementation Code Example

```dart
static List<int> deriveUserKey(String deviceId, String entityId) {
  final deviceBytes = deviceId.encodeUtf16LE();
  final entityBytes = entityId.encodeUtf16LE();
  final length = min(deviceBytes.length, entityBytes.length);

  return List<int>.generate(
    length,
    (i) => deviceBytes[i] ^ entityBytes[i],
  );
}
```
