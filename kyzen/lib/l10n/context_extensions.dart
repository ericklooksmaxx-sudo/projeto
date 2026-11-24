import 'package:material_ui/material_ui.dart';
import 'package:kyzen/l10n/app_localizations.dart';

extension ContextExtensions on BuildContext {
  AppLocalizations get l10n {
    final localizations = AppLocalizations.of(this);
    if (localizations == null) {
      throw FlutterError(
        'AppLocalizations not found in context. Make sure MaterialApp includes AppLocalizations.delegate',
      );
    }
    return localizations;
  }
}
