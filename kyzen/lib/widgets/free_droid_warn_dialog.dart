import 'dart:io';
import 'dart:ui';
import 'package:kyzen/l10n/app_localizations.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';

class FreeDroidWarnDialog extends StatelessWidget {
  const FreeDroidWarnDialog({super.key});

  static Future<bool> checkAndShow(BuildContext context) async {
    if (!Platform.isAndroid) return false;

    final alreadyShown = await SettingsService.instance.getFreeDroidWarnShown();
    if (alreadyShown) return false;
    if (!context.mounted) return false;

    // only display once
    await SettingsService.instance.setFreeDroidWarnShown(true);
    if (!context.mounted) return false;

    // new users would prolly never see the localized message since
    // to reach the settings to change lang they need to dismiss the dialog
    // so we auto get the local of the device and override lang
    final deviceLocale = PlatformDispatcher.instance.locale;
    final localeToUse = AppLocalizations.delegate.isSupported(deviceLocale)
        ? Locale(deviceLocale.languageCode)
        : const Locale('en');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Localizations.override(
        context: dialogContext,
        locale: localeToUse,
        child: const FreeDroidWarnDialog(),
      ),
    );
    return true;
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenLink(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(
        Icons.warning_amber_rounded,
        size: 36,
        color: colorScheme.error,
      ),
      content: SingleChildScrollView(
        child: Text(
          l10n.freeDroidWarnMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            height: 1.4,
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => _openUrl(context, 'https://keepandroidopen.org'),
          child: Text(l10n.freeDroidWarnDetails),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          onPressed: () => _openUrl(
            context,
            'https://github.com/woheller69/FreeDroidWarn?tab=readme-ov-file#solutions',
          ),
          child: Text(
            l10n.freeDroidWarnSolution,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
