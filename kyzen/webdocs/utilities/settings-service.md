# SettingsService

Manages the application's configuration parameters. Saves settings in local JSON format to `settings_app.json`.

## Preferences Schema Fields

| Field Key | Type | Default Value | Description |
|---|---|---|---|
| `isDarkMode` | boolean | `true` | Enables dark theme. |
| `colorScheme` | string | `null` | Selected application color theme palette. |
| `customColor` | integer | `null` | Decimal representation of custom color scheme. |
| `keyFilter` | string | `"Show all"` | Filters lists based on key availability (Only available, Only not available, Show all). |
| `KeyUpdate` | boolean | `true` | If should auto update keys. |
| `OnlyNewKeys` | boolean | `false` | Export option to filter out existing keys. |
| `ShowSkins` | boolean | `true` | Toggles display of skin packs in search results. |
| `PNG` | boolean | `false` | If should export the image to PNG |
| `ImageToGallery` | boolean | `false` | Allows saving downloaded images to the gallery. |
| `NormalCompression` | boolean | `true` | Applies standard compression level when packaging zips. |
| `LoadSkinPersona` | boolean | `false` | Determines if skin/persona keys are processed during local searches. |
| `LoadOnlyNewKeys` | boolean | `false` | Hides keys that are already present into the main keys db. |
| `Languages` | string | `"en"` | App translation localization language code. |
| `apiLanguage` | string | `"en"` | PlayFab API localized search results content language. |
| `pageSize` | integer | `30` | Page size limit for catalog queries. |
| `mcFont` | boolean | `false` | Applies Minecraft font when true. |
| `customDownloadPath` | string | `null` | Custom output directory or Android SAF URI (`content://`). |
| `minecraftPackageName` | string | `"com.mojang.minecraftpe"` | Package ID of the target game (useful when using cloned mc). |
| `devModeEnabled` | boolean | `false` | Enables developer menu. |

## Configuration Loading & Serialization Methods

### `loadSettings()` → `Future<Map<String, dynamic>>`

Loads preferences from `settings_app.json`. If the file does not exist, writes the default configurations map to disk first. It merges the stored values with defaults to guarantee all preference keys are present in the returned Map.

### `updateSetting(String key, dynamic value)` → `Future<void>`

Updates a specific setting key-value pair in memory, serializes the updated settings structure to JSON format, and overwrites `settings_app.json` on disk.

### `getSetting<T>(String key, T defaultValue)` → `Future<T>`

Returns the value associated with the specified key, cast to type `T`. If the key is not found or null, returns the provided `defaultValue`.

### `resetToDefaults()` → `Future<void>`

Resets all settings back to the default system settings. Overwrites `settings_app.json` with the default configurations map.

## JSON Schema Example

```json
{
  "isDarkMode": true,
  "keyFilter": "Show all",
  "KeyUpdate": true,
  "ShowSkins": true,
  "Languages": "en",
  "customDownloadPath": "C:\\Users\\...\\Kyzen",
  "minecraftPackageName": "com.mojang.minecraftpe"
}
```
