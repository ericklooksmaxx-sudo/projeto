# Publishing with FastForge

Kyzen uses [FastForge](https://fastforge.dev/) to build and package releases for all supported platforms.

## Prerequisites

Some makers require extra system dependencies before you can build:

- **AppImage (Linux):** See [fastforge.dev/makers/appimage](https://fastforge.dev/makers/appimage)
- **EXE (Windows):** See [fastforge.dev/makers/exe](https://fastforge.dev/makers/exe)

## First-time Setup

Activate the FastForge CLI globally (only needed once):

```bash
dart pub global activate fastforge
```

## Running a Release

```bash
fastforge release --name <name>
```

Available release names are defined in `distribute_options.yaml`:

| Name | Platform | Output |
|---|---|---|
| `release-linux` | Linux | AppImage |
| `release-android` | Android | APK |
| `release-windows` | Windows | EXE |

### Examples

```bash
# Windows installer
fastforge release --name release-windows

# Android APK
fastforge release --name release-android

# Linux AppImage
fastforge release --name release-linux
```

Output is written to the `dist/` folder.
