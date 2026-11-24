# KeysService

Responsible for parsing, filtering, and caching decryption keys.

## Remote Key Retrieval

KeysService fetches the keys from a server. The remote host can serve them either as an encrypted binary or as a plaintext TSV file:

- **Plaintext TSV Auto-Detection:** Automatically detects if the downloaded data is unencrypted. If the payload is already plaintext, it skips the decryption step and parses the TSV directly.
- **Secure Build Secrets:** The `KEYS_DECRYPTION_KEY` env variable (a 32-byte AES key) is injected at build time via `--dart-define-from-file=.env.json`. See [Environment Setup](/getting-started/environment-setup).

## Local TSV Mappings

Parses TSV files utilizing tab boundaries (`\t`).

Columns: `MarketUUID`, `ManifestUUID`, `TypePack`, and `Key`.

## TSV Format Example

```
MarketUUID\tManifestUUID\tTypePack\tKey
a2b3c4f5-1234...\t9f8e7d6c-5678...\tworldtemplate\ta5f392b4c6...
```
