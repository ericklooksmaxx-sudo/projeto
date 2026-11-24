import 'dart:io';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../services/key_filter.dart';
import '../../services/key_service.dart';
import '../../services/minecraft_launcher.dart';
import '../../services/search_service.dart';
import '../../services/settings_service.dart';
import '../app_picker_dialog.dart';
import '../custom_db_page.dart';
import '../custom_toast.dart';
import '../key_server_restriction_dialog.dart';
import '../mcdecryptor_page.dart';

class KeysSettingsPage extends StatefulWidget {
  final KeysService keysService;
  final SearchService searchService;
  final Function(int) onPageSizeChanged;
  final Function(String)? onKeyFilterChanged;

  const KeysSettingsPage({
    super.key,
    required this.keysService,
    required this.searchService,
    required this.onPageSizeChanged,
    this.onKeyFilterChanged,
  });

  @override
  State<KeysSettingsPage> createState() => _KeysSettingsPageState();
}

class _KeysSettingsPageState extends State<KeysSettingsPage> {
  final SettingsService _settingsService = SettingsService.instance;
  String _selectedKeyFilter = KeyFilterType.showAll;
  bool _keySetting = true;
  bool _skinSetting = true;
  int _pageSize = 30;
  int? _totalKeysCount;
  String? _minecraftPackageName;
  Uint8List? _minecraftAppIcon;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final keyFilter = await _settingsService.getKeyFilter();
    final keySettings = await _settingsService.getKeyUpdate();
    final skinSetting = await _settingsService.getSkinsFilter();
    final pageSize = await _settingsService.getPageSize();
    final packageName = await _settingsService.getMinecraftPackageName();
    final savedIcon = await MinecraftLauncher.loadSavedAppIcon();

    int? keysCount;
    if (widget.keysService.mainManifestUuids.isNotEmpty) {
      keysCount = widget.keysService.mainManifestUuids.length;
    } else {
      final content = widget.keysService.mainTsvContent;
      if (content != null) {
        int count = 0;
        for (int i = 0; i < content.length; i++) {
          if (content.codeUnitAt(i) == 0x0A) count++;
        }
        keysCount = count;
      }
    }

