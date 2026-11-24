# XboxAuthService

Authenticates the Microsoft OAuth2 token with Xbox Live services. This includes generating a device token and performing Sisu authentication.

## Proof-of-Possession Request Signing

Xbox Live requires all HTTP requests in the authentication chain to carry a cryptographic signature header: `Signature`. The service signs payloads using the P-256 ECDSA curve.

### Signature Composition

```
Payload = Policy (4 bytes version 1 + null)
        + Timestamp (8 bytes Windows epoch + null)
        + Method (e.g. POST + null)
        + Path/Query (e.g. /device/authenticate + null)
        + Authorization header (empty + null)
        + Body bytes + null
```

This buffer is hashed using **SHA-256** and signed with a locally generated P-256 Elliptic Curve private key. The resulting signature bytes (concatenated R and S values) are encoded with timestamps and policy version, then converted to base64 for the `Signature` header.

## Key API Calls

### `requestXBLToken(OAuth2Token liveToken)` → `Future<XBLToken>`

Performs the full authentication chain:
1. Generates ECDSA P-256 Keypair
2. Obtains Xbox Device Token
3. Requests the final XBL Token from `https://sisu.xboxlive.com/authorize` targeting Relying Party `https://b980a380.minecraft.playfabapi.com/`

## Code Example: ECDSA P-256 Signing

```dart
// Signature Header Construction (using PointyCastle)
final windowsTimestamp = 
  (DateTime.now().toUtc().millisecondsSinceEpoch 
  ~/ 1000 + 11644473600) * 10000000;

final policy = [0, 0, 0, 1, 0];
final tsBytes = ByteData(8)
  ..setUint64(0, windowsTimestamp);

// Hash with SHA-256
final sha256 = SHA256Digest();
final digest = sha256.process(payload);

// Sign with ECDSA and P-256 Private Key
final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
signer.init(true, PrivateKeyParameter(privateKey));
final sig = signer.generateSignature(digest) as ECSignature;
```
