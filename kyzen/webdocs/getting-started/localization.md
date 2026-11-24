# Localization (l10n)

Kyzen uses Flutter's built-in localization system ([`flutter_localizations`](https://docs.flutter.dev/ui/internationalization)) to support **20 languages**. Translation strings live in ARB files; Dart code is generated automatically.

::: info Official Reference
Flutter's full internationalization guide is available at [docs.flutter.dev/ui/internationalization](https://docs.flutter.dev/ui/internationalization).
:::

## File Layout

```
l10n.yaml                   ← code-gen configuration (project root)
lib/l10n/
  app_en.arb                ← template (English)
  app_es.arb                ← Spanish translations
  app_it.arb                ← Italian translations
  … (one .arb per locale)
  app_localizations.dart    ← generated (do not edit)
  app_localizations_*.dart  ← generated (do not edit)
  context_extensions.dart   ← extension on BuildContext
```

## l10n.yaml

The `l10n.yaml` at the project root controls how the generator runs:

```yaml
arb-dir: lib/l10n                          # where the .arb files live
template-arb-file: app_en.arb             # English is the template
output-localization-file: app_localizations.dart
untranslated-messages-file: untranslated_text.txt
```

## Adding / Updating Translations

1. **Edit the template** `lib/l10n/app_en.arb` to add or change a key.
2. **Copy the key** to every other `app_<locale>.arb` file with the translated value.
3. **Run the generator** (see below).

### ARB key format

```json
{
  "@@locale": "en",
  "welcomeTitle": "Welcome to Kyzen",
  "@welcomeTitle": {
    "description": "Title shown on the home screen"
  },
  "itemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "@itemCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

## Generating Dart Code

After editing any `.arb` file, regenerate the Dart classes:

```bash
flutter gen-l10n
```

This reads `l10n.yaml` and writes the `app_localizations*.dart` files in `lib/l10n/`.

::: tip Automatic generation
If you prefer, enable automatic generation instead of the manual command by adding the following to `pubspec.yaml`:

```yaml
flutter:
  generate: true
```
:::

## Wiring up MaterialApp

The generated delegates must be passed to `MaterialApp`:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kyzen/l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  // ...
)
```

## Using Strings in Widgets

`context_extensions.dart` provides a short `context.l10n` accessor so you don't need to write `AppLocalizations.of(context)!` every time:

```dart
import 'package:kyzen/l10n/context_extensions.dart';

// Inside a build method:
Text(context.l10n.welcomeTitle)
```

## Supported Locales

| Code | Language |
|------|----------|
| `ar` | Arabic |
| `bn` | Bengali |
| `cs` | Czech |
| `en` | English |
| `es` | Spanish |
| `fa` | Persian |
| `fi` | Finnish |
| `fil` | Filipino |
| `fr` | French |
| `hi` | Hindi |
| `id` | Indonesian |
| `it` | Italian |
| `lt` | Lithuanian |
| `ms` | Malay |
| `pt` | Portuguese |
| `ru` | Russian |
| `th` | Thai |
| `uk` | Ukrainian |
| `zh` | Chinese |

## Tracking Untranslated Strings

`l10n.yaml` is configured with `untranslated-messages-file: untranslated_text.txt`. After running `flutter gen-l10n`, open `untranslated_text.txt` in the project root to see which keys are still missing for each locale.
