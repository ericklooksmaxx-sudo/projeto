import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import '../flutter_gpu/texture_utils.dart';
import '../services/settings_service.dart';

class Unsupported3DDialog extends StatelessWidget {
  const Unsupported3DDialog({super.key});

  static bool _isShowing = false;

  static Future<bool> checkAndShow(BuildContext context) async {
    if (!SettingsService.instance.get3DPreviewSync()) return false;
    if (is3DPreviewSupported()) return false;
    if (_isShowing) return false;

    final alreadyShown = await SettingsService.instance
        .get3DUnsupportedWarnShown();
    if (alreadyShown || !context.mounted) return false;

    _isShowing = true;
    try {
      await SettingsService.instance.set3DPreview(false);
      await SettingsService.instance.set3DUnsupportedWarnShown(true);
      if (!context.mounted) return false;

      await showDialog<void>(
        context: context,
        builder: (_) => const Unsupported3DDialog(),
      );
      return true;
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(
        Icons.view_in_ar_rounded,
        size: 36,
        color: colorScheme.primary,
      ),
      title: Text(context.l10n.unsupported3DTitle),
      content: Text(
        context.l10n.unsupported3DMessage,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          height: 1.4,
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.ok),
        ),
      ],
    );
  }
}
