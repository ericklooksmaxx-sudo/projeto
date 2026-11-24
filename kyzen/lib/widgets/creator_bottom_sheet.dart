import 'package:material_ui/material_ui.dart';
import '../models/search_result.dart';
import '../services/search_service.dart';
import '../services/settings_service.dart';
import '../services/key_filter.dart';
import 'search_result_item.dart';
import 'package:kyzen/l10n/context_extensions.dart';

class CreatorStatsBottomSheet extends StatefulWidget {
  final CreatorResult creator;
  final SearchService searchService;
  final int pageSize;

  const CreatorStatsBottomSheet({
    super.key,
    required this.creator,
    required this.searchService,
    required this.pageSize,
  });

  @override
  State<CreatorStatsBottomSheet> createState() =>
      _CreatorStatsBottomSheetState();
}

class _CreatorStatsBottomSheetState extends State<CreatorStatsBottomSheet> {
  Map<String, dynamic>? _statistics;
  List<SearchResult> _itemResults = [];
  bool _isLoading = true;
  bool _isLoadingItems = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _selectedContentType;
  String _searchTerm = "";
  String _keyFilter = KeyFilterType.showAll;

  // Pagination variables
  int _totalItemCount = 0;
  int _currentSkip = 0;
  static const int _maxSkip = 10000;

