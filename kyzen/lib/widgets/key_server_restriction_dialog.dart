import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import '../services/key_service.dart';

class KeyServerRestrictionDialog extends StatefulWidget {
  final void Function(int count)? onRetrySuccess;

  const KeyServerRestrictionDialog({super.key, this.onRetrySuccess});

  static Future<bool> show(
    BuildContext context, {
    void Function(int count)? onRetrySuccess,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) =>
          KeyServerRestrictionDialog(onRetrySuccess: onRetrySuccess),
    );
    return result ?? false;
  }

  @override
  State<KeyServerRestrictionDialog> createState() =>
      _KeyServerRestrictionDialogState();
}

class _KeyServerRestrictionDialogState
    extends State<KeyServerRestrictionDialog> {
  bool _isRetrying = false;
  String? _retryError;

  Future<void> _handleRetry() async {
    setState(() {
      _isRetrying = true;
      _retryError = null;
    });

    try {
      final count = await KeysService.instance.initialize(download: true);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      widget.onRetrySuccess?.call(count);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRetrying = false;
        _retryError = context.l10n.stillUnableToReachServer;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.vpn_lock_rounded,
          size: 36,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        context.l10n.keyServerConnectionFailed,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.unableToReachKeyServer,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.restrictedRegionOrNetwork,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.restrictedRegionOrNetworkDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.keyServerOfflineNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
              if (_retryError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _retryError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: _isRetrying
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.continueOffline),
        ),
        FilledButton.icon(
          onPressed: _isRetrying ? null : _handleRetry,
          icon: _isRetrying
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                  ),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text(_isRetrying ? context.l10n.retrying : context.l10n.retry),
        ),
      ],
    );
  }
}
