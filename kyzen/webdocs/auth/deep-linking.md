# Platform Deep Links

Ensures Microsoft Live authentication redirects can deliver the authentication token back to the application.

## Windows Registry Registration

Registers a protocol scheme handler in the user's registry.

**Location:** `HKCU\Software\Classes\ms-xal-0000000048183522`

- Key includes the `URL Protocol` string value.
- Subkey `shell\open\command` is set to the application executable: `"C:\Path\To\Kyzen.exe" "%1"`.

## Linux Desktop Registration

Generates a temporary desktop entry to listen to the protocol scheme:

- **Path:** `~/.local/share/applications/kyzen-temp-[random].desktop`
- Adds the entry: `MimeType=x-scheme-handler/ms-xal-0000000048183522;`
- Registers the scheme handler using `xdg-mime default [filename] x-scheme-handler/ms-xal-0000000048183522`, then updates the desktop database.

## Android Registration

Registers an intent filter in the app manifest to capture redirection URIs:

- **Manifest Location:** `android/app/src/main/AndroidManifest.xml`
- **Configuration:** An `<intent-filter>` is added under the `MainActivity` declaration:
  - **Action:** `android.intent.action.VIEW`
  - **Scheme:** `ms-xal-0000000048183522`
  - **Host:** `auth`
  - **Categories:** `android.intent.category.DEFAULT`, `android.intent.category.BROWSABLE`
