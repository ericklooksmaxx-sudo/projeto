import 'package:material_ui/material_ui.dart';
import 'dart:math';
import '../models/search_result.dart';
import '../services/key_service.dart';
import '../services/search_service.dart';
import '../services/settings_service.dart';
import 'search_result_grid_item.dart';
import 'search_result_item.dart';
import 'package:kyzen/l10n/context_extensions.dart';

class AuthDlcPage extends StatefulWidget {
  final KeysService keysService;
  final SearchService searchService;
  final int pageSize;

  const AuthDlcPage({
    super.key,
    required this.keysService,
    required this.searchService,
    required this.pageSize,
  });

  @override
  State<AuthDlcPage> createState() => _AuthDlcPageState();
}

class _AuthDlcPageState extends State<AuthDlcPage> {
  List<SearchResult> _searchResults = [];
  List<SearchResult> _filteredResults = [];
  String _searchQuery = '';
  bool _isLoadingData = false;
  bool _isLoadingSettings = true;
  bool _hasResults = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final SettingsService _settingsService = SettingsService();
  late bool _loadSkinPersona;
  late bool _loadOnlyNewKeys;

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

    if (mounted) {
      setState(() {
        _loadSkinPersona = skinPersona;
        _loadOnlyNewKeys = onlyNewKeys;
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      final cachedResults = await widget.searchService.getCachedResults(
        KeysFileType.receipt,
        loadSkinPersona: _loadSkinPersona,
        onlyNewKeys: _loadOnlyNewKeys,
      );

      if (cachedResults.isNotEmpty) {
        setState(() {
          _searchResults = cachedResults;
          _filteredResults = cachedResults;
          _hasResults = true;
          _isLoadingData = false;
        });
      } else {
        await _loadDlcData();
      }
    } catch (e) {
      await _loadDlcData();
    }
  }

  Future<void> _loadDlcData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      final searchResults = await widget.searchService.searchPersonalKeys(
        KeysFileType.receipt,
        loadSkinPersona: _loadSkinPersona,
        onlyNewKeys: _loadOnlyNewKeys,
      );

      setState(() {
        _searchResults = searchResults;
        _filteredResults = searchResults;
        _hasResults = searchResults.isNotEmpty;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
        _errorMessage = e.toString();
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _buildResultsView() {
    if (_isLoadingData) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.errorLoadingDlcs,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadDlcData,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasResults && _loadOnlyNewKeys) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/no_content.png'),
              const SizedBox(height: 12),
              Text(
                context.l10n.nowNewdlcFound,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.nowNewDlcFoundDescription,
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

    if (!_hasResults) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/no_content.png'),
              const SizedBox(height: 12),
              Text(
                context.l10n.noDlcFound,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.noDlcAvailable,
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
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => SearchResultItem(
                item: _filteredResults[index],
                searchService: widget.searchService,
                pageSize: widget.pageSize,
              ),
              childCount: _filteredResults.length,
            ),
          );
        }

        final crossAxisCount = min(
          (MediaQuery.of(context).size.width / 350).floor(),
          5,
        );

        return SliverPadding(
          padding: const EdgeInsets.all(6),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dlcs),
        forceMaterialTransparency: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0, top: 6.0),
            child: IconButton(
              icon: Icon(
                Icons.refresh,
                color: Theme.of(context).colorScheme.primary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
              ),
              onPressed: _isLoadingSettings ? null : _loadDlcData,
              tooltip: context.l10n.refresh,
            ),
          ),
        ],
      ),
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(10, 6, 10, 12),
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
                            await _loadDlcData();
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
                            await _loadDlcData();
                          },
                          isFirst: false,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildSearchBar(),
                  ),
                ),
                _buildResultsView(),
              ],
            ),
    );
  }
}
