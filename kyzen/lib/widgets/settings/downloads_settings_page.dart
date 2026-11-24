import 'dart:io';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../services/cache_manager.dart';
import '../../services/permission.dart';
import '../../services/settings_service.dart';

class DownloadsSettingsPage extends StatefulWidget {
  final VoidCallback onDownloadPathChanged;

  const DownloadsSettingsPage({super.key, required this.onDownloadPathChanged});

  @override
  State<DownloadsSettingsPage> createState() => _DownloadsSettingsPageState();
}

class _DownloadsSettingsPageState extends State<DownloadsSettingsPage> {
  final SettingsService _settingsService = SettingsService.instance;
  final StoragePermissionHandler _permissionHandler =
      StoragePermissionHandler();

  String? _customDownloadPath;
  late String _cachedDisplayPath;
  bool _compressionSetting = true;
  bool _pngSetting = false;
  bool _gallerySetting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cachedDisplayPath = _computeDisplayPath(null);
    _settingsService.onDownloadPathAutoReset = _onDownloadPathAutoReset;
    _loadSettings();
  }

  @override
  void dispose() {
    if (_settingsService.onDownloadPathAutoReset == _onDownloadPathAutoReset) {
      _settingsService.onDownloadPathAutoReset = null;
    }
    super.dispose();
  }

  void _onDownloadPathAutoReset(String stalePath) {
    if (!mounted) return;
    final staleDisplay = _computeDisplayPath(stalePath);
    final defaultDisplay = _computeDisplayPath(null);
    setState(() {
      _customDownloadPath = null;
      _cachedDisplayPath = defaultDisplay;
    });
    widget.onDownloadPathChanged();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.folder_off_rounded),
        title: Text(context.l10n.downloadPathResetTitle),
        content: Text(
          context.l10n.downloadPathResetFallback(staleDisplay, defaultDisplay),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    final compression = await _settingsService.getCompression();
    final png = await _settingsService.getPng();
    final gallery = await _settingsService.getGallery();
    final customPath = await _settingsService.getCustomDownloadPath();

    if (mounted) {
      setState(() {
        _compressionSetting = compression;
        _pngSetting = png;
        _gallerySetting = gallery;
        _customDownloadPath = customPath;
        _cachedDisplayPath = _computeDisplayPath(customPath);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCompression(bool value) async {
    try {
      await _settingsService.setCompression(value);
      setState(() => _compressionSetting = value);
    } catch (_) {
      _showErrorSnackBar('Failed to save compression setting');
    }
  }

  Future<void> _togglePng(bool value) async {
    try {
      await _settingsService.setPng(value);
      setState(() => _pngSetting = value);
    } catch (_) {
      _showErrorSnackBar('Failed to save PNG setting');
    }
  }

  Future<void> _toggleGallery(bool value) async {
    try {
      if (value) {
        await _permissionHandler.requestGalleryPermission();
      }
      await _settingsService.setGallery(value);
      setState(() => _gallerySetting = value);
    } catch (_) {
      _showErrorSnackBar('Failed to update gallery setting');
    }
  }

  Future<void> _pickDownloadFolder() async {
    try {
      String? selectedDirectory;
      if (Platform.isAndroid) {
        selectedDirectory = await _pickFolderAndroid();
      } else {
        selectedDirectory = await FilePicker.getDirectoryPath();
      }

      if (selectedDirectory != null) {
        await _settingsService.setCustomDownloadPath(selectedDirectory);
        setState(() {
          _customDownloadPath = selectedDirectory;
          _cachedDisplayPath = _computeDisplayPath(selectedDirectory);
        });

        widget.onDownloadPathChanged();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.downloadPathUpdated),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select folder: $e');
    }
  }

  Future<String?> _pickFolderAndroid() async {
    const platform = MethodChannel('xyz.kyzendlc.app/storage');
    try {
      final String? uri = await platform.invokeMethod('pickFolder');
      return uri;
    } catch (e) {
      debugPrint('Error picking folder: $e');
      return null;
    }
  }

  Future<void> _resetDownloadFolder() async {
    try {
      await _settingsService.setCustomDownloadPath(null);
      setState(() {
        _customDownloadPath = null;
        _cachedDisplayPath = _computeDisplayPath(null);
      });
      widget.onDownloadPathChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.downloadPathReset),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      _showErrorSnackBar('Failed to reset folder');
    }
  }

  String _computeDisplayPath(String? path) {
    if (path != null) {
      if (path.startsWith('content://')) {
        try {
          final uri = Uri.parse(path);
          final segments = uri.pathSegments;
          if (segments.isNotEmpty) {
            final lastSegment = Uri.decodeComponent(segments.last);
            if (lastSegment.contains(':')) {
              final parts = lastSegment.split(':');
              if (parts.length > 1) {
                return parts.sublist(1).join(':');
              }
            }
            return lastSegment;
          }
          return 'External Storage';
        } catch (_) {
          return 'Custom Location';
        }
      }

      final segments = path.split(Platform.pathSeparator);
      if (segments.length > 2) {
        return '...${Platform.pathSeparator}${segments[segments.length - 2]}${Platform.pathSeparator}${segments.last}';
      }
      return path;
    }

    if (Platform.isAndroid) {
      return 'Download/Kyzen';
    } else {
      return 'Downloads/Kyzen';
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildSectionCard({required List<Widget> children, String? title}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.downloadsAndStorage;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), forceMaterialTransparency: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          12.0,
          12.0,
          12.0,
          12.0 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _buildSectionCard(
            title: context.l10n.downloadLocation,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: Text(context.l10n.downloadPath),
                subtitle: Text(
                  _cachedDisplayPath,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_customDownloadPath != null)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: context.l10n.resetDefaults,
                        onPressed: _resetDownloadFolder,
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _pickDownloadFolder,
                      icon: Icon(
                        Icons.folder_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: context.l10n.chooseFolder,
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildSectionCard(
            title: context.l10n.fileAndImageFormats,
            children: [
              SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.compression),
                subtitle: Text(
                  _compressionSetting
                      ? context.l10n.normalCompression
                      : context.l10n.noCompression,
                ),
                value: _compressionSetting,
                onChanged: _toggleCompression,
                secondary: Icon(
                  _compressionSetting
                      ? Icons.folder_zip_rounded
                      : Icons.folder_rounded,
                ),
              ),
              const Divider(),
              SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.saveToPng),
                value: _pngSetting,
                onChanged: _togglePng,
                secondary: Icon(
                  _pngSetting ? Icons.image_outlined : Icons.image_rounded,
                ),
              ),
              const Divider(),
              SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.saveToGallery),
                value: _gallerySetting,
                onChanged: _toggleGallery,
                secondary: Icon(
                  _gallerySetting ? Icons.photo_camera : Icons.no_photography,
                ),
              ),
            ],
          ),
          _buildSectionCard(
            title: context.l10n.cache,
            children: [
              ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: Text(context.l10n.cache),
                subtitle: Text(context.l10n.temporaryFiles),
                trailing: ElevatedButton(
                  onPressed: () async {
                    double clearedMB = await SmallCacheManager.clearCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.cacheCleared(
                              clearedMB.toStringAsFixed(1),
                            ),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                  ),
                  child: Text(context.l10n.clear),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
