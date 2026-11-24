# Kyzen

Kyzen is the app side of [kyzendlc.xyz](https://kyzendlc.xyz): a downloader for
Minecraft Bedrock marketplace packs, in the same black-glass skin as the site.

* Interface: the site's design tokens, in Dart — `lib/kyzen/` (colours, glass,
  metal, Anton + Work Sans, motion curves). Every Material surface is themed
  from `lib/kyzen/kz_theme.dart`, so screens that were never touched by hand
  still come out on-brand.
* Downloads pass: the 24 h gate runs **on the site**, not in the app. The app
  asks for a signed request (`/api/gate?a=app-req`), opens the gate page in the
  browser, and the browser hands a one-shot code back through
  `kyzen://unlock?c=<code>`, which the app redeems (`/api/gate?a=app-claim`).
  Code: `lib/kyzen/gate/`.
* Package id: `xyz.kyzendlc.app` — the site's gate return link names that
  package, so the id is part of the contract, not a preference.

# Project setup

After `flutter pub get` run `dart run husky install` to configure the git hooks.

## Environment Variables

Environment variables are injected at build time via `--dart-define-from-file`. Create a `.env.json` file in the project root with the following keys:

```json
{
  "KEYS_URL": "<url to the encrypted keys file>",
  "KEYS_DECRYPTION_KEY": "<32-char AES key for the keys file>",
  "SOCIAL_LINKS_URL": "<url to the social links JSON endpoint>",
  "UPLOAD_KEYS_URL": "<url to the key upload endpoint>",
  "ANNOUNCEMENTS_URL": "<url to the announcements JSON endpoint>",
  "UPDATE_URL": "<url to the update JSON endpoint>"
}
```

Pass it to every build/run command:

```
flutter run --dart-define-from-file=.env.json
flutter build <target> --dart-define-from-file=.env.json
```

> **VS Code**: `.vscode/launch.json` already includes `"toolArgs": ["--dart-define-from-file=.env.json"]` in every configuration, so the flag is applied automatically when launching from the editor.

| Key | Used in |
|---|---|
| `KEYS_URL` | `lib/services/key_service.dart` |
| `KEYS_DECRYPTION_KEY` | `lib/services/key_service.dart` |
| `SOCIAL_LINKS_URL` | `lib/services/social_link.dart` |
| `UPLOAD_KEYS_URL` | `lib/services/upload_keys.dart` |
| `ANNOUNCEMENTS_URL` | `lib/services/announcements_service.dart` |
| `UPDATE_URL` | `lib/services/app_update_service.dart` |



## libDecrypt

To build libdecrypt on Linux you need openSSL dev library:

Ubuntu/Debian: `sudo apt-get install -y libssl-dev`

Fedora: `sudo dnf install -y openssl-devel`

Arch: `sudo pacman -S openssl`

# Webdocs

Developer documentation use [VitePress](https://vitepress.dev/) and can be found in the `webdocs/` folder.

```bash
cd webdocs
npm install
```

Start locally:

```bash
npm run docs:dev
```

Build the static site to `webdocs/.vitepress/dist/`:

```bash
npm run docs:build
```

# Publishing

Using [FastForge](https://fastforge.dev/):

AppImage and Exe builds need some dependancies:
https://fastforge.dev/makers/appimage
https://fastforge.dev/makers/exe

Setup FastForge (first time):
`dart pub global activate fastforge`

After:
`fastforge release --name <name>`

All names available in [distribute_options.yaml](distribute_options.yaml)

windows command: fastforge release --name release-windows

