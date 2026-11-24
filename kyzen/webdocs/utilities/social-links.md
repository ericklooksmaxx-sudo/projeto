# SocialLinksService

Fetches community social links (Telegram, Discord, etc.) from a remote endpoint and exposes them to the UI. Falls back to a hardcoded list if the network request fails or if the build environment variable is not set.

## `SocialLink`

### Fields

| Field | Type | Description |
|---|---|---|
| `title` | `String` | Display name of the platform (e.g. `"Telegram"`). |
| `url` | `String` | Full URL of the community link. |
| `icon` | `String?` | Lowercase icon identifier used to resolve the platform icon asset (e.g. `"discord"`). |

### Constructor

```dart
const SocialLink({required String title, required String url, String? icon})
```

### Fallback Links

If the remote fetch fails for any reason, the service returns the following hardcoded links:

| Title | URL | Icon |
|---|---|---|
| Telegram | `https://t.me/+M8oIGVo-GpEyNGU0` | `telegram` |
| Discord | `https://discord.gg/XHgyapNEx8` | `discord` |

### Environment Variable

| Variable | Description |
|---|---|
| `SOCIAL_LINKS_URL` | The endpoint URL to `GET` social links from. Must be provided at build time via `--dart-define-from-file=.env.json`. |

**Expected JSON format:**

```json
{
  "telegram": "https://t.me/+M8oIGVo-GpEyNGU0",
  "discord": "https://discord.gg/XHgyapNEx8",
  "twitter": "https://twitter.com/example"
}
```

**Return examples:**

```dart
// Success
final (links, isUsingFallback) = await SocialLinksService.fetch();
// isUsingFallback == false

// Network failure / timeout / bad status
final (links, isUsingFallback) = await SocialLinksService.fetch();
// isUsingFallback == true, links == SocialLinksService.fallback
```