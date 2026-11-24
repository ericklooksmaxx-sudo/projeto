import 'dart:math';
import 'package:material_ui/material_ui.dart';
import '../services/key_service.dart';
import '../services/search_service.dart';
import 'search_result_grid_item.dart';
import 'search_result_item.dart';
import '../decrypt/entitlement.dart';
import '../models/entitlement_models.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import '../services/settings_service.dart';

class McDecryptorPage extends StatefulWidget {
  final KeysService keysService;
  final SearchService searchService;
  final int pageSize;

  const McDecryptorPage({
    super.key,
    required this.keysService,
    required this.searchService,
    required this.pageSize,
  });

  @override
  State<McDecryptorPage> createState() => _McDecryptorPageState();
}

class _McDecryptorPageState extends State<McDecryptorPage> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoadingData = false;
  bool _hasResults = false;
  List<dynamic> _searchResults = [];
  List<dynamic> _filteredResults = [];
  EntitlementResult? _entitlementResult;
  bool _showErrorSection = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late bool _loadSkinPersona;
  late bool _loadOnlyNewKeys;
  late bool _exportOnlyNewKeys;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadSettings();
    await _loadInitialData();
  }

  Future<void> _loadSettings() async {
    final skinPersona = await _settingsService.getLoadSkinPersona();
    final onlyNewKeys = await _settingsService.getLoadOnlyNewKeys();
    final exportOnlyNewKeys = await _settingsService.getKeyExport();

    if (mounted) {
      setState(() {
        _loadSkinPersona = skinPersona;
        _loadOnlyNewKeys = onlyNewKeys;
        _exportOnlyNewKeys = exportOnlyNewKeys;
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    _entitlementResult = await Entitlement.getLastResult();

    final cachedResults = await widget.searchService.getCachedResults(
      KeysFileType.entitlement,
      loadSkinPersona: _loadSkinPersona,
      onlyNewKeys: _loadOnlyNewKeys,
    );

    if (mounted) {
      setState(() {
        if (cachedResults.isNotEmpty) {
          _searchResults = cachedResults;
          _filteredResults = cachedResults;
          _hasResults = true;
        }
      });
    }
  }

  Future<void> _searchEntitlementKeys() async {
    setState(() {
      _isLoadingData = true;
      _hasResults = false;
    });

    try {
      final searchResults = await widget.searchService.searchPersonalKeys(
        KeysFileType.entitlement,
        loadSkinPersona: _loadSkinPersona,
        onlyNewKeys: _loadOnlyNewKeys,
      );

      setState(() {
        _searchResults = searchResults;
        _filteredResults = searchResults;
        _hasResults = searchResults.isNotEmpty;
        _isLoadingData = false;
        _searchQuery = '';
        _searchController.clear();
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  void _filterResults(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredResults = _searchResults;
      } else {
        _filteredResults = _searchResults.where((item) {
          final title = item.title.toLowerCase();
          final packType = item.packType.toLowerCase();
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) || packType.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _saveEntitlementKeys() async {
    try {
      final formattedKeys = await widget.keysService.formatKeysForSharing(
        KeysFileType.entitlement,
      );

      if (formattedKeys.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.noNewKeysFoundToSave)),
          );
        }
        return;
      }

      await widget.keysService.saveKeys(
        KeysFileType.entitlement,
        formattedKeys,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.keysSavedSuccessfully),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.failedToSaveKeys(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mcDecryptor),
        forceMaterialTransparency: true,
      ),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildControlPanel()),
                if (_hasResults) SliverToBoxAdapter(child: _buildSearchBar()),
                if (_entitlementResult != null &&
                    _entitlementResult!.hasErrors &&
                    _showErrorSection)
                  SliverToBoxAdapter(child: _buildErrorSection()),
                _buildResultsView(),
              ],
            ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      margin: const EdgeInsets.only(top: 10, right: 16, left: 16, bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.key, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.entitlementKeys,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.searchBoughContent,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Save button - only show if keys were extracted
                if (_entitlementResult != null &&
                    _entitlementResult!.totalKeysExtracted > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: _saveEntitlementKeys,
                      icon: const Icon(Icons.save),
                      label: Text(context.l10n.saveKeys),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                // Search/Refresh button
                ElevatedButton.icon(
                  onPressed: _isLoadingData ? null : _searchEntitlementKeys,
                  icon: const Icon(Icons.search),
                  label: Text(
                    _hasResults
                        ? context.l10n.refresh
                        : context.l10n.searchKeys,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 4),
            _buildSettingsSwitches(),
            if (_entitlementResult != null &&
                _entitlementResult!.hasSuccess) ...[
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),
              _buildProcessingResultsContent(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSwitches() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            title: context.l10n.loadSkinPersona,
            subtitle: context.l10n.descriptionSkinPersona,
            icon: Icons.person_outline,
            value: _loadSkinPersona,
            onChanged: (value) async {
              setState(() {
                _loadSkinPersona = value;
              });
              await _settingsService.setLoadSkinPersona(value);
            },
            isFirst: true,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _buildSwitchTile(
            title: context.l10n.loadOnlyNewKeys,
            subtitle: context.l10n.descriptionLoadOnlyNewKeys,
            icon: Icons.new_releases_outlined,
            value: _loadOnlyNewKeys,
            onChanged: (value) async {
              setState(() {
                _loadOnlyNewKeys = value;
              });
              await _settingsService.setLoadOnlyNewKeys(value);
            },
            isFirst: false,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _buildSwitchTile(
            title: context.l10n.exportNewKeys,
            subtitle: context.l10n.descriptionExportNewKeys,
            icon: Icons.save,
            value: _exportOnlyNewKeys,
            onChanged: (value) async {
              setState(() {
                _exportOnlyNewKeys = value;
              });
              await _settingsService.setKeyExport(value);
            },
            isFirst: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isFirst,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: !isFirst ? const Radius.circular(12) : Radius.zero,
      ), // this is just when u hover it and u see the ink well
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SearchBar(
        controller: _searchController,
        hintText: context.l10n.hintText,
        leading: const Icon(Icons.search),
        trailing: _searchQuery.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterResults('');
                  },
                ),
              ]
            : null,
        onChanged: _filterResults,
        elevation: const WidgetStatePropertyAll(2),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildProcessingResultsContent() {
    final result = _entitlementResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.processedEntitlementKeys(
                result.successfulFiles.length,
                result.totalKeysExtracted,
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...result.successfulFiles.map(
          (file) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0, left: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.filePath,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _localizeError(String error) {
    switch (error) {
      case 'minecraftNotInstalled':
        return context.l10n.minecraftNotInstalled;
      default:
        return error;
    }
  }

  Widget _buildErrorSection() {
    final result = _entitlementResult!;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
      padding: const EdgeInsets.all(13.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.processingError,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                onPressed: () {
                  setState(() {
                    _showErrorSection = false;
                  });
                },
                tooltip: context.l10n.dismiss,
              ),
            ],
          ),
          ...result.errors.map(
            (error) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '• ${_localizeError(error)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
          if (result.failedFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.failedFiles,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...result.failedFiles.map(
              (failed) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0, left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failed.filePath,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '  → ${_localizeError(failed.reason)}',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    if (_isLoadingData) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasResults) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.noResultsYet,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.clickSearchKeysToLoadContent,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredResults.isEmpty && _searchQuery.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.noResultsFound,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.tryadifferentSearch,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Builder(
      builder: (context) {
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;

        if (isPortrait) {
          return SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => SearchResultItem(
                  item: _filteredResults[index],
                  searchService: widget.searchService,
                  pageSize: widget.pageSize,
                ),
                childCount: _filteredResults.length,
              ),
            ),
          );
        }

        final crossAxisCount = min(
          (MediaQuery.of(context).size.width / 350).floor(),
          5,
        );

        return SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => SearchResultGridItem(
                item: _filteredResults[index],
                searchService: widget.searchService,
                pageSize: widget.pageSize,
              ),
              childCount: _filteredResults.length,
            ),
          ),
        );
      },
    );
  }
}
