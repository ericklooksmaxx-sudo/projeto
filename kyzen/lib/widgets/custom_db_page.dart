import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import '../models/search_result.dart';
import '../services/search_service.dart';
import 'search_result_item.dart';
import 'search_result_grid_item.dart';
import '../services/key_service.dart';
import 'package:kyzen/l10n/context_extensions.dart';

class CustomDbPage extends StatefulWidget {
  final SearchService searchService;
  final KeysService keysService;
  final int pageSize;

  const CustomDbPage({
    super.key,
    required this.searchService,
    required this.keysService,
    required this.pageSize,
  });

  @override
  State<CustomDbPage> createState() => _CustomDbPageState();
}

class _CustomDbPageState extends State<CustomDbPage> {
  int keyCount = 0;
  bool _isProcessing = false;
  bool _isLoadingData = false;
  String _statusMessage = '';
  List<SearchResult> _searchResults = [];
  List<SearchResult> _filteredResults = [];
  bool _hasResults = false;
  bool _isRefreshing = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    setState(() {
      _isLoadingData = true;
    });

    final personalKeysCount = await widget.keysService.getKeysCount(
      KeysFileType.personal,
    );

    setState(() {
      keyCount = personalKeysCount;
    });

    if (widget.searchService.getCachedResultsCount(KeysFileType.personal) > 0) {
      final searchResults = await widget.searchService.getCachedResults(
        KeysFileType.personal,
      );
      setState(() {
        _searchResults = searchResults;
        _filteredResults = searchResults;
        _hasResults = searchResults.isNotEmpty;
      });
    }

    setState(() {
      _isLoadingData = false;
    });
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Future<void> _pickAndProcessFile() async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = context.l10n.selectingFile;
      });

      PlatformFile? file = await FilePicker.pickFile();
      if (file != null && file.path != null) {
        setState(() {
          _statusMessage = context.l10n.processingFile;
        });
        final filePath = file.path!;
        await widget.searchService.processCustomKeysFile(filePath);

        final searchResults = await widget.searchService.getCachedResults(
          KeysFileType.personal,
        );

        final personalKeysCount = await widget.keysService.getKeysCount(
          KeysFileType.personal,
        );

        setState(() {
          _statusMessage = context.l10n.fileProcessed;
          keyCount = personalKeysCount;
          _searchResults = searchResults;
          _filteredResults = searchResults;
          _hasResults = searchResults.isNotEmpty;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = '';
            });
          }
        });
      } else {
        setState(() {
          _statusMessage = context.l10n.noFileSelected;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = e.toString();
        _hasResults = false;
        _searchResults.clear();
        _filteredResults.clear();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _refreshResults() async {
    try {
      setState(() {
        _isRefreshing = true;
      });

      final personalKeysCount = await widget.keysService.getKeysCount(
        KeysFileType.personal,
      );
      final searchResults = await widget.searchService.searchPersonalKeys(
        KeysFileType.personal,
      );

      setState(() {
        keyCount = personalKeysCount;
        _searchResults = searchResults;
        _filteredResults = searchResults;
        _hasResults = searchResults.isNotEmpty;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _statusMessage = '';
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = e.toString();
        _hasResults = false;
        _searchResults.clear();
        _filteredResults.clear();
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isErrorMessage =
        _statusMessage.startsWith('Exception') ||
        _statusMessage.startsWith('Error') ||
        _statusMessage.startsWith('Failed');

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.customDb),
        forceMaterialTransparency: true,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _hasResults
          ? CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: keyCount > 0 ? () {} : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                          ),
                          icon: const Icon(Icons.key),
                          label: Text('$keyCount'),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: _isProcessing ? null : _pickAndProcessFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed:
                              (_isProcessing || _isRefreshing || keyCount == 0)
                              ? null
                              : _refreshResults,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                          ),
                          child: _isRefreshing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                ),

                // Status message
                if (_statusMessage.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(
                                isErrorMessage
                                    ? Icons.error_outline
                                    : Icons.info_outline,
                                color: isErrorMessage
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _statusMessage,
                                  style: TextStyle(
                                    color: isErrorMessage
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Search bar
                SliverToBoxAdapter(child: _buildSearchBar()),

                // Results or no results message
                if (_filteredResults.isEmpty)
                  SliverFillRemaining(
                    child: Center(
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
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      final isPortrait =
                          MediaQuery.of(context).orientation ==
                          Orientation.portrait;

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

                      return SliverGrid(
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
                      );
                    },
                  ),
              ],
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: keyCount > 0 ? () {} : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                        ),
                        icon: const Icon(Icons.key),
                        label: Text('$keyCount'),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _isProcessing ? null : _pickAndProcessFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed:
                            (_isProcessing || _isRefreshing || keyCount == 0)
                            ? null
                            : _refreshResults,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                        ),
                        child: _isRefreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),

                // Status message
                if (_statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              isErrorMessage
                                  ? Icons.error_outline
                                  : Icons.info_outline,
                              color: isErrorMessage
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: isErrorMessage
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Empty state
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storage,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          keyCount > 0
                              ? context.l10n.customKeysLoaded(keyCount)
                              : context.l10n.noCustomKeysLoaded,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.importFileFormat,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
