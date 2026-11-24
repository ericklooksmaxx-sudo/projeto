import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/environment_service.dart';
import '../../api/playfabapi.dart';
import '../../services/search_service.dart';
import '../../services/settings_service.dart';
import 'json_view_page.dart';
import '../models/playfab_models.dart';
import 'playfab_response_panel.dart';

class PlayFabApiPage extends StatefulWidget {
  final SearchService searchService;

  const PlayFabApiPage({super.key, required this.searchService});

  @override
  State<PlayFabApiPage> createState() => _PlayFabApiPageState();
}

class _PlayFabApiPageState extends State<PlayFabApiPage>
    with SingleTickerProviderStateMixin {
  PlayFabEndpoint _selectedEndpoint = PlayFabEndpoint.catalogSearch;
  bool _usePersonalAccount = false;
  bool _isRawJsonMode = false;
  bool _isLoading = false;

  String _activeTitleId = '20CA2';

  // Text Controllers
  final _searchQueryController = TextEditingController();
  final _searchFilterController = TextEditingController();
  final _topController = TextEditingController(text: '30');
  final _skipController = TextEditingController(text: '0');
  final _selectController = TextEditingController(text: 'contents, images');
  final _itemIdController = TextEditingController();
  final _etagController = TextEditingController();
  final _containerFriendlyIdController = TextEditingController();
  final _containerItemIdController = TextEditingController();
  final _containerCountController = TextEditingController(text: '10');
  final _titleIdController = TextEditingController();
  final _sharedSecretController = TextEditingController();
  final _entityIdController = TextEditingController();
  final _entityTypeController = TextEditingController(
    text: 'master_player_account',
  );
  final _customIdController = TextEditingController();
  final _customEndpointController = TextEditingController(text: '/Catalog/');
  final _rawJsonController = TextEditingController();

  late final List<TextEditingController> _textControllers = [
    _searchQueryController,
    _searchFilterController,
    _topController,
    _skipController,
    _selectController,
    _itemIdController,
    _etagController,
    _containerFriendlyIdController,
    _containerItemIdController,
    _containerCountController,
    _titleIdController,
    _sharedSecretController,
    _entityIdController,
    _entityTypeController,
    _customIdController,
    _customEndpointController,
    _rawJsonController,
  ];

  final _rawScrollController = ScrollController();
  String _selectedOrderBy = '';
  bool _createAccount = false;
  static const String _defaultScid = '4fc10100-5f7a-4470-899b-280835760c07';
  static const int _maxPlayFabTop = 300;
  static const int _maxPlayFabSkip = 10000;

  // Response State
  dynamic _responseJson;
  int? _responseStatusCode;
  int? _responseDurationMs;
  int? _responseSizeBytes;
  String? _errorMessage;
  String? _rawResponseString;
  Map<String, dynamic>? _lastSentPayload;
  String? _lastSentEndpoint;
  DateTime? _lastResponseTime;

  late TabController _mobileTabController;

  String _selectedPresetCategory = 'All';

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    _loadEnvironment();
    _syncFormToRawJson();
  }

  @override
  void dispose() {
    _mobileTabController.dispose();
    for (final c in _textControllers) {
      c.dispose();
    }
    _rawScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEnvironment() async {
    final env = await EnvironmentService.instance.getActiveEnvironment();
    if (!mounted) return;
    setState(() {
      _activeTitleId = env.titleId;
      _titleIdController.text = env.titleId;
      _sharedSecretController.text = env.sharedSecret;
    });
  }

  // Endpoint and payload helpers

  String _getEndpointPath() {
    if (_selectedEndpoint == PlayFabEndpoint.custom) {
      final text = _customEndpointController.text.trim();
      return text.startsWith('/') ? text : '/$text';
    }
    return _selectedEndpoint.endpoint;
  }

  Map<String, dynamic> _buildPayloadFromForm() {
    switch (_selectedEndpoint) {
      case PlayFabEndpoint.catalogSearch:
        final rawTop = int.tryParse(_topController.text.trim()) ?? 30;
        final rawSkip = int.tryParse(_skipController.text.trim()) ?? 0;
        final top = rawTop.clamp(1, _maxPlayFabTop);
        final skip = rawSkip.clamp(0, _maxPlayFabSkip);
        final payload = <String, dynamic>{
          'count': true,
          'scid': _defaultScid,
          'top': top,
          'skip': skip,
        };
        final query = _searchQueryController.text.trim();
        if (query.isNotEmpty) payload['search'] = query;

        final filter = _searchFilterController.text.trim();
        if (filter.isNotEmpty) payload['filter'] = filter;

        if (_selectedOrderBy.isNotEmpty) {
          payload['orderBy'] = _selectedOrderBy;
        }

        final select = _selectController.text.trim();
        if (select.isNotEmpty) payload['select'] = select;

        return payload;

      case PlayFabEndpoint.catalogGetPublishedItem:
        return {
          'ItemId': _itemIdController.text.trim(),
          'ETag': _etagController.text.trim(),
        };

      case PlayFabEndpoint.catalogGetItemContainers:
        final payload = <String, dynamic>{};
        final count = int.tryParse(_containerCountController.text.trim()) ?? 10;
        payload['Count'] = count;

        final friendlyId = _containerFriendlyIdController.text.trim();
        final itemId = _containerItemIdController.text.trim();

        if (friendlyId.isNotEmpty) {
          payload['AlternateId'] = {'Type': 'FriendlyId', 'Value': friendlyId};
        } else if (itemId.isNotEmpty) {
          payload['Id'] = itemId;
        } else {
          payload['AlternateId'] = {'Type': 'FriendlyId', 'Value': ''};
        }
        return payload;

      case PlayFabEndpoint.clientGetTitlePublicKey:
        return {
          'TitleId': _titleIdController.text.trim().isEmpty
              ? _activeTitleId
              : _titleIdController.text.trim(),
          'TitleSharedSecret': _sharedSecretController.text.trim(),
        };

      case PlayFabEndpoint.authenticationGetEntityToken:
        final entityId = _entityIdController.text.trim();
        final entityType = _entityTypeController.text.trim();
        if (entityId.isNotEmpty && entityType.isNotEmpty) {
          return {
            'Entity': {'Id': entityId, 'Type': entityType},
          };
        }
        return {};

      case PlayFabEndpoint.clientLoginWithCustomId:
        return {
          'TitleId': _titleIdController.text.trim().isEmpty
              ? _activeTitleId
              : _titleIdController.text.trim(),
          'CustomId': _customIdController.text.trim(),
          'CreateAccount': _createAccount,
        };

      case PlayFabEndpoint.custom:
        try {
          final decoded = jsonDecode(_rawJsonController.text);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
        return {};
    }
  }

  void _syncFormToRawJson() {
    if (_isRawJsonMode) return;
    final map = _buildPayloadFromForm();
    const encoder = JsonEncoder.withIndent('  ');
    _rawJsonController.text = encoder.convert(map);
  }

  void _formatRawJson() {
    try {
      final decoded = jsonDecode(_rawJsonController.text);
      const encoder = JsonEncoder.withIndent('  ');
      setState(() {
        _rawJsonController.text = encoder.convert(decoded);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON formatted successfully'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid JSON: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyFilterPreset(FilterPreset preset) {
    final filterText = preset.filter;
    final current = _searchFilterController.text.trim();
    if (current.isEmpty) {
      setState(() {
        _searchFilterController.text = filterText;
        _syncFormToRawJson();
      });
      return;
    }

    if (!mounted) return;

    // If there is already a filter, show menu to append or replace
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Apply Filter Preset',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    preset.title,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Theme.of(ctx).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add_link),
                  title: const Text('Append with AND'),
                  subtitle: Text('and $filterText'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _searchFilterController.text = '$current and $filterText';
                      _syncFormToRawJson();
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alt_route),
                  title: const Text('Append with OR'),
                  subtitle: Text('or $filterText'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _searchFilterController.text =
                          '($current) or $filterText';
                      _syncFormToRawJson();
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.find_replace),
                  title: const Text('Replace current filter'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _searchFilterController.text = filterText;
                      _syncFormToRawJson();
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _paginate(int delta) {
    if (_isRawJsonMode || _selectedEndpoint == PlayFabEndpoint.custom) {
      try {
        final decoded = jsonDecode(_rawJsonController.text.trim());
        if (decoded is Map<String, dynamic>) {
          final currentSkip = decoded['skip'] is num
              ? (decoded['skip'] as num).toInt()
              : (decoded['Skip'] is num ? (decoded['Skip'] as num).toInt() : 0);
          final rawTop = decoded['top'] is num
              ? (decoded['top'] as num).toInt()
              : (decoded['Top'] is num ? (decoded['Top'] as num).toInt() : 30);
          final top = rawTop.clamp(1, _maxPlayFabTop);
          final newSkip = (currentSkip + (delta * top)).clamp(
            0,
            _maxPlayFabSkip,
          );
          if (decoded.containsKey('Skip')) {
            decoded['Skip'] = newSkip;
            decoded['Top'] = top;
          } else {
            decoded['skip'] = newSkip;
            decoded['top'] = top;
          }
          _rawJsonController.text = const JsonEncoder.withIndent(
            '  ',
          ).convert(decoded);
          _skipController.text = newSkip.toString();
          _topController.text = top.toString();
        }
      } catch (_) {}
    } else {
      final currentSkip = int.tryParse(_skipController.text.trim()) ?? 0;
      final rawTop = int.tryParse(_topController.text.trim()) ?? 30;
      final top = rawTop.clamp(1, _maxPlayFabTop);
      final newSkip = (currentSkip + (delta * top)).clamp(0, _maxPlayFabSkip);
      setState(() {
        _topController.text = top.toString();
        _skipController.text = newSkip.toString();
        _syncFormToRawJson();
      });
    }
    _sendRequest();
  }

  Future<void> _sendRequest() async {
    final endpoint = _getEndpointPath();
    if (endpoint.isEmpty || endpoint == '/') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify a valid endpoint path.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Map<String, dynamic> payload;
    if (_isRawJsonMode || _selectedEndpoint == PlayFabEndpoint.custom) {
      final rawText = _rawJsonController.text.trim();
      if (rawText.isEmpty || rawText == '{}') {
        payload = <String, dynamic>{};
      } else {
        try {
          final decoded = jsonDecode(rawText);
          if (decoded is Map<String, dynamic>) {
            payload = decoded;
          } else {
            throw const FormatException('Root must be a JSON object ({...})');
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid JSON body: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } else {
      payload = _buildPayloadFromForm();
    }

    final bool isLoginEndpoint =
        endpoint == '/Client/LoginWithCustomID' ||
        _selectedEndpoint == PlayFabEndpoint.clientLoginWithCustomId;

    if (isLoginEndpoint && !payload.containsKey('EncryptedRequest')) {
      String customId = (payload['CustomId'] ?? _customIdController.text)
          .toString()
          .trim();
      bool createAccount = payload['CreateAccount'] == true || _createAccount;

      // Auto-generate MCPF if Custom ID is empty
      if (customId.isEmpty) {
        customId = PlayFabClient.instance.genCustomId();
        createAccount = true;
        _customIdController.text = customId;
        _createAccount = true;
      }

      payload['CustomId'] = customId;
      payload['CreateAccount'] = createAccount;
      if (!payload.containsKey('TitleId') ||
          (payload['TitleId'] as String).isEmpty) {
        payload['TitleId'] = _activeTitleId;
      }

      if (_isRawJsonMode) {
        _rawJsonController.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(payload);
      } else {
        _syncFormToRawJson();
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _responseJson = null;
      _responseStatusCode = null;
      _responseDurationMs = null;
      _rawResponseString = null;
      _lastSentPayload = payload;
      _lastSentEndpoint = endpoint;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final Map<String, dynamic> result;
      if (isLoginEndpoint && !payload.containsKey('EncryptedRequest')) {
        result = await widget.searchService.loginWithCustomId(
          customId: payload['CustomId'] as String?,
          createAccount: payload['CreateAccount'] == true,
        );
      } else {
        result = await widget.searchService.rawPlayFabRequest(
          endpoint,
          payload,
          usePersonalAccount: _usePersonalAccount,
        );
      }

      stopwatch.stop();
      final rawString = const JsonEncoder.withIndent('  ').convert(result);
      final bytes = utf8.encode(rawString).length;

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _responseStatusCode = 200;
        _responseDurationMs = stopwatch.elapsedMilliseconds;
        _responseSizeBytes = bytes;
        _responseJson = result;
        _rawResponseString = rawString;
        _lastResponseTime = DateTime.now();
      });

      // Switch tab to response on mobile
      if (_mobileTabController.index == 0) {
        _mobileTabController.animateTo(1);
      }
    } on PlayFabException catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _responseStatusCode = e.httpCode != 0 ? e.httpCode : 400;
        _responseDurationMs = stopwatch.elapsedMilliseconds;
        _errorMessage = e.message;
        _responseJson = {
          'error': 'PlayFabException',
          'httpCode': e.httpCode,
          'errorCode': e.errorCode,
          'message': e.message,
        };
        _rawResponseString = const JsonEncoder.withIndent(
          '  ',
        ).convert(_responseJson);
        _responseSizeBytes = utf8.encode(_rawResponseString!).length;
        _lastResponseTime = DateTime.now();
      });
      if (_mobileTabController.index == 0) {
        _mobileTabController.animateTo(1);
      }
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _responseStatusCode = 500;
        _responseDurationMs = stopwatch.elapsedMilliseconds;
        _errorMessage = e.toString();
        _responseJson = {'error': 'Exception', 'details': e.toString()};
        _rawResponseString = const JsonEncoder.withIndent(
          '  ',
        ).convert(_responseJson);
        _responseSizeBytes = utf8.encode(_rawResponseString!).length;
        _lastResponseTime = DateTime.now();
      });
      if (_mobileTabController.index == 0) {
        _mobileTabController.animateTo(1);
      }
    }
  }

  // Response actions

  Future<void> _saveResponseToFile() async {
    if (_rawResponseString == null) return;

    try {
      final downloadPath = await SettingsService.instance.getDownloadPath();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final endpointClean = _getEndpointPath().replaceAll('/', '_');
      final fileName = 'playfab${endpointClean}_$timestamp.json';
      final filePath = '$downloadPath/$fileName';

      final file = File(filePath);
      await file.writeAsString(_rawResponseString!, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved response to $filePath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyResponseJson() {
    if (_rawResponseString == null) return;
    Clipboard.setData(ClipboardData(text: _rawResponseString!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Response copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _openFullscreenJson() {
    if (_responseJson == null) return;
    final title = '${_getEndpointPath()} (${_responseStatusCode ?? 200})';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JsonViewPage(
          title: title,
          json: _responseJson,
          rawJson: _rawResponseString,
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
            title: const Text(
              'PlayFab API Explorer',
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // Active Title ID Chip
              Tooltip(
                message: 'Active PlayFab Title ID: $_activeTitleId',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _activeTitleId,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Account Toggle
              Tooltip(
                message: _usePersonalAccount
                    ? 'Using Personal Account'
                    : 'Using Guest Account',
                child: IconButton(
                  icon: Icon(
                    _usePersonalAccount
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                    color: _usePersonalAccount
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                  ),
                  onPressed: () {
                    setState(() {
                      _usePersonalAccount = !_usePersonalAccount;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _usePersonalAccount
                              ? 'Switched to Personal Account headers'
                              : 'Switched to Guest Account headers',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
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
                            if (_responseStatusCode != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _responseStatusCode == 200
                                      ? Colors.green
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_responseStatusCode',
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
        // Left Column: Request Configuration
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

        // Right Column: Response Viewer
        Expanded(flex: 52, child: _buildResponsePanelWidget()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _mobileTabController,
      children: [
        // Tab 1: Request
        Column(
          children: [
            _buildEndpointBar(),
            const Divider(height: 1),
            Expanded(child: _buildRequestConfigPanel()),
          ],
        ),

        // Tab 2: Response
        _buildResponsePanelWidget(),
      ],
    );
  }

  Widget _buildResponsePanelWidget() {
    return PlayFabResponsePanel(
      isLoading: _isLoading,
      endpointPath: _getEndpointPath(),
      activeTitleId: _activeTitleId,
      usePersonalAccount: _usePersonalAccount,
      responseJson: _responseJson,
      responseStatusCode: _responseStatusCode,
      responseDurationMs: _responseDurationMs,
      responseSizeBytes: _responseSizeBytes,
      errorMessage: _errorMessage,
      rawResponseString: _rawResponseString,
      lastSentPayload: _lastSentPayload,
      lastSentEndpoint: _lastSentEndpoint,
      lastResponseTime: _lastResponseTime,
      onCopyResponse: _copyResponseJson,
      onSaveResponse: _saveResponseToFile,
      onOpenFullscreen: _openFullscreenJson,
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
              // Method Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'POST',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Searchable Endpoint Picker Button
              Expanded(
                child: Tooltip(
                  message: _selectedEndpoint == PlayFabEndpoint.custom
                      ? 'Custom Endpoint - ${_selectedEndpoint.description}'
                      : '${_selectedEndpoint.category}: ${_selectedEndpoint.label}\n${_selectedEndpoint.description}',
                  child: InkWell(
                    onTap: _openEndpointPicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedEndpoint == PlayFabEndpoint.custom
                                  ? 'Custom Endpoint'
                                  : _selectedEndpoint.endpoint,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.unfold_more,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send Action Button
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
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_isLoading ? 'Sending' : 'Send'),
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

          // Custom Endpoint path input if selected
          if (_selectedEndpoint == PlayFabEndpoint.custom) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customEndpointController,
              decoration: const InputDecoration(
                labelText: 'PlayFab Endpoint Path',
                hintText: '/Catalog/Search or /Client/...',
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
    final isCustom = _selectedEndpoint == PlayFabEndpoint.custom;

    if (isCustom) {
      return _buildRawJsonEditor();
    }

    return Column(
      children: [
        // Form, Raw JSON
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
                  label: Text(
                    'Parameters',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: Icon(Icons.tune, size: 16),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(
                    'Raw JSON',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: Icon(Icons.code, size: 16),
                ),
              ],
              selected: {_isRawJsonMode},
              onSelectionChanged: (set) {
                final raw = set.first;
                setState(() {
                  if (raw) {
                    _syncFormToRawJson();
                  }
                  _isRawJsonMode = raw;
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
              key: ValueKey<bool>(_isRawJsonMode),
              child: _isRawJsonMode
                  ? _buildRawJsonEditor()
                  : _buildStructuredParametersForm(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawJsonEditor() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'JSON Request Payload',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.auto_fix_high, size: 18),
                tooltip: 'Format / Prettify JSON',
                visualDensity: VisualDensity.compact,
                onPressed: _formatRawJson,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy Body',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _rawJsonController.text),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request body copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _rawJsonController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: isDarkMode
                    ? const Color(0xFFD4D4D4)
                    : const Color(0xFF1E1E1E),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF8F9FA),
                hintText: '{\n  // Enter JSON payload\n}',
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: isDarkMode
                      ? const Color(0xFF6E6E6E)
                      : const Color(0xFFA0A0A0),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          if (_selectedEndpoint == PlayFabEndpoint.catalogSearch) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                int currentSkip = 0;
                try {
                  final decoded = jsonDecode(_rawJsonController.text.trim());
                  if (decoded is Map<String, dynamic>) {
                    currentSkip = decoded['skip'] is num
                        ? (decoded['skip'] as num).toInt()
                        : (decoded['Skip'] is num
                              ? (decoded['Skip'] as num).toInt()
                              : 0);
                  }
                } catch (_) {
                  currentSkip = int.tryParse(_skipController.text.trim()) ?? 0;
                }
                final canPrev = currentSkip > 0;
                final canNext = currentSkip < _maxPlayFabSkip;

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Prev Page'),
                        onPressed: _isLoading || !canPrev
                            ? null
                            : () => _paginate(-1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Next Page'),
                        onPressed: _isLoading || !canNext
                            ? null
                            : () => _paginate(1),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStructuredParametersForm() {
    switch (_selectedEndpoint) {
      case PlayFabEndpoint.catalogSearch:
        return _buildCatalogSearchParams();
      case PlayFabEndpoint.catalogGetPublishedItem:
        return _buildGetPublishedItemParams();
      case PlayFabEndpoint.catalogGetItemContainers:
        return _buildGetItemContainersParams();
      case PlayFabEndpoint.clientGetTitlePublicKey:
        return _buildTitlePublicKeyParams();
      case PlayFabEndpoint.authenticationGetEntityToken:
        return _buildEntityTokenParams();
      case PlayFabEndpoint.clientLoginWithCustomId:
        return _buildLoginParams();
      case PlayFabEndpoint.custom:
        return _buildRawJsonEditor();
    }
  }

  Widget _buildCatalogSearchParams() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchQueryController,
          decoration: InputDecoration(
            labelText: 'Search Query (Text)',
            hintText: 'e.g. skin, medieval, castle, dragon',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _searchQueryController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchQueryController.clear();
                      _syncFormToRawJson();
                    },
                  )
                : null,
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 16),

        // OData Filter Field
        TextField(
          controller: _searchFilterController,
          maxLines: 2,
          minLines: 1,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: 'OData Filter Expression',
            hintText: "(contentType eq 'MarketplaceDurableCatalog_V1.2')",
            prefixIcon: const Icon(Icons.filter_alt_outlined),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _searchFilterController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchFilterController.clear();
                      _syncFormToRawJson();
                    },
                  )
                : null,
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 12),

        // Filter Presets Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list, size: 16),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Filter Presets',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Category Filter Dropdown
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPresetCategory,
                isDense: true,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Presets')),
                  DropdownMenuItem(
                    value: 'Content Type',
                    child: Text('Content Types'),
                  ),
                  DropdownMenuItem(
                    value: 'Piece & Tags',
                    child: Text('Pieces & Tags'),
                  ),
                  DropdownMenuItem(
                    value: 'Store & Pricing',
                    child: Text('Store & Free'),
                  ),
                  DropdownMenuItem(
                    value: 'Date & Combos',
                    child: Text('Dates & Combos'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPresetCategory = val);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Presets Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: filterPresets
              .where(
                (p) =>
                    _selectedPresetCategory == 'All' ||
                    p.category == _selectedPresetCategory,
              )
              .map((preset) {
                return Tooltip(
                  message: '${preset.tooltip ?? ''}\n${preset.filter}',
                  child: ActionChip(
                    label: Text(
                      preset.title,
                      style: const TextStyle(fontSize: 11),
                    ),
                    avatar: const Icon(Icons.add, size: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onPressed: () => _applyFilterPreset(preset),
                  ),
                );
              })
              .toList(),
        ),
        const SizedBox(height: 20),

        // Order
        const Text(
          'Order By Sorting',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildOrderByChip('Relevance (Default)', ''),
            _buildOrderByChip('Rating: Total Count', 'Rating/TotalCount desc'),
            _buildOrderByChip('Rating: Average', 'Rating/Average desc'),
            _buildOrderByChip('Creation Date (Desc)', 'CreationDate desc'),
            _buildOrderByChip('Creation Date (Asc)', 'CreationDate asc'),
            _buildOrderByChip('Start Date (Desc)', 'startDate desc'),
            _buildOrderByChip('Start Date (Asc)', 'startDate asc'),
          ],
        ),
        const SizedBox(height: 20),

        // Paging, Top and skip
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _topController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Top (Limit, max 300)',
                  hintText: '30',
                  prefixIcon: Icon(Icons.format_list_numbered),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _syncFormToRawJson(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _skipController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Skip (Offset, max 10000)',
                  hintText: '0',
                  prefixIcon: Icon(Icons.skip_next),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _syncFormToRawJson(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Pagination quick buttons
        Builder(
          builder: (context) {
            final currentSkip = int.tryParse(_skipController.text.trim()) ?? 0;
            final canPrev = currentSkip > 0;
            final canNext = currentSkip < _maxPlayFabSkip;

            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Prev Page'),
                    onPressed: _isLoading || !canPrev
                        ? null
                        : () => _paginate(-1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Next Page'),
                    onPressed: _isLoading || !canNext
                        ? null
                        : () => _paginate(1),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Select
        TextField(
          controller: _selectController,
          decoration: const InputDecoration(
            labelText: 'Select',
            hintText: 'contents, images, title, description',
            prefixIcon: Icon(Icons.checklist),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOrderByChip(String label, String value) {
    final isSelected = _selectedOrderBy == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedOrderBy = selected ? value : '';
          _syncFormToRawJson();
        });
      },
    );
  }

  Widget _buildGetPublishedItemParams() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _itemIdController,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'UUID',
            hintText: 'e.g. 2066fa2b-d98c-4f10-9cbf-c943ba620d44',
            prefixIcon: const Icon(Icons.key),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste, size: 18),
              tooltip: 'Paste from clipboard',
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _itemIdController.text = data!.text!.trim();
                  _syncFormToRawJson();
                }
              },
            ),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _etagController,
          decoration: const InputDecoration(
            labelText: 'ETag (Optional)',
            prefixIcon: Icon(Icons.tag),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
      ],
    );
  }

  Widget _buildGetItemContainersParams() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _containerFriendlyIdController,
          decoration: InputDecoration(
            labelText: 'Friendly ID',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste, size: 18),
              tooltip: 'Paste from clipboard',
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _containerFriendlyIdController.text = data!.text!.trim();
                  _syncFormToRawJson();
                }
              },
            ),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _containerItemIdController,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'Or Item UUID (Optional)',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste, size: 18),
              tooltip: 'Paste from clipboard',
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _containerItemIdController.text = data!.text!.trim();
                  _syncFormToRawJson();
                }
              },
            ),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _containerCountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Count',
            hintText: '10',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
      ],
    );
  }

  Widget _buildTitlePublicKeyParams() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleIdController,
          decoration: const InputDecoration(
            labelText: 'Title ID',
            hintText: '20CA2',
            prefixIcon: Icon(Icons.business),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _sharedSecretController,
          decoration: const InputDecoration(
            labelText: 'Title Shared Secret',
            prefixIcon: Icon(Icons.lock_outline),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
      ],
    );
  }

  Widget _buildEntityTokenParams() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _entityIdController,
          decoration: InputDecoration(
            labelText: 'Entity ID (Optional)',
            hintText: 'Leave empty for current caller',
            prefixIcon: const Icon(Icons.badge_outlined),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.account_circle_outlined, size: 18),
              tooltip: 'Use current PlayFabId',
              onPressed: () {
                final id = widget.searchService.authService.playFabId;
                if (id != null && id.isNotEmpty) {
                  setState(() {
                    _entityIdController.text = id;
                    _syncFormToRawJson();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No active PlayFabId available.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _entityTypeController,
          decoration: const InputDecoration(
            labelText: 'Entity Type',
            hintText: 'master_player_account / title_player_account',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
      ],
    );
  }

  Widget _buildLoginParams() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _customIdController,
          decoration: InputDecoration(
            labelText: 'Custom ID',
            hintText: 'Leave empty to auto-generate MCPF...',
            prefixIcon: const Icon(Icons.fingerprint),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_customIdController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear Custom ID',
                    onPressed: () {
                      setState(() {
                        _customIdController.clear();
                        _syncFormToRawJson();
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Generate new MCPF ID',
                  onPressed: () {
                    final generated = PlayFabClient.instance.genCustomId();
                    setState(() {
                      _customIdController.text = generated;
                      _createAccount = true;
                      _syncFormToRawJson();
                    });
                  },
                ),
              ],
            ),
          ),
          onChanged: (_) => _syncFormToRawJson(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.refresh, size: 14),
              label: const Text(
                'Generate New MCPF',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: () {
                final generated = PlayFabClient.instance.genCustomId();
                setState(() {
                  _customIdController.text = generated;
                  _createAccount = true;
                  _syncFormToRawJson();
                });
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.account_circle_outlined, size: 14),
              label: const Text(
                'Load Saved Custom ID',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: () async {
                await PlayFabClient.instance.configLoad();
                if (!mounted) return;
                final savedId = PlayFabClient.instance.configGet(
                  PlayFabClient.instance.envKey('CUSTOM_ID'),
                );
                if (savedId != null && savedId.isNotEmpty) {
                  setState(() {
                    _customIdController.text = savedId;
                    _createAccount = false;
                    _syncFormToRawJson();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Loaded saved Custom ID: $savedId'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No saved Custom ID found in settings.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Create Account'),
          subtitle: const Text('Create a new account if one does not exist'),
          value: _createAccount,
          onChanged: (val) {
            setState(() {
              _createAccount = val;
              _syncFormToRawJson();
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'If Custom ID is left empty, a unique MCPF ID will be automatically generated and authenticated via encrypted RSA',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openEndpointPicker() async {
    final selected = await showDialog<PlayFabEndpoint>(
      context: context,
      builder: (context) =>
          _EndpointPickerDialog(selectedEndpoint: _selectedEndpoint),
    );

    if (selected != null && selected != _selectedEndpoint) {
      setState(() {
        _selectedEndpoint = selected;
        _syncFormToRawJson();
      });
    }
  }
}

class _EndpointPickerDialog extends StatefulWidget {
  final PlayFabEndpoint selectedEndpoint;

  const _EndpointPickerDialog({required this.selectedEndpoint});

  @override
  State<_EndpointPickerDialog> createState() => _EndpointPickerDialogState();
}

class _EndpointPickerDialogState extends State<_EndpointPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final set = <String>{'All'};
    for (final ep in PlayFabEndpoint.values) {
      set.add(ep.category);
    }
    return set.toList();
  }

  List<PlayFabEndpoint> get _filteredEndpoints {
    final query = _searchController.text.trim().toLowerCase();
    return PlayFabEndpoint.values.where((ep) {
      if (_selectedCategory != 'All' && ep.category != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      final matchLabel = ep.label.toLowerCase().contains(query);
      final matchEndpoint = ep.endpoint.toLowerCase().contains(query);
      final matchCategory = ep.category.toLowerCase().contains(query);
      final matchDesc = ep.description.toLowerCase().contains(query);
      return matchLabel || matchEndpoint || matchCategory || matchDesc;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredEndpoints;

    // Group filtered items by category
    final grouped = <String, List<PlayFabEndpoint>>{};
    for (final ep in filtered) {
      grouped.putIfAbsent(ep.category, () => []).add(ep);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Title Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.api_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select PlayFab Endpoint',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search endpoints by name, path, or keyword...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (filtered.length == 1) {
                    Navigator.of(context).pop(filtered.first);
                  }
                },
              ),
            ),

            // Category Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final isCatSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isCatSelected,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isCatSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Endpoints List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No endpoints matching "${_searchController.text}"',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              children: [
                                Text(
                                  entry.key.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${entry.value.length})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final ep in entry.value)
                            _buildEndpointItem(context, ep),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointItem(BuildContext context, PlayFabEndpoint ep) {
    final theme = Theme.of(context);
    final isSelected = ep == widget.selectedEndpoint;

    return InkWell(
      onTap: () => Navigator.of(context).pop(ep),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.dividerColor.withValues(alpha: 0.25),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ep.method,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ep.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 13,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                  if (ep.endpoint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      ep.endpoint,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    ep.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
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
}
