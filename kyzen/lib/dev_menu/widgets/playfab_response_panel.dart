import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'json_view_page.dart';

class PlayFabResponsePanel extends StatefulWidget {
  final bool isLoading;
  final String endpointPath;
  final String activeTitleId;
  final bool usePersonalAccount;
  final dynamic responseJson;
  final int? responseStatusCode;
  final int? responseDurationMs;
  final int? responseSizeBytes;
  final String? errorMessage;
  final String? rawResponseString;
  final Map<String, dynamic>? lastSentPayload;
  final String? lastSentEndpoint;
  final DateTime? lastResponseTime;
  final VoidCallback onCopyResponse;
  final VoidCallback onSaveResponse;
  final VoidCallback onOpenFullscreen;

  const PlayFabResponsePanel({
    super.key,
    required this.isLoading,
    required this.endpointPath,
    required this.activeTitleId,
    required this.usePersonalAccount,
    this.responseJson,
    this.responseStatusCode,
    this.responseDurationMs,
    this.responseSizeBytes,
    this.errorMessage,
    this.rawResponseString,
    this.lastSentPayload,
    this.lastSentEndpoint,
    this.lastResponseTime,
    required this.onCopyResponse,
    required this.onSaveResponse,
    required this.onOpenFullscreen,
  });

  @override
  State<PlayFabResponsePanel> createState() => _PlayFabResponsePanelState();
}

class _PlayFabResponsePanelState extends State<PlayFabResponsePanel> {
  // Response sub-tabs: 0 = JSON, 1 = Overview, 2 = Request Info
  int _activeResponseTab = 0;

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
              'Sending ${widget.endpointPath} request...',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'PlayFab Title ID: ${widget.activeTitleId}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.responseJson == null && widget.errorMessage == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.api_rounded,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'PlayFab API Explorer',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  'Select an endpoint, customize OData filters or parameters, and click Send to test PlayFab requests in real time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Status and Metadata Bar
        _buildResponseStatusBar(),

        // Sub Tabs: JSON / Overview / Request Info
        Container(
          height: 40,
          color: Theme.of(context).colorScheme.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildResponseSubTab('JSON', 0, Icons.code),
                _buildResponseSubTab('Overview', 1, Icons.analytics_outlined),
                _buildResponseSubTab('Request Info', 2, Icons.info_outline),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Response Body View
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey<int>(_activeResponseTab),
              child: _buildActiveResponseBody(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponseSubTab(String title, int index, IconData icon) {
    final isSelected = _activeResponseTab == index;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => setState(() => _activeResponseTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? primary
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseStatusBar() {
    final isSuccess =
        (widget.responseStatusCode ?? 0) >= 200 &&
        (widget.responseStatusCode ?? 0) < 300;
    final statusColor = isSuccess ? const Color(0xFF2E7D32) : Colors.red[700]!;

    // Calculate count if catalog search or item containers
    int? itemCount;
    int? totalCount;
    if (widget.responseJson is Map<String, dynamic>) {
      final json = widget.responseJson as Map<String, dynamic>;
      final items = json['Items'] ?? json['Containers'];
      if (items is List) itemCount = items.length;
      totalCount = json['Count'] as int?;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // Status and Metadata Badges (Horizontally scrollable if screen is narrow)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status Code Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.responseStatusCode ?? 200} ${isSuccess ? 'OK' : 'Error'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Item Count Badge
                  if (itemCount != null) ...[
                    const SizedBox(width: 8),
                    Container(
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
                      child: Text(
                        totalCount != null
                            ? '$itemCount / $totalCount items'
                            : '$itemCount items',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          IconButton(
            icon: const Icon(Icons.copy, size: 17),
            tooltip: 'Copy JSON',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onCopyResponse,
          ),
          IconButton(
            icon: const Icon(Icons.save_alt, size: 17),
            tooltip: 'Save JSON to File',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onSaveResponse,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 18),
            tooltip: 'Open in Fullscreen Viewer',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onOpenFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveResponseBody() {
    switch (_activeResponseTab) {
      case 0:
        // JSON
        return JsonViewWidget(
          json: widget.responseJson,
          rawJson: widget.rawResponseString,
        );
      case 1:
        // Overview Summary
        return _buildOverviewSummary();
      case 2:
        // Request Info
        return _buildRequestInfo();
      default:
        return const SizedBox.shrink();
    }
  }

  // Overview Summary Tab
  Widget _buildOverviewSummary() {
    if (widget.responseJson is! Map<String, dynamic>) {
      return Center(
        child: Text('Response is not a JSON object: ${widget.responseJson}'),
      );
    }

    final map = widget.responseJson as Map<String, dynamic>;
    final isContainers = map.containsKey('Containers');
    final items = (map['Items'] ?? map['Containers']) as List<dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Error card if error
        if (widget.errorMessage != null) ...[
          Card(
            color: Colors.red.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PlayFab Error Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(widget.errorMessage!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Catalog Search or Containers Summary
        if (items != null) ...[
          Text(
            'Returned ${isContainers ? 'Containers' : 'Items'} (${items.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            if (item is! Map<String, dynamic>) return const SizedBox.shrink();
            final id = item['Id'] as String? ?? 'Unknown';
            final titleObj = item['Title'] as Map<String, dynamic>?;
            final title = titleObj?['neutral'] ?? item['Title'] ?? 'No title';
            final contentType =
                item['ContentType'] ?? item['Type'] ?? 'Unknown Type';
            final creationDate = item['CreationDate'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '$title',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UUID: $id',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '$contentType - $creationDate',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy Item UUID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied UUID: $id'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 16),
                      tooltip: 'Inspect Item JSON',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JsonViewPage(
                              uuid: id,
                              title: '$title ($id)',
                              json: item,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ] else ...[
          // Key-Value summary table of top-level response
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top-Level Response Properties',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Divider(),
                  ...map.entries.map((entry) {
                    final valStr = entry.value is Map || entry.value is List
                        ? const JsonEncoder.withIndent(
                            '  ',
                          ).convert(entry.value)
                        : entry.value.toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              valStr,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Request Info Tab
  Widget _buildRequestInfo() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sent Request Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Divider(),
                _buildInfoRow(
                  'Endpoint',
                  widget.lastSentEndpoint ?? widget.endpointPath,
                ),
                _buildInfoRow('Method', 'POST'),
                _buildInfoRow('Title ID', widget.activeTitleId),
                _buildInfoRow(
                  'Account Mode',
                  widget.usePersonalAccount
                      ? 'Personal Account'
                      : 'Guest Account',
                ),
                if (widget.lastResponseTime != null)
                  _buildInfoRow(
                    'Timestamp',
                    widget.lastResponseTime!.toIso8601String(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payload Sent:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            const JsonEncoder.withIndent(
              '  ',
            ).convert(widget.lastSentPayload ?? {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
