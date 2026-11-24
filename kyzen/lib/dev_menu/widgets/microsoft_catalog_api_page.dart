import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/settings_service.dart';
import '../services/microsoft_catalog_service.dart';
import 'json_view_page.dart';
import '../models/microsoft_catalog_models.dart';
import 'microsoft_catalog_response_panel.dart';

class MicrosoftCatalogApiPage extends StatefulWidget {
  final String? initialProductId;
  final MicrosoftCatalogMode initialMode;

  const MicrosoftCatalogApiPage({
    super.key,
    this.initialProductId,
    this.initialMode = MicrosoftCatalogMode.lookup,
  });

  @override
  State<MicrosoftCatalogApiPage> createState() =>
      _MicrosoftCatalogApiPageState();
}

class _MicrosoftCatalogApiPageState extends State<MicrosoftCatalogApiPage>
    with SingleTickerProviderStateMixin {
  late MicrosoftCatalogMode _selectedMode;
  late TabController _mobileTabController;

  // Controllers
  final _productIdController = TextEditingController(text: '9NBLGGH2JHXJ');
  final _marketController = TextEditingController(text: 'US');
  final _languagesController = TextEditingController(text: 'en-US');
  final _topController = TextEditingController(text: '25');
  final _skipController = TextEditingController(text: '0');
  final _alternateIdController = TextEditingController(text: 'SellableBy');
  final _customUrlController = TextEditingController(
    text:
        r'https://displaycatalog.mp.microsoft.com/v7/products/lookup?value=9NBLGGH2JHXJ&market=US&languages=en-US&$top=25&$skip=0&alternateId=SellableBy',
  );

  late final List<TextEditingController> _controllers = [
    _productIdController,
    _marketController,
    _languagesController,
    _topController,
    _skipController,
    _alternateIdController,
    _customUrlController,
  ];

  // Preset selection
  final _presetsScrollController = ScrollController();
  MicrosoftPlatform? _selectedPlatformFilter; // null = all
  MicrosoftCatalogPreset? _selectedPreset;

  // Request state
  bool _isLoading = false;
  MicrosoftCatalogResponse? _response;
  bool _isRawUrlMode = false;

  // Scraper progress state
  int _scrapeCurrentCandidates = 0;
  int _scrapeTotalCandidates = 0;
  int _scrapeFoundProducts = 0;
  bool _isScrapeCancelled = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    if (widget.initialProductId != null &&
        widget.initialProductId!.isNotEmpty) {
      _productIdController.text = widget.initialProductId!;
    }
    _mobileTabController = TabController(length: 2, vsync: this);
    _syncUrlPreview();
  }

  @override
  void dispose() {
    _mobileTabController.dispose();
    _presetsScrollController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncUrlPreview() {
    final host = MicrosoftCatalogService.host;
    final productId = _productIdController.text.trim();
    final market = _marketController.text.trim();
    final languages = _languagesController.text.trim();

    if (_selectedMode == MicrosoftCatalogMode.lookup) {
      final top = _topController.text.trim();
      final skip = _skipController.text.trim();
      final altId = _alternateIdController.text.trim();
      _customUrlController.text =
          'https://$host/v7/products/lookup?value=$productId&market=$market&languages=$languages&\$top=$top&\$skip=$skip&alternateId=$altId';
    } else if (_selectedMode == MicrosoftCatalogMode.scraper) {
      final altId = _alternateIdController.text.trim();
      _customUrlController.text =
          'https://$host/v7/products/lookup?value=$productId&market=$market&languages=$languages&\$top=25 (Scrape All Pages)&alternateId=$altId';
    } else if (_selectedMode == MicrosoftCatalogMode.singleProduct) {
      _customUrlController.text =
          'https://$host/v7/products/$productId?languages=$languages&market=$market';
    }
  }

  void _scrollPresets(double delta) {
    if (!_presetsScrollController.hasClients) return;
    final target = (_presetsScrollController.offset + delta).clamp(
      0.0,
      _presetsScrollController.position.maxScrollExtent,
    );
    _presetsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _applyPreset(MicrosoftCatalogPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _productIdController.text = preset.productId;
      _skipController.text = '0';
      _syncUrlPreview();
    });
  }

  Future<void> _sendRequest() async {
    final productId = _productIdController.text.trim();

    if (_selectedMode != MicrosoftCatalogMode.custom && productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a Product ID or select a preset')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _scrapeCurrentCandidates = 0;
      _scrapeTotalCandidates = 0;
      _scrapeFoundProducts = 0;
      _isScrapeCancelled = false;
    });

    try {
      final MicrosoftCatalogResponse response;

      if (_isRawUrlMode || _selectedMode == MicrosoftCatalogMode.custom) {
        response = await MicrosoftCatalogService.instance.rawRequest(
          _customUrlController.text.trim(),
        );
      } else if (_selectedMode == MicrosoftCatalogMode.scraper) {
        response = await MicrosoftCatalogService.instance.scrapeAllProducts(
          productId: productId,
          market: _marketController.text.trim(),
          languages: _languagesController.text.trim(),
          alternateId: _alternateIdController.text.trim(),
          pageSize: 25,
          onProgress: (current, total, found) {
            if (mounted) {
              setState(() {
                _scrapeCurrentCandidates = current;
                _scrapeTotalCandidates = total;
                _scrapeFoundProducts = found;
              });
            }
          },
          isCancelled: () => _isScrapeCancelled,
        );
      } else if (_selectedMode == MicrosoftCatalogMode.lookup) {
        final top = int.tryParse(_topController.text.trim()) ?? 25;
        final skip = int.tryParse(_skipController.text.trim()) ?? 0;

        response = await MicrosoftCatalogService.instance.lookupProducts(
          productId: productId,
          market: _marketController.text.trim(),
          languages: _languagesController.text.trim(),
          top: top,
          skip: skip,
          alternateId: _alternateIdController.text.trim(),
        );
      } else {
        response = await MicrosoftCatalogService.instance.getProductDetails(
          productId: productId,
          market: _marketController.text.trim(),
          languages: _languagesController.text.trim(),
        );
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _response = response;
      });

      // If scraper mode and success, auto-save to Downloads folder
      if (_selectedMode == MicrosoftCatalogMode.scraper && response.isSuccess) {
        await _autoSaveScrapedFile(response);
      }

      // On mobile switch to Response tab
      if (_mobileTabController.index == 0) {
        _mobileTabController.animateTo(1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _response = MicrosoftCatalogResponse.fromHttp(
          statusCode: 500,
          durationMs: 0,
          url: _customUrlController.text,
          rawString: '{"error": "${e.toString()}"}',
          errorMessage: e.toString(),
        );
      });
      if (_mobileTabController.index == 0) {
        _mobileTabController.animateTo(1);
      }
    }
  }

  Future<void> _autoSaveScrapedFile(MicrosoftCatalogResponse resp) async {
    try {
      final downloadPath = await SettingsService.instance.getDownloadPath();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final prodId = _productIdController.text.trim().replaceAll(
        RegExp(r'[^\w\.-]'),
        '_',
      );
      final fileName = 'microsoft_catalog_scrape_${prodId}_$timestamp.json';
      final filePath = '$downloadPath/$fileName';

      final file = File(filePath);
      await file.writeAsString(resp.rawString, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-saved ${resp.products.length} products to $fileName',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-save to download folder failed: $e')),
      );
    }
  }

  void _paginate(int delta) {
    final currentSkip = int.tryParse(_skipController.text.trim()) ?? 0;
    final top = int.tryParse(_topController.text.trim()) ?? 25;
    final newSkip = (currentSkip + (delta * top)).clamp(0, 999999);
    setState(() {
      _skipController.text = newSkip.toString();
      _syncUrlPreview();
    });
    _sendRequest();
  }

  void _inspectSingleProduct(String productId) {
    setState(() {
      _selectedMode = MicrosoftCatalogMode.singleProduct;
      _productIdController.text = productId;
      _syncUrlPreview();
    });
    _sendRequest();
  }

  Future<void> _copyResponseJson() async {
    if (_response == null) return;
    await Clipboard.setData(ClipboardData(text: _response!.rawString));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Response JSON copied to clipboard')),
    );
  }

  Future<void> _saveResponseToFile() async {
    if (_response == null) return;

    try {
      final downloadPath = await SettingsService.instance.getDownloadPath();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final modeName = _selectedMode.name;
      final prodId = _productIdController.text.trim().replaceAll(
        RegExp(r'[^\w\.-]'),
        '_',
      );
      final fileName =
          'microsoft_catalog_${modeName}_${prodId}_$timestamp.json';
      final filePath = '$downloadPath/$fileName';

      final file = File(filePath);
      await file.writeAsString(_response!.rawString, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $fileName')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
    }
  }

  void _openFullscreenJson() {
    if (_response == null) return;
    final title =
        'Microsoft Catalog (${_response!.statusCode}) - ${_productIdController.text}';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JsonViewPage(
          title: title,
          json: _response!.json,
          rawJson: _response!.json == null ? _response!.rawString : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Microsoft Catalog API',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              // Presets Dialog button
              IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: 'Browse Presets',
                onPressed: _showPresetsModal,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reset Fields',
                onPressed: () {
                  setState(() {
                    _productIdController.text = '9NBLGGH2JHXJ';
                    _marketController.text = 'US';
                    _languagesController.text = 'en-US';
                    _topController.text = '25';
                    _skipController.text = '0';
                    _alternateIdController.text = 'SellableBy';
                    _selectedPreset = null;
                    _syncUrlPreview();
                  });
                },
              ),
            ],
            bottom: isDesktop
                ? null
                : TabBar(
                    controller: _mobileTabController,
                    tabs: [
                      const Tab(
                        icon: Icon(Icons.call_made, size: 18),
                        text: 'Request',
                      ),
                      Tab(
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.call_received, size: 18),
                            if (_response != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _response!.isSuccess
                                      ? Colors.green
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_response!.statusCode}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        text: 'Response',
                      ),
                    ],
                  ),
          ),
          body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left column, rq config
        Expanded(
          flex: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              children: [
                _buildEndpointBar(),
                const Divider(height: 1),
                Expanded(child: _buildRequestConfigPanel()),
              ],
            ),
          ),
        ),

        // Right column, rsp viewer
        Expanded(flex: 52, child: _buildResponsePanelWidget()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _mobileTabController,
      children: [
        // Tab 1 Request
        Column(
          children: [
            _buildEndpointBar(),
            const Divider(height: 1),
            Expanded(child: _buildRequestConfigPanel()),
          ],
        ),

        // Tab 2 Response
        _buildResponsePanelWidget(),
      ],
    );
  }

  Widget _buildResponsePanelWidget() {
    return MicrosoftCatalogResponsePanel(
      isLoading: _isLoading,
      activeEndpoint: _customUrlController.text,
      response: _response,
      onCopyResponse: _copyResponseJson,
      onSaveResponse: _saveResponseToFile,
      onOpenFullscreen: _openFullscreenJson,
      onInspectSingleProduct: _inspectSingleProduct,
    );
  }

  Widget _buildEndpointBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'GET',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Mode Picker Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MicrosoftCatalogMode>(
                      value: _selectedMode,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      items: MicrosoftCatalogMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(
                            mode.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (mode) {
                        if (mode != null) {
                          setState(() {
                            _selectedMode = mode;
                            _syncUrlPreview();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send / Scrape Action Button
              FilledButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _selectedMode == MicrosoftCatalogMode.scraper
                            ? Icons.download_rounded
                            : Icons.send_rounded,
                        size: 16,
                      ),
                label: Text(
                  _isLoading
                      ? (_selectedMode == MicrosoftCatalogMode.scraper
                            ? 'Scraping'
                            : 'Fetching')
                      : (_selectedMode == MicrosoftCatalogMode.scraper
                            ? 'Scrape'
                            : 'Send'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _sendRequest,
              ),
            ],
          ),

          // Custom URL textfield if custom mode
          if (_selectedMode == MicrosoftCatalogMode.custom) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customUrlController,
              decoration: const InputDecoration(
                labelText: 'Direct Microsoft Catalog URL',
                hintText: 'https://displaycatalog.mp.microsoft.com/v7/...',
                prefixIcon: Icon(Icons.link, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestConfigPanel() {
    if (_selectedMode == MicrosoftCatalogMode.custom) {
      return _buildCustomUrlPanel();
    }

    return Column(
      children: [
        // Mode toggle, Form and Raw URL
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Parameters'),
                  icon: Icon(Icons.tune, size: 16),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Raw URL Preview'),
                  icon: Icon(Icons.link, size: 16),
                ),
              ],
              selected: {_isRawUrlMode},
              onSelectionChanged: (set) {
                setState(() {
                  _isRawUrlMode = set.first;
                  _syncUrlPreview();
                });
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey<bool>(_isRawUrlMode),
              child: _isRawUrlMode
                  ? _buildCustomUrlPanel()
                  : _buildStructuredParametersForm(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStructuredParametersForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Platform filter and presets section
        _buildPresetsSection(),

        const SizedBox(height: 16),

        TextField(
          controller: _productIdController,
          decoration: InputDecoration(
            labelText: _selectedMode == MicrosoftCatalogMode.scraper
                ? 'Product ID to Scrape'
                : (_selectedMode == MicrosoftCatalogMode.lookup
                      ? 'Product ID (Lookup Value)'
                      : 'Product ID (Single Product)'),
            hintText: 'e.g. 9NBLGGH2JHXJ',
            prefixIcon: const Icon(Icons.tag, size: 18),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.paste, size: 18),
                  tooltip: 'Paste from clipboard',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.isNotEmpty) {
                      setState(() {
                        _productIdController.text = data.text!.trim();
                        _selectedPreset = null;
                        _syncUrlPreview();
                      });
                    }
                  },
                ),
                if (_productIdController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear Product ID',
                    onPressed: () {
                      setState(() {
                        _productIdController.clear();
                        _selectedPreset = null;
                        _syncUrlPreview();
                      });
                    },
                  ),
              ],
            ),
            border: const OutlineInputBorder(),
            helperText: _selectedMode == MicrosoftCatalogMode.scraper
                ? 'Scrapes all pages for this ID or selected preset and auto-saves to Downloads'
                : (_selectedMode == MicrosoftCatalogMode.lookup
                      ? 'Lookup sellable items (Windows and Xbox titles)'
                      : 'Single product details by Product ID'),
          ),
          onChanged: (val) {
            setState(() {
              if (_selectedPreset != null &&
                  _selectedPreset!.productId != val.trim()) {
                _selectedPreset = null;
              }
              _syncUrlPreview();
            });
          },
        ),

        const SizedBox(height: 14),

        // Market and lang row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _marketController,
                decoration: const InputDecoration(
                  labelText: 'Market',
                  hintText: 'US',
                  prefixIcon: Icon(Icons.public, size: 18),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _syncUrlPreview(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _languagesController,
                decoration: const InputDecoration(
                  labelText: 'Languages',
                  hintText: 'en-US',
                  prefixIcon: Icon(Icons.language, size: 18),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _syncUrlPreview(),
              ),
            ),
          ],
        ),

        // Lookup specific parameters
        if (_selectedMode == MicrosoftCatalogMode.lookup) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _topController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: r'$top (Limit)',
                    hintText: '25',
                    prefixIcon: Icon(Icons.filter_list, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _syncUrlPreview(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _skipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: r'$skip (Offset)',
                    hintText: '0',
                    prefixIcon: Icon(Icons.fast_forward, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _syncUrlPreview(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          TextField(
            controller: _alternateIdController,
            decoration: const InputDecoration(
              labelText: 'alternateId',
              hintText: 'SellableBy',
              prefixIcon: Icon(Icons.alt_route, size: 18),
              border: OutlineInputBorder(),
              helperText: 'Default: SellableBy',
            ),
            onChanged: (_) => _syncUrlPreview(),
          ),

          const SizedBox(height: 14),

          // Pagination quick buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Prev Page'),
                  onPressed: () => _paginate(-1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Next Page'),
                  onPressed: () => _paginate(1),
                ),
              ),
            ],
          ),
        ],

        // Scraper mode specific parameters & status
        if (_selectedMode == MicrosoftCatalogMode.scraper) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _alternateIdController,
            decoration: const InputDecoration(
              labelText: 'alternateId',
              hintText: 'SellableBy',
              prefixIcon: Icon(Icons.alt_route, size: 18),
              border: OutlineInputBorder(),
              helperText: 'Default: SellableBy',
            ),
            onChanged: (_) => _syncUrlPreview(),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            _buildScraperProgressCard(),
          ],
        ],

        const SizedBox(height: 20),

        // Execute Button
        if (!(_isLoading && _selectedMode == MicrosoftCatalogMode.scraper))
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _selectedMode == MicrosoftCatalogMode.scraper
                          ? Icons.download_rounded
                          : Icons.play_arrow_rounded,
                    ),
              label: Text(
                _isLoading
                    ? 'Executing Query...'
                    : _selectedMode == MicrosoftCatalogMode.scraper
                    ? 'Start Scrape'
                    : (_selectedMode == MicrosoftCatalogMode.lookup
                          ? 'Lookup'
                          : 'Fetch Product Details'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _isLoading ? null : _sendRequest,
            ),
          ),
      ],
    );
  }

  Widget _buildScraperProgressCard() {
    final percent = _scrapeTotalCandidates > 0
        ? (_scrapeCurrentCandidates / _scrapeTotalCandidates).clamp(0.0, 1.0)
        : null;

    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Scraping Microsoft Catalog...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                if (percent != null)
                  Text(
                    '${(percent * 100).toInt()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: percent, minHeight: 6),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _scrapeTotalCandidates > 0
                      ? 'Items: $_scrapeCurrentCandidates / $_scrapeTotalCandidates'
                      : 'Connecting to catalog...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$_scrapeFoundProducts products found',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton.icon(
                icon: Icon(
                  _isScrapeCancelled
                      ? Icons.hourglass_top
                      : Icons.cancel_outlined,
                  size: 14,
                ),
                label: Text(
                  _isScrapeCancelled ? 'Cancelling Scrape...' : 'Cancel Scrape',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: _isScrapeCancelled
                    ? null
                    : () {
                        setState(() {
                          _isScrapeCancelled = true;
                        });
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsSection() {
    final filteredPresets = _selectedPlatformFilter == null
        ? microsoftCatalogPresets
        : microsoftCatalogPresets
              .where((p) => p.platform == _selectedPlatformFilter)
              .toList();

    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Presets',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                // Filter chips
                _buildFilterChip('All', null),
                const SizedBox(width: 4),
                _buildFilterChip('Windows', MicrosoftPlatform.windows),
                const SizedBox(width: 4),
                _buildFilterChip('Xbox', MicrosoftPlatform.xbox),
              ],
            ),
            const SizedBox(height: 8),

            // Horizontally scrolling chips with desktop mouse drag and navigation buttons
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  tooltip: 'Previous Presets',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: () => _scrollPresets(-200),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: SingleChildScrollView(
                      controller: _presetsScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filteredPresets.map((preset) {
                          final isSelected =
                              _productIdController.text.trim() ==
                              preset.productId;

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              showCheckmark: false,
                              avatar: Icon(
                                preset.platform == MicrosoftPlatform.windows
                                    ? Icons.window
                                    : Icons.sports_esports,
                                size: 14,
                              ),
                              label: Text(
                                preset.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: isSelected,
                              onSelected: (_) => _applyPreset(preset),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  tooltip: 'Next Presets',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: () => _scrollPresets(200),
                ),
              ],
            ),
            if (_selectedPreset != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedPreset!.platform == MicrosoftPlatform.windows
                          ? Icons.window
                          : Icons.sports_esports,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_selectedPreset!.packageIdentifier} • ${_selectedPreset!.description}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, MicrosoftPlatform? platform) {
    final isSelected = _selectedPlatformFilter == platform;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlatformFilter = platform;
        });
        if (_presetsScrollController.hasClients) {
          _presetsScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomUrlPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Direct Request URL',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _customUrlController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://displaycatalog.mp.microsoft.com/v7/...',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.send_rounded),
            label: const Text('Execute URL'),
            onPressed: _isLoading ? null : _sendRequest,
          ),
        ],
      ),
    );
  }

  void _showPresetsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/microslop.png',
                        width: 22,
                        height: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Windows & Xbox Presets',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: microsoftCatalogPresets.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = microsoftCatalogPresets[index];
                      return ListTile(
                        leading: Icon(
                          item.platform == MicrosoftPlatform.windows
                              ? Icons.window
                              : Icons.sports_esports,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID: ${item.productId}  •  ${item.packageIdentifier}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              item.description,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _applyPreset(item);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