  late ScrollController _scrollController;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchController = TextEditingController();
    _loadCreatorStatistics();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadMoreItems();
    }
  }

  void _checkAndAutoLoadMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedContentType == null ||
          !_hasMoreItems() ||
          _isLoadingItems ||
          _isLoadingMore) {
        return;
      }
      if (!_scrollController.hasClients) return;

      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200) {
        _loadMoreItems();
      }
    });
  }

  Future<void> _loadCreatorStatistics() async {
    try {
      final stats = await widget.searchService.getCreatorStatistics(
        widget.creator.filterId,
      );
      if (!mounted) return;
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        debugPrint("Error: $_error");
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCreatorItems(String contentType) async {
    final keyFilter = await SettingsService.instance.getKeyFilter();
    _keyFilter = keyFilter;
    if (keyFilter == KeyFilterType.onlyNotAvailable &&
        (contentType == 'skin' ||
            contentType == 'persona' ||
            contentType == 'capes')) {
      setState(() {
        _isLoadingItems = false;
        _selectedContentType = contentType;
        _itemResults = [];
        _currentSkip = 0;
        _totalItemCount = 0;
        _searchTerm = "";
        _searchController.clear();
      });
      return;
    }

    setState(() {
      _isLoadingItems = true;
      _selectedContentType = contentType;
      _itemResults = [];
      _currentSkip = 0;
      _totalItemCount = 0;
      _searchTerm = "";
      _searchController.clear();
    });

    try {
      final result = await widget.searchService.searchCreatorItemsPaginated(
        widget.creator.filterId,
        contentType: contentType,
        searchTerm: "",
        top: widget.pageSize,
      );

      if (!mounted || _selectedContentType != contentType) return;

      var items = (result['items'] as List<dynamic>).cast<SearchResult>();
      final totalCount = result['totalCount'] as int;
      var skip = widget.pageSize;

      while (items.isEmpty && skip < totalCount && skip < _maxSkip) {
        final nextResult = await widget.searchService
            .searchCreatorItemsPaginated(
              widget.creator.filterId,
              contentType: contentType,
              searchTerm: "",
              skip: skip,
              top: widget.pageSize,
            );

        if (!mounted || _selectedContentType != contentType) return;

        final nextItems = (nextResult['items'] as List<dynamic>)
            .cast<SearchResult>();
        items.addAll(nextItems);
        skip += widget.pageSize;
      }

      setState(() {
        _itemResults = items;
        _totalItemCount = totalCount;
        _currentSkip = skip;
        _isLoadingItems = false;
      });

      _checkAndAutoLoadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        debugPrint("Error: $_error");
        _isLoadingItems = false;
      });
    }
  }

  Future<void> _searchItems(String searchTerm) async {
    if (_selectedContentType == null) return;
    final currentContentType = _selectedContentType!;

    final keyFilter = await SettingsService.instance.getKeyFilter();
    _keyFilter = keyFilter;
    if (keyFilter == KeyFilterType.onlyNotAvailable &&
        (currentContentType == 'skin' ||
            currentContentType == 'persona' ||
            currentContentType == 'capes')) {
      setState(() {
        _isLoadingItems = false;
        _itemResults = [];
        _currentSkip = 0;
        _totalItemCount = 0;
        _searchTerm = searchTerm;
      });
      return;
    }

    setState(() {
      _isLoadingItems = true;
      _itemResults = [];
      _currentSkip = 0;
      _totalItemCount = 0;
      _searchTerm = searchTerm;
    });

    try {
      final result = await widget.searchService.searchCreatorItemsPaginated(
        widget.creator.filterId,
        contentType: currentContentType,
        searchTerm: searchTerm,
        top: widget.pageSize,
      );

      if (!mounted ||
          _selectedContentType != currentContentType ||
          _searchTerm != searchTerm) {
        return;
      }

      var items = (result['items'] as List<dynamic>).cast<SearchResult>();
      final totalCount = result['totalCount'] as int;
      var skip = widget.pageSize;

      while (items.isEmpty && skip < totalCount && skip < _maxSkip) {
        final nextResult = await widget.searchService
            .searchCreatorItemsPaginated(
              widget.creator.filterId,
              contentType: currentContentType,
              searchTerm: searchTerm,
              skip: skip,
              top: widget.pageSize,
            );

        if (!mounted ||
            _selectedContentType != currentContentType ||
            _searchTerm != searchTerm) {
          return;
        }

        final nextItems = (nextResult['items'] as List<dynamic>)
            .cast<SearchResult>();
        items.addAll(nextItems);
        skip += widget.pageSize;
      }

      setState(() {
        _itemResults = items;
        _totalItemCount = totalCount;
        _currentSkip = skip;
        _isLoadingItems = false;
      });

      _checkAndAutoLoadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        debugPrint("Error: $_error");
        _isLoadingItems = false;
      });
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || _selectedContentType == null || !_hasMoreItems()) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final currentContentType = _selectedContentType;
    final currentSearchTerm = _searchTerm;
    final currentSkip = _currentSkip;

    try {
      final result = await widget.searchService.searchCreatorItemsPaginated(
        widget.creator.filterId,
        contentType: currentContentType!,
        searchTerm: currentSearchTerm,
        skip: currentSkip,
        top: widget.pageSize,
      );

      if (!mounted ||
          _selectedContentType != currentContentType ||
          _searchTerm != currentSearchTerm) {
        return;
      }

      setState(() {
        _itemResults.addAll(
          (result['items'] as List<dynamic>).cast<SearchResult>(),
        );
        _currentSkip += widget.pageSize;
        _isLoadingMore = false;
      });

      _checkAndAutoLoadMore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.failedLoadMoreItems(e.toString())),
          ),
        );
      }
    }
  }

  void _goBackToStats() {
    setState(() {
      _selectedContentType = null;
      _itemResults = [];
      _currentSkip = 0;
      _totalItemCount = 0;
      _searchTerm = "";
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Row(
                  children: [
                    if (_selectedContentType != null)
                      IconButton(
                        onPressed: _goBackToStats,
                        icon: const Icon(Icons.arrow_back, size: 20),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      radius: 20,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.creator.filterName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _selectedContentType != null
                                ? (_totalItemCount > 0
                                      ? context.l10n
                                            .creatorItemsWithTypeAndCount(
                                              _selectedContentType!
                                                  .capitalize(),
                                              _totalItemCount,
                                            )
                                      : context.l10n.creatorItemsWithType(
                                          _selectedContentType!.capitalize(),
                                        ))
                                : context.l10n.creatorItemsDefault,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: _selectedContentType != null
                    ? _buildItemResults()
                    : _buildContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              context.l10n.failedLoadStatistic,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadCreatorStatistics();
              },
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_statistics == null) {
      return Center(child: Text(context.l10n.noStatistic));
    }

    final counts = _statistics!['counts'] as Map<String, int>;

    final statItems = [
      _StatItem(
        context.l10n.addons,
        counts['addon'] ?? 0,
        'assets/addon.png',
        'addon',
      ),
      _StatItem(
        context.l10n.skins,
        counts['skin'] ?? 0,
        'assets/skin.png',
        'skin',
      ),
      _StatItem(
        context.l10n.textures,
        counts['texture'] ?? 0,
        'assets/texture.png',
        'texture',
      ),
      _StatItem(
        context.l10n.worlds,
        counts['world'] ?? 0,
        'assets/world.png',
        'world',
      ),
      _StatItem(
        context.l10n.mashups,
        counts['mashup'] ?? 0,
        'assets/mashup.png',
        'mashup',
      ),
      _StatItem(
        context.l10n.persona,
        counts['persona'] ?? 0,
        'assets/persona.png',
        'persona',
      ),
      _StatItem(
        context.l10n.capes,
        counts['capes'] ?? 0,
        'assets/cape.png',
        'capes',
      ),
    ].where((item) => item.count > 0).toList();

    if (statItems.isEmpty) {
      return Center(child: Text(context.l10n.noItemCreator));
    }
    final spacing = (MediaQuery.of(context).size.width * 0.035).clamp(
      10.0,
      16.0,
    );

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics grid
          Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth.clamp(0.0, 600.0);
                  final cardWidth = (maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.center,
                    children: statItems
                        .map(
                          (item) => SizedBox(
                            width: cardWidth,
                            child: AspectRatio(
                              aspectRatio: 1.2,
                              child: _buildStatCard(
                                item.title,
                                item.count,
                                item.iconPath,
                                item.contentType,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemResults() {
    if (_selectedContentType != null &&
        _hasMoreItems() &&
        !_isLoadingItems &&
        !_isLoadingMore) {
      _checkAndAutoLoadMore();
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _isLoadingItems
              ? const Center(child: CircularProgressIndicator())
              : _itemResults.isEmpty
              ? (_keyFilter == KeyFilterType.onlyNotAvailable &&
                        (_selectedContentType == 'skin' ||
                            _selectedContentType == 'persona' ||
                            _selectedContentType == 'capes'))
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.skinAndPersonaAlwaysAvailable,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.changeFilterInSettingsNotice,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.noResultsFound,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount:
                      _itemResults.length +
                      (_hasMoreItems() || _isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _itemResults.length) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        child: _isLoadingMore
                            ? const CircularProgressIndicator()
                            : const SizedBox.shrink(),
                      );
                    }

                    return SearchResultItem(
                      item: _itemResults[index],
                      searchService: widget.searchService,
                      pageSize: widget.pageSize,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SearchBar(
        controller: _searchController,
        hintText: context.l10n.hintText,
        leading: const Icon(Icons.search),
        trailing: _searchTerm.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchTerm = '';
                    });
                    _searchItems('');
                  },
                ),
              ]
            : null,
        onChanged: (value) {
          setState(() {
            _searchTerm = value;
          });
        },
        onSubmitted: _searchItems,
        elevation: const WidgetStatePropertyAll(2),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  bool _hasMoreItems() {
    return _currentSkip < _totalItemCount && _currentSkip < _maxSkip;
  }

  Widget _buildStatCard(
    String title,
    int count,
    String iconPath,
    String contentType,
  ) {
    return GestureDetector(
      onTap: () => _loadCreatorItems(contentType),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _loadCreatorItems(contentType),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Image.asset(
                      iconPath,
                      width: 64,
                      height: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.8),
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported, size: 64);
                      },
                    ),
                  ),
                  const SizedBox(height: 3),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem {
  final String title;
  final int count;
  final String iconPath;
  final String contentType;

  _StatItem(this.title, this.count, this.iconPath, this.contentType);
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
