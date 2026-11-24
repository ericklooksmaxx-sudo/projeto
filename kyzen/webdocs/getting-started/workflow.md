# Core Workflow

## Steps of the Pipeline

| Phase | Service Invoked | Action Performed |
|---|---|---|
| 1. Search & Get | `PlayFabClient` | Queries PlayFab Catalog using search parameters or a direct item UUID. Retrieves metadata, version, and encrypted download URLs. |
| 2. Download Zip | `DownloadService` | Downloads encrypted catalog zip. Computes MD5 hash to verify file integrity. |
| 3. Extract Zip | `ZipHandler` | Extracts the downloaded encrypted zip files. |
| 4. Decrypt | `KeysService` / `Decryptor` | Locates manifest UUID (manifest.json), retrieves the AES content decryption key from the keys TSV mapping, and decrypts files inside the `db` folder and `contents.json`. |
| 5. File Decryption | `Decryptor` / C library | Spawns isolate pool to decrypt every file listed inside `contents.json` using AES-256-CFB8 decryption. |
| 6. Bypass | `Decryptor` / Helper | Modifies level.dat files, substituting `prid` (premium ID) with `pria`, and unlocks paid skins in `skins.json` by changing type to `free`. |
| 7. Pack DLC | `ZipHandler` | Repackages the decrypted contents (e.g. `.mcpack`, `.mctemplate`, or `.mcaddon`). |

## DLC File Extensions

- **World Templates:** `.mctemplate`
- **Resource Packs / Skin Packs:** `.mcpack`
- **Addon:** `.mcaddon`
- **Persona pieces:** `.zip`
