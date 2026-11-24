import 'package:kyzen/l10n/context_extensions.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../kyzen/kz_theme.dart';
import '../kyzen/kz_tokens.dart';

/// App-wide theme. Everything comes from the Kyzen tokens (see
/// `lib/kyzen/kz_theme.dart`); this class stays as the entry point the screens
/// already call.
///
/// The app is dark: the site is black glass, and a light copy of it is not the
/// same product. The colour picker still works — it moves the Material accent
/// (selection, switches, progress), while the brand metal stays Kyzen purple.
class AppTheme {
  static const WidgetStateProperty<Icon> switchThumbIcon =
      KzTheme.switchThumbIcon;

  static const Map<String, Color> _seedColors = {
    'kyzen': KzColors.p600,
    'blue': Colors.blue,
    'green': Colors.green,
    'orange': Colors.orange,
    'red': Colors.red,
    'teal': Colors.teal,
    'pink': Colors.pinkAccent,
    'lime': Colors.limeAccent,
  };

  static SystemUiOverlayStyle getSystemOverlayStyle({required bool isDark}) =>
      KzTheme.overlayStyle;

  static const PageTransitionsTheme pageTransitionsTheme =
      KzTheme.pageTransitionsTheme;

  static ThemeData getTheme({
    required bool isDark,
    required String colorScheme,
    Color? customColor,
    bool minecraftFont = false,
  }) {
    final Color accent = (colorScheme == 'custom' && customColor != null)
        ? customColor
        : (_seedColors[colorScheme] ?? KzColors.accent);
    return KzTheme.build(accent: accent, minecraftFont: minecraftFont);
  }

  static ThemeData get lightTheme => KzTheme.build();

  static ThemeData get darkTheme => KzTheme.build();

  static List<String> get availableColorSchemes => _seedColors.keys.toList();

  static Map<String, String> getColorSchemeDisplayNames(BuildContext context) =>
      {
        'kyzen': 'Kyzen',
        'blue': context.l10n.colorSchemeBlue,
        'green': context.l10n.colorSchemeGreen,
        'orange': context.l10n.colorSchemeOrange,
        'red': context.l10n.colorSchemeRed,
        'teal': context.l10n.colorSchemeTeal,
        'pink': context.l10n.colorSchemePink,
        'lime': context.l10n.colorSchemeLime,
      };

  static Color getSeedColor(String colorScheme) =>
      _seedColors[colorScheme] ?? KzColors.accent;
}
