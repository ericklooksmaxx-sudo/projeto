import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';

import 'json_view_page.dart';
import '../models/microsoft_catalog_models.dart';

class MicrosoftCatalogResponsePanel extends StatefulWidget {
  final bool isLoading;
  final String activeEndpoint;
  final MicrosoftCatalogResponse? response;
  final VoidCallback onCopyResponse;
  final VoidCallback onSaveResponse;
  final VoidCallback onOpenFullscreen;
  final void Function(String productId)? onInspectSingleProduct;

  const MicrosoftCatalogResponsePanel({
    super.key,
    required this.isLoading,
    required this.activeEndpoint,
    this.response,
    required this.onCopyResponse,
    required this.onSaveResponse,
    required this.onOpenFullscreen,
    this.onInspectSingleProduct,
  });

  @override
  State<MicrosoftCatalogResponsePanel> createState() =>
      _MicrosoftCatalogResponsePanelState();
}

class _MicrosoftCatalogResponsePanelState
    extends State<MicrosoftCatalogResponsePanel> {
  int _activeSubTab = 0; // 0 Products, 1 JSON, 2 Request Info
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void didUpdateWidget(covariant MicrosoftCatalogResponsePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.response != widget.response) {
      _searchController.clear();
      _searchQuery = '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Fetching from Microsoft Catalog...',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              widget.activeEndpoint,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final resp = widget.response;
    if (resp == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildStatusBar(resp),
        const Divider(height: 1),
        _buildSubTabBar(resp),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey<int>(_activeSubTab),
              child: _buildActiveTabContent(resp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/microslop.png', width: 56, height: 56),
            ),
            const SizedBox(height: 20),
            Text(
              'Microsoft Display Catalog Explorer',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                'Lookup sellable DLCs, packages for Windows & Xbox titles',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildTipChip(Icons.search, 'Catalog Lookup'),
                _buildTipChip(Icons.inventory_2, 'Single Product Details'),
                _buildTipChip(Icons.window, 'Windows Titles'),
                _buildTipChip(Icons.sports_esports, 'Xbox Titles'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusBar(MicrosoftCatalogResponse resp) {
    final isSuccess = resp.isSuccess;
    final statusColor = isSuccess ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status code pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${resp.statusCode} ${resp.statusCode == 200 ? 'OK' : 'Error'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Count pill
                  if (resp.totalResultCount != null) ...[
                    const SizedBox(width: 8),
                    _buildMetaPill(
                      Icons.format_list_numbered,
                      'Total: ${resp.totalResultCount}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Actions
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy JSON Response',
            onPressed: widget.onCopyResponse,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.download, size: 18),
            tooltip: 'Save JSON to Downloads',
            onPressed: widget.onSaveResponse,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 20),
            tooltip: 'Fullscreen JSON Viewer',
            onPressed: widget.onOpenFullscreen,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabBar(MicrosoftCatalogResponse resp) {
    final productsCount = resp.products.length;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton(0, 'Products ($productsCount)', Icons.grid_view),
            _buildTabButton(1, 'JSON', Icons.code),
            _buildTabButton(2, 'Request Info', Icons.info_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeSubTab == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => setState(() => _activeSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(MicrosoftCatalogResponse resp) {
    switch (_activeSubTab) {
      case 0:
        return _buildProductsTab(resp);
      case 1:
        return _buildJsonTab(resp);
      case 2:
        return _buildRequestInfoTab(resp);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildJsonTab(MicrosoftCatalogResponse resp) {
    return JsonViewWidget(
      json: resp.json,
      rawJson: resp.json == null ? resp.rawString : null,
      highlightSyntax: true,
      showLineNumbers: true,
    );
  }

  Widget _buildProductsTab(MicrosoftCatalogResponse resp) {
    final allProducts = resp.products;
    if (allProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text(
              'No products returned in this response',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (resp.errorMessage != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  resp.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final filteredProducts = query.isEmpty
        ? allProducts
        : allProducts.where((p) {
            final title = p.title.toLowerCase();
            final id = p.productId.toLowerCase();
            final pub = (p.publisherName ?? '').toLowerCase();
            final cat = (p.category ?? '').toLowerCase();
            final kind = (p.productKind ?? '').toLowerCase();
            final desc = (p.description ?? '').toLowerCase();
            return title.contains(query) ||
                id.contains(query) ||
                pub.contains(query) ||
                cat.contains(query) ||
                kind.contains(query) ||
                desc.contains(query);
          }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText:
                  'Filter ${allProducts.length} products by title, ID, publisher...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Search count feedback strip if searching
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Found ${filteredProducts.length} of ${allProducts.length} products',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

        Expanded(
          child: filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No products match "$_searchQuery"',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.filter_alt_off, size: 16),
                        label: const Text('Clear Filter'),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final prod = filteredProducts[index];
                        return _buildProductCard(prod, isWide);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(MicrosoftCatalogProduct prod, bool isWide) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 72,
                height: 72,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: prod.imageUrl != null && prod.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: prod.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorBuilder: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, size: 28),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.image_not_supported, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + ID chip
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          prod.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (prod.priceFormatted != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            prod.priceFormatted!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Product ID with 1-tap copy, Kind badge, Release Date
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: prod.productId),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied: ${prod.productId}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                prod.productId,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy,
                                size: 11,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (prod.productKind != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            prod.productKind!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (prod.originalReleaseDate != null)
                        Text(
                          prod.originalReleaseDate!.split('T').first,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                    ],
                  ),

                  // Publisher / Short Description
                  if (prod.publisherName != null ||
                      prod.packageFamilyName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      prod.packageFamilyName ?? prod.publisherName ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontFamily: prod.packageFamilyName != null
                            ? 'monospace'
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Action buttons
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.code, size: 14),
                      label: const Text(
                        'View JSON',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JsonViewPage(
                              title: '${prod.title} (${prod.productId})',
                              json: prod.rawJson,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestInfoTab(MicrosoftCatalogResponse resp) {
    final uri = Uri.tryParse(resp.url);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          title: 'Request Target',
          icon: Icons.link,
          children: [
            _buildInfoRow('Full URL', resp.url, isMonospace: true),
            if (uri != null) ...[
              _buildInfoRow('Host', uri.host),
              _buildInfoRow('Path', uri.path),
            ],
            _buildInfoRow('Method', 'GET'),
            _buildInfoRow('Timestamp', resp.timestamp.toIso8601String()),
          ],
        ),
        const SizedBox(height: 12),
        if (uri != null && uri.queryParameters.isNotEmpty) ...[
          _buildInfoCard(
            title: 'Query Parameters (${uri.queryParameters.length})',
            icon: Icons.tune,
            children: uri.queryParameters.entries
                .map((e) => _buildInfoRow(e.key, e.value, isMonospace: true))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        _buildInfoCard(
          title: 'Response Metrics',
          icon: Icons.analytics_outlined,
          children: [
            _buildInfoRow('HTTP Status Code', '${resp.statusCode}'),
            _buildInfoRow('Parsed Products Count', '${resp.products.length}'),
            if (resp.totalResultCount != null)
              _buildInfoRow('Total Result Count', '${resp.totalResultCount}'),
            if (resp.hasMorePages != null)
              _buildInfoRow('Has More Pages', '${resp.hasMorePages}'),
            if (resp.bigIds.isNotEmpty)
              _buildInfoRow('BigIds Returned', '${resp.bigIds.length} items'),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: isMonospace ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
