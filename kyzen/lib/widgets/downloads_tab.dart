import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/share_file.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import '../services/minecraft_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../models/download_tab.dart';
import 'file_icon_helper.dart';

class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => DownloadsTabState();
}

class DownloadsTabState extends State<DownloadsTab> {
  List<DownloadedFile> _files = [];
  bool _isLoading = true;
  bool _wasDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();

    Provider.of<DownloadService>(context, listen: false).loadIconCache();
  }

  void refreshFiles() {
    _loadFiles();
    Provider.of<DownloadService>(context, listen: false).loadIconCache();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final folderPath = await SettingsService.instance.getDownloadPath();
      List<DownloadedFile> files;

      if (folderPath.startsWith('content://')) {
        files = await _loadFilesFromContentUri(folderPath);
      } else {
        files = await _loadFilesFromDirectory(folderPath);
      }

      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading files: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<DownloadedFile>> _loadFilesFromDirectory(String dirPath) async {
    // directory.list it's only picking up files created by the app (this only happens on latest android version)
    // and it might not detect new file created by the user
    final entities = await Directory(
      dirPath,
    ).list().where((entity) => entity is File).toList();

    final futures = entities.map((entity) async {
      final stat = await entity.stat();
      return DownloadedFile(
        name: path.basename(entity.path),
        path: entity.path,
        size: stat.size,
        lastModified: stat.modified,
      );
    }).toList();

    return Future.wait(futures);
  }

  Future<List<DownloadedFile>> _loadFilesFromContentUri(String uri) async {
    const platform = MethodChannel('xyz.kyzendlc.app/storage');

    try {
      final List<dynamic> result = await platform.invokeMethod('listFiles', {
        'uri': uri,
      });

      return result.map((fileMap) {
        return DownloadedFile(
          name: fileMap['name'] as String,
          uri: fileMap['uri'] as String,
          size: fileMap['size'] as int,
          lastModified: DateTime.fromMillisecondsSinceEpoch(
            fileMap['lastModified'] as int,
          ),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error listing files from content URI: $e');
      return [];
    }
  }

  Future<bool> _deleteFile(DownloadedFile file) async {
    try {
      if (file.uri != null) {
        const platform = MethodChannel('xyz.kyzendlc.app/storage');
        return await platform.invokeMethod<bool>('deleteFile', {
              'uri': file.uri,
            }) ??
            false;
      } else if (file.path != null) {
        await File(file.path!).delete();
        return true;
      }
    } catch (e) {
      debugPrint('Delete failed: $e');
    }

    return false;
  }

  Future<void> _confirmAndDelete(DownloadedFile file) async {
    final pathToRemove = file.path ?? file.uri;

    setState(() {
      _files.remove(file);
    });

    final success = await _deleteFile(file);

    if (!mounted) return;

    if (!success) {
      // rollback
      setState(() {
        _files.add(file);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.failedToDeleteFile)));
      return;
    }

    if (pathToRemove != null) {
      await context.read<DownloadService>().removeIconCacheEntry(pathToRemove);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.fileDeleted),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _shareFile(DownloadedFile file) async {
    try {
      final pathToShare = file.uri ?? file.path;
      if (pathToShare != null) {
        await ShareFile.shareFile(filePath: pathToShare);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedToShareFile(e.toString()))),
      );
    }
  }

  String _getFileSize(DownloadedFile file) {
    try {
      final sizeInBytes = file.size;

      if (sizeInBytes >= 1024 * 1024 * 1024) {
        // GB
        return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      } else if (sizeInBytes >= 1024 * 1024) {
        // MB (1 MB or more)
        return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
      } else {
        // Less than 1 MB, show as KB
        return '${(sizeInBytes / 1024).toStringAsFixed(0)} KB';
      }
    } catch (e) {
      return 'Unknown size';
    }
  }

  void _openInFileExplorer(DownloadedFile file) async {
    try {
      if (file.path != null) {
        final uri = Directory(path.dirname(file.path!)).uri;

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      debugPrint('Error opening file explorer: $e');
    }
  }

  Widget _buildActionButton({
    required String tooltip,
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    double iconSize = 18,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor ?? color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(DownloadedFile file, DownloadService downloadService) {
    final fileName = file.name;
    final fileExtension = fileName.toLowerCase();
    final isMinecraftFile =
        fileExtension.endsWith('.mctemplate') ||
        fileExtension.endsWith('.mcworld') ||
        fileExtension.endsWith('.mcpack') ||
        fileExtension.endsWith('.mcaddon');

    final filePath = file.path ?? file.uri;
    final iconUrl = filePath != null
        ? downloadService.getIconUrlForFile(filePath)
        : null;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final accentColor = isMinecraftFile
        ? colorScheme.tertiary
        : colorScheme.secondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: iconUrl != null
                    ? CachedNetworkImage(
                        imageUrl: iconUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        memCacheWidth: 128,
                        memCacheHeight: 128,
                        errorBuilder: (context, url, error) =>
                            getFileIcon(fileName, context),
                        placeholder: (context, url) =>
                            getFileIcon(fileName, context),
                      )
                    : getFileIcon(fileName, context),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getFileSize(file),
                      style: TextStyle(
                        color: primaryColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (isMinecraftFile && filePath != null)
                  _buildActionButton(
                    tooltip: context.l10n.importToMc,
                    onTap: () =>
                        MinecraftLauncher.importToMinecraft(filePath, context),
                    icon: Icons.file_download,
                    color: colorScheme.tertiary,
                  ),
                if (Platform.isAndroid)
                  _buildActionButton(
                    tooltip: context.l10n.shareFile,
                    onTap: () => _shareFile(file),
                    icon: Icons.share,
                    color: primaryColor,
                  ),
                if (Platform.isWindows && file.path != null)
                  _buildActionButton(
                    tooltip: context.l10n.openFileinExplorer,
                    onTap: () => _openInFileExplorer(file),
                    icon: Icons.folder_open,
                    color: colorScheme.secondary,
                  ),
                _buildActionButton(
                  tooltip: context.l10n.deleteFile,
                  onTap: () => _showDeleteConfirmation(file),
                  icon: Icons.delete_outline,
                  color: colorScheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(DownloadedFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteFile),
        content: Text(context.l10n.deleteFileConfirmation(file.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancelUppercase),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmAndDelete(file);
            },
            child: Text(
              context.l10n.deleteUppercase,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, child) {
        // Check if download just completed, if so refresh files list
        final isDownloading = downloadService.isDownloading;
        if (_wasDownloading && !isDownloading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadFiles();
          });
        }
        _wasDownloading = isDownloading;

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final primaryColor = colorScheme.primary;
        final bool hasDownloads =
            isDownloading || downloadService.completedDownloads.isNotEmpty;
        final bool hasFiles = !_isLoading && _files.isNotEmpty;
        final bool showEmptyState = !hasDownloads && !hasFiles && !_isLoading;

        if (showEmptyState || (_isLoading && !hasDownloads)) {
          return Center(
            child: showEmptyState
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_done_rounded,
                        size: 48,
                        color: primaryColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.noActiveDownloads,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          );
        }
        return CustomScrollView(
          slivers: [
            if (isDownloading) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.downloading,
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.currentDownload,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
                  child: _buildActiveDownload(downloadService),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

            if (downloadService.completedDownloads.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.l10n.completedDownloads,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                        ],
                      ),
                      if (downloadService.completedDownloads.length > 1)
                        TextButton(
                          onPressed: () =>
                              downloadService.clearAllCompletedDownloads(),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                          ),
                          child: Text(context.l10n.clearAll),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverList.builder(
                  itemCount: downloadService.completedDownloads.length,
                  itemBuilder: (context, index) {
                    final download = downloadService.completedDownloads[index];
                    return _buildCompletedDownloadItem(
                      download,
                      downloadService,
                    );
                  },
                ),
              ),
            ],

            // Stored files header
            if (hasFiles) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.folder_rounded,
                              size: 18,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.l10n.storedFiles,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh_rounded, color: primaryColor),
                        onPressed: _loadFiles,
                        tooltip: context.l10n.refreshFiles,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
            ],

            // Stored files list
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(13, 2, 13, 13),
                sliver: SliverList.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) =>
                      _buildFileItem(_files[index], downloadService),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActiveDownload(DownloadService downloadService) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final currentItem = downloadService.currentItem;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentItem != null) ...[
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.download_for_offline_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentItem.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentItem.creator,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: downloadService.progress,
                backgroundColor: primaryColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  downloadService.status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(downloadService.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedDownloadItem(
    CompletedDownload download,
    DownloadService downloadService,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 24,
          ),
        ),
        title: Text(
          download.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          download.item.creator,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        trailing: _buildActionButton(
          tooltip: context.l10n.clear,
          onTap: () =>
              downloadService.clearCompletedDownload(download.item.dlcId),
          icon: Icons.close,
          iconSize: 16,
          color: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
        ),
      ),
    );
  }
}