    if (mounted) {
      setState(() {
        _selectedKeyFilter = keyFilter;
        _keySetting = keySettings;
        _skinSetting = skinSetting;
        _pageSize = pageSize;
        _totalKeysCount = keysCount;
        _minecraftPackageName = packageName;
        _minecraftAppIcon = savedIcon;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleKeysUpdate(bool value) async {
    try {
      await _settingsService.setKeyUpdate(value);
      setState(() => _keySetting = value);
    } catch (_) {
      _showErrorSnackBar('Failed to save keys setting');
    }
  }

  Future<void> _manualCheckKeys() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final count = await widget.keysService.initialize(download: true);
      if (!mounted) return;
      Navigator.of(context).pop();

      CustomToast.showToast(
        context: context,
        message: count > 0
            ? context.l10n.addedNewKeys(count)
            : context.l10n.keysAreUpToDate,
      );
      _loadSettings();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      if (KeysService.isNetworkOrRestrictedError(e)) {
        await KeyServerRestrictionDialog.show(
          context,
          onRetrySuccess: (count) {
            if (mounted) {
              CustomToast.showToast(
                context: context,
                message: count > 0
                    ? context.l10n.addedNewKeys(count)
                    : context.l10n.keysAreUpToDate,
              );
              _loadSettings();
            }
          },
        );
      } else {
        _showErrorSnackBar('Error loading keys: $e');
      }
    }
  }

  Future<void> _updateKeyFilter(String? newValue) async {
    if (newValue == null) return;
    try {
      await _settingsService.setKeyFilter(newValue);
      setState(() => _selectedKeyFilter = newValue);
      widget.onKeyFilterChanged?.call(newValue);
    } catch (_) {
      _showErrorSnackBar('Failed to save key filter setting');
    }
  }

  Future<void> _toggleSkinFilter(bool value) async {
    try {
      await _settingsService.setSkinsFilter(value);
      setState(() => _skinSetting = value);
    } catch (_) {
      _showErrorSnackBar('Failed to save skin setting');
    }
  }

  Future<void> _savePageSize(double value) async {
    try {
      final newPageSize = value.round();
      await _settingsService.setPageSize(newPageSize);
      widget.onPageSizeChanged(newPageSize);
    } catch (_) {
      _showErrorSnackBar('Failed to save page size setting');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _getKeyFilterIcon() {
    return KeyFilterType.getIcon(_selectedKeyFilter);
  }

  Widget _buildSectionCard({required List<Widget> children, String? title}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                  style: theme.textTheme.titleMedium?.copyWith(
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
    final title = context.l10n.keysAndTools;
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
            title: context.l10n.keys,
            children: [
              SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.autoUpdate),
                value: _keySetting,
                onChanged: _toggleKeysUpdate,
                secondary: Icon(
                  _keySetting ? Icons.key_rounded : Icons.key_off_rounded,
                ),
              ),
              const Divider(),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.sync_rounded),
                title: Text(context.l10n.checkForKeysUpdate),
                trailing: const Icon(Icons.chevron_right),
                onTap: _manualCheckKeys,
              ),
              const Divider(),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.key_rounded),
                title: Text(context.l10n.keys),
                trailing: Text(
                  _totalKeysCount?.toString() ?? '—',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          _buildSectionCard(
            title: context.l10n.filtersAndDisplay,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 7,
                        children: [
                          _getKeyFilterIcon(),
                          Text(context.l10n.filter),
                        ],
                      ),
                    ),
                    Flexible(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(12),
                        value: _selectedKeyFilter,
                        dropdownColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer,
                        underline: const SizedBox(),
                        items: KeyFilterType.allValues.map((String filterType) {
                          return DropdownMenuItem<String>(
                            value: filterType,
                            child: Text(
                              KeyFilterType.getDisplayText(context, filterType),
                            ),
                          );
                        }).toList(),
                        onChanged: _updateKeyFilter,
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.showSkins),
                value: _skinSetting,
                onChanged: _toggleSkinFilter,
                secondary: const ImageIcon(AssetImage('assets/skin.png')),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.l10n.pageSize,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(context.l10n.pageSizeInfo),
                                    content: Text(
                                      context.l10n.pageSizeInfoText,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Text(context.l10n.ok),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '$_pageSize',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _pageSize.toDouble(),
                      min: 20,
                      max: 300,
                      divisions: 28,
                      label: _pageSize.toString(),
                      onChanged: (value) {
                        setState(() => _pageSize = value.round());
                      },
                      onChangeEnd: (value) => _savePageSize(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildSectionCard(
            title: context.l10n.tools,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.file_present),
                title: Text(context.l10n.customDb),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CustomDbPage(
                      searchService: widget.searchService,
                      keysService: widget.keysService,
                      pageSize: _pageSize,
                    ),
                  ),
                ),
              ),
              if (Platform.isWindows) ...[
                const Divider(),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const ImageIcon(AssetImage('assets/axe.png')),
                  title: Text(context.l10n.mcDecryptor),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => McDecryptorPage(
                        searchService: widget.searchService,
                        keysService: widget.keysService,
                        pageSize: _pageSize,
                      ),
                    ),
                  ),
                ),
              ],
              if (Platform.isAndroid) ...[
                const Divider(),
                ListTile(
                  leading: _minecraftAppIcon != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _minecraftAppIcon!,
                            width: 32,
                            height: 32,
                            gaplessPlayback: true,
                          ),
                        )
                      : Image.asset(
                          'assets/mc_icon.png',
                          width: 32,
                          height: 32,
                        ),
                  title: Text(context.l10n.minecraftPackage),
                  subtitle: Text(
                    _minecraftPackageName ?? 'com.mojang.minecraftpe',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_minecraftPackageName != null &&
                          _minecraftPackageName != 'com.mojang.minecraftpe')
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: context.l10n.resetDefaults,
                          onPressed: () async {
                            await _settingsService.setMinecraftPackageName(
                              'com.mojang.minecraftpe',
                            );
                            await MinecraftLauncher.clearSavedAppIcon();
                            setState(() {
                              _minecraftPackageName = 'com.mojang.minecraftpe';
                              _minecraftAppIcon = null;
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () async {
                    final picked =
                        await showDialog<
                          ({String packageName, Uint8List? icon})
                        >(
                          context: context,
                          builder: (_) => const AppPickerDialog(),
                        );
                    if (picked != null) {
                      await _settingsService.setMinecraftPackageName(
                        picked.packageName,
                      );
                      if (picked.icon != null) {
                        await MinecraftLauncher.saveSelectedAppIcon(
                          picked.icon!,
                        );
                      }
                      setState(() {
                        _minecraftPackageName = picked.packageName;
                        _minecraftAppIcon = picked.icon;
                      });
                    }
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
