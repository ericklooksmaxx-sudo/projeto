# AppUpdateService

Handles checking for app updates.

## Environment Variable

| Variable | Description |
|---|---|
| `UPDATE_URL` | The endpoint URL to `GET` update metadata from. Must be provided at build time via `--dart-define-from-file=.env.json`. |

## Platform Keys

| Platform Key | Target System |
|---|---|
| `android` | Android (APK) |
| `linux` | Linux (AppImage) |
| `windows` | Windows x86_64 |
| `windows_arm64` | Windows ARM64 |

## Data Models

### `UpdateInfo`

| Field | Type | Description |
|---|---|---|
| `latestVersion` | `String` | Version string of the latest available release (e.g. `"1.5.0"`). |
| `changelog` | `String` | Change log |
| `platforms` | `Map<String, PlatformDownload>` | Map of platform keys to platform-specific download metadata. |

### `PlatformDownload`

| Field | Type | Description |
|---|---|---|
| `downloadUrl` | `String` | URL of the binary. |
| `isDirectDownload` | `bool` | Indicates whether the URL is a direct downloadable binary file. |
| `fileName` | `String` | Target output file name. |
| `zipPassword` | `String?` | Optional password. |

### `UpdateResult`

| Field | Type | Description |
|---|---|---|
| `updateAvailable` | `bool` | `true` if a newer version is available. |
| `latestVersion` | `String?` | Remote version string. |
| `changelog` | `String?` | Change log |
| `platformDownload` | `PlatformDownload?` | Platform download metadata. |

## Expected JSON Payload Schema

```json
{
  "latest_version": "1.5.0",
  "changelog": "- Added Announcements Service\n- Added auto-updater",
  "platforms": {
    "windows": {
      "download_url": "https://example.com/downloads/kyzen-windows.exe",
      "is_direct_download": true,
      "file_name": "kyzen-windows.exe",
      "zip_password": null
    },
    "windows_arm64": {
      "download_url": "https://example.com/downloads/kyzen-windows-arm64.exe",
      "is_direct_download": true,
      "file_name": "kyzen-windows-arm64.exe",
      "zip_password": null
    },
    "android": {
      "download_url": "https://example.com/downloads/kyzen-release.apk",
      "is_direct_download": true,
      "file_name": "kyzen-release.apk"
    },
    "linux": {
      "download_url": "https://example.com/downloads/kyzen-linux.AppImage",
      "is_direct_download": true,
      "file_name": "kyzen-linux.AppImage"
    }
  }
}
```

## Public API Reference

### Methods

#### `checkForUpdate()` → `Future<UpdateResult>`
Parses `UpdateInfo`, evaluates `isNewerVersion`, and checks if current OS platform key is present in `platforms`. Returns `UpdateResult.none()` if no update is available or if checks fail.

#### `installApk(String filePath)` → `Future<bool>`
Launches Android package installer for APK at `filePath` using `MethodChannel('xyz.kyzendlc.app/storage')`. Returns `true` if installer launched successfully.

#### `openInBrowser(PlatformDownload info)` → `Future<void>`
Opens `info.downloadUrl` in system external browser application using `url_launcher`.

#### `isNewerVersion(String remote)` → `bool`
Method comparing remote version string against local `AppVersion` fields (`major`, `minor`, `ultraminor`).
