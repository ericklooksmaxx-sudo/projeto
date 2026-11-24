# Environment Setup

Kyzen injects configuration at build time via Flutter's `--dart-define-from-file` flag. You must create a `.env.json` file in the project root before running or building the app.

## Creating `.env.json`

Add a file named `.env.json` to the root of the project with the following structure:

```json
{
  "KEYS_URL": "<url to the encrypted keys file>",
  "KEYS_DECRYPTION_KEY": "<32-char AES key for the keys file>",
  "SOCIAL_LINKS_URL": "<url to the social links JSON endpoint>",
  "UPLOAD_KEYS_URL": "<url to the key upload endpoint>",
  "ANNOUNCEMENTS_URL": "<url to the announcements JSON endpoint>",
  "UPDATE_URL": "<url to the update info JSON endpoint>"
}
```

## Key Reference

| Key | Type | Used in |
|---|---|---|
| `KEYS_URL` | URL string | `lib/services/key_service.dart` |
| `KEYS_DECRYPTION_KEY` | 32-character AES key | `lib/services/key_service.dart` |
| `SOCIAL_LINKS_URL` | URL string | `lib/services/social_link.dart` |
| `UPLOAD_KEYS_URL` | URL string | `lib/services/upload_keys.dart` |
| `ANNOUNCEMENTS_URL` | URL string | `lib/services/announcements_service.dart` |
| `UPDATE_URL` | URL string | `lib/services/app_update_service.dart` |

## Passing the File to Flutter

Pass the flag explicitly on every `run` or `build` command:

```bash
flutter run --dart-define-from-file=.env.json
flutter build <target> --dart-define-from-file=.env.json
```

## VS Code

The repository ships with a pre-configured `.vscode/launch.json`. Every launch configuration already includes:

```json
"toolArgs": ["--dart-define-from-file=.env.json"]
```

The flag is applied automatically whenever you launch or debug from VS Code.

## FastForge

If you release with [FastForge](/getting-started/fastforge), you don't need to pass the flag manually. Every target in `distribute_options.yaml` already includes:

```yaml
build_args:
  dart-define-from-file: .env.json
```

This covers `release-linux` (AppImage), `release-android` (APK), and `release-windows` (EXE).
