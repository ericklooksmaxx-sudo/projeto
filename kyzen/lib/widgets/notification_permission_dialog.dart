import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  static bool _isShowing = false;

  static Future<void> show(BuildContext context) async {
    if (_isShowing) return;
    if (!context.mounted) return;
    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const NotificationPermissionDialog(),
      );
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
        Icons.notifications_active_rounded,
        size: 36,
        color: colorScheme.primary,
      ),
      title: Text(context.l10n.notificationPermission),
      content: SingleChildScrollView(
        child: Text(
          context.l10n.notificationPermissionDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            height: 1.4,
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await openAppSettings();
          },
          child: Text(context.l10n.openSettings),
        ),
      ],
    );
  }
}
