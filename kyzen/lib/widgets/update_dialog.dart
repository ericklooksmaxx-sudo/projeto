import 'dart:io';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import '../models/update_info.dart';
import '../services/app_update_service.dart';
import '../services/app_version.dart';
import '../services/settings_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateResult updateResult;
  final bool showIgnoreButton;

  const UpdateDialog({
    super.key,
    required this.updateResult,
    this.showIgnoreButton = true,
  });

  static Future<void> checkAndShow(
    BuildContext context, {
    bool force = false,
  }) async {
    if (!force && await SettingsService.instance.isUpdateIgnored()) return;
    final result = await AppUpdateService.checkForUpdate();
    if (!context.mounted) return;
    if (!result.updateAvailable) {
      if (force) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.youAreUsingTheLatestVersion),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          UpdateDialog(updateResult: result, showIgnoreButton: !force),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = '';
  String? _downloadedPath;
  String? _error;
  final ScrollController _errorScrollController = ScrollController();

  PlatformDownload get _download => widget.updateResult.platformDownload!;

  @override
  void dispose() {
    _errorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(color: colorScheme.primaryContainer),
              child: Row(
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Available',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _versionChip(
                              AppVersion.display,
                              colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.14,
                              ),
                              colorScheme.onPrimaryContainer,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            _versionChip(
                              'v${widget.updateResult.latestVersion}',
                              colorScheme.primary,
                              colorScheme.onPrimary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    tooltip: context.l10n.close,
                    visualDensity: VisualDensity.compact,
                    onPressed: _isDownloading
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // changelog
            if (widget.updateResult.changelog != null &&
                widget.updateResult.changelog!.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            context.l10n.changelog,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ..._parseChangelog(widget.updateResult.changelog!).map(
                        (line) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  right: 10,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  line,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // download progress
            if (_isDownloading || _downloadedPath != null || _error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: _buildProgressSection(theme, colorScheme),
              ),

            // zip password (usually only for Windows)
            if (_download.zipPassword != null)
              _buildZipPasswordSection(theme, colorScheme),

            const SizedBox(height: 4),

            // actions
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _isDownloading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          (_downloadedPath != null || _error != null)
                              ? 'Close'
                              : 'Later',
                        ),
                      ),
                      if (_downloadedPath == null &&
                          _error == null &&
                          widget.showIgnoreButton)
                        TextButton(
                          onPressed: _isDownloading
                              ? null
                              : () async {
                                  await SettingsService.instance
                                      .ignoreUpdateForDays(1);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          child: Text(context.l10n.ignore1Day),
                        ),
                    ],
                  ),
                  if (_downloadedPath == null)
                    FilledButton.icon(
                      onPressed: _isDownloading ? null : _handleUpdate,
                      icon: Icon(
                        _error != null
                            ? Icons.refresh_rounded
                            : (_download.isDirectDownload
                                  ? Icons.download_rounded
                                  : Icons.open_in_new_rounded),
                        size: 18,
                      ),
                      label: Text(
                        _error != null
                            ? context.l10n.retry
                            : (_download.isDirectDownload
                                  ? context.l10n.download
                                  : context.l10n.openInBrowser),
                      ),
                    ),
                  if (_downloadedPath != null)
                    if (_download.fileName.toLowerCase().endsWith('.apk'))
                      FilledButton.icon(
                        onPressed: () =>
                            AppUpdateService.installApk(_downloadedPath!),
                        icon: const Icon(Icons.system_update_rounded, size: 18),
                        label: Text(context.l10n.installApk),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => _openInFileExplorer(_downloadedPath!),
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: Text(context.l10n.openFile),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _versionChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme, ColorScheme colorScheme) {
    if (_error != null) {
      final errorDetail = _error!.startsWith('Download failed: ')
          ? _error!.substring('Download failed: '.length).trim()
          : _error!;
      final displayDetail = errorDetail.isEmpty ? _error! : errorDetail;

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.downloadFailed,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110),
              child: Scrollbar(
                controller: _errorScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _errorScrollController,
                  child: Text(
                    displayDetail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_downloadedPath != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.savedTo(_getDisplayPath(_downloadedPath!)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // downloading in progress
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _status.isNotEmpty
              ? '${(_progress * 100).round()}% · $_status'
              : context.l10n.startingDownload,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildZipPasswordSection(ThemeData theme, ColorScheme colorScheme) {
    final textColor = colorScheme.onTertiaryContainer;
    final textStyle = theme.textTheme.bodySmall?.copyWith(color: textColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '${context.l10n.zipPassword} ',
                  style: textStyle,
                  children: [
                    TextSpan(
                      text: _download.zipPassword!,
                      style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: textColor,
              tooltip: context.l10n.copyPassword,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _download.zipPassword!));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    await SettingsService.instance.clearUpdateIgnored();
    if (_download.isDirectDownload) {
      setState(() {
        _isDownloading = true;
        _error = null;
      });
      try {
        final path = await AppUpdateService.downloadUpdate(
          _download,
          onProgress: (progress, status) {
            if (mounted) {
              setState(() {
                _progress = progress;
                _status = status;
              });
            }
          },
        );
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadedPath = path;
          });
          if (_download.fileName.toLowerCase().endsWith('.apk')) {
            await AppUpdateService.installApk(path);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _error = 'Download failed: $e';
          });
        }
      }
    } else {
      await AppUpdateService.openInBrowser(_download);
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _getDisplayPath(String filePath) {
    // fuckass android saf uri
    if (filePath.startsWith('content://')) {
      try {
        final decoded = Uri.decodeFull(filePath);
        if (decoded.contains(':')) {
          final lastPart = decoded.split(':').last;
          if (lastPart.isNotEmpty && !lastPart.startsWith('//')) {
            return lastPart;
          }
        }
        final uri = Uri.parse(filePath);
        if (uri.pathSegments.isNotEmpty) {
          return Uri.decodeComponent(uri.pathSegments.last);
        }
      } catch (_) {
        return filePath;
      }
    }
    return filePath;
  }

  // parse changelog lines and strip leading bullet markers
  List<String> _parseChangelog(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          // strip leading "- " or "* "
          if (line.startsWith('- ') || line.startsWith('* ')) {
            return line.substring(2);
          }
          return line;
        })
        .toList();
  }

  Future<void> _openInFileExplorer(String filePath) async {
    try {
      final directory = Directory(path.dirname(filePath));
      final uri = directory.uri;
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[UpdateDialog] Error opening file explorer: $e');
    }
  }
}
