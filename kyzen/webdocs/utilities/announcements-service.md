# AnnouncementsService

Fetches application announcements.

## Environment Variable

| Variable | Description |
|---|---|
| `ANNOUNCEMENTS_URL` | The endpoint URL to `GET` announcements from. Must be provided at build time via `--dart-define-from-file=.env.json`. |

## Data Models

### `Announcement`

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique identifier (parsed from `id`, `_id`, `uuid`, or generated epoch microsecond). |
| `title` | `String` | Announcement title (parsed from `title` or `heading`). |
| `body` | `String` | Content description (parsed from `body`, `content`, or `description`). |
| `date` | `DateTime?` | Optional timestamp (supports ISO 8601 strings and unix timestamps in seconds or milliseconds). |
| `imageUrl` | `String?` | Optional banner image URL (parsed from `image_url`, `image`, `imageUrl`, or `banner`). |
| `links` | `List<AnnouncementLink>` | Optional list of associated action links. |

### `AnnouncementLink`

| Field | Type | Description |
|---|---|---|
| `label` | `String` | Display label for the link. |
| `url` | `String` | Action target web URL. |

## Expected JSON Payload Schemas

The service supports both a top-level JSON array and wrapped JSON objects:

### Direct Array Payload
```json
[
  {
    "id": "ann-1",
    "title": "Version 1.5.0 Released",
    "body": "New features and improvements",
    "date": "2026-07-29T12:00:00Z",
    "image_url": "https://example.com/banner.png",
    "links": [
      { "label": "Changelog", "url": "https://example.com/changelog" }
    ]
  }
]
```

### Wrapped Object Payload
```json
{
  "announcements": [
    {
      "uuid": "ann-2",
      "heading": "Maintenance Notice",
      "content": "Server is gonna blow up soon; maintenance is scheduled for tomorrow.",
      "created_at": 1722254400,
      "banner": "https://example.com/notice.jpg",
      "action_links": [
        "https://example.com/status"
      ]
    }
  ]
}
```

## Public API Reference

### Properties

#### `hasUnreadNotifier` → `ValueNotifier<bool>`
A static `ValueNotifier` indicating whether there are unread announcements relative to the last stored hash in `SettingsService`.

---

### Methods

#### `fetchAnnouncements({bool forceRefresh = false, bool isTabActive = false})` → `Future<List<Announcement>>`

- `forceRefresh`: When `true`, ignores cache and performs a fresh request.
- `isTabActive`: When `true`, automatically marks announcements as read if tab is visible.

#### `markAsRead([String? rawContent])` → `Future<void>`
Stores the MD5 hash of the current or specified raw content into `SettingsService` and sets `hasUnreadNotifier.value = false`.

#### `checkUnreadStatus(String rawContent, {bool isTabActive = false})` → `Future<void>`
Compares the MD5 hash of `rawContent` against the stored hash in `SettingsService` and updates `hasUnreadNotifier`.

#### `computeHash(String? input)` → `String`
Computes the MD5 hex digest string.
