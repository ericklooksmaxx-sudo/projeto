import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import '../models/search_result.dart';
import '../models/content_variant.dart';
import '../models/home_discovery_data.dart';
import 'auth_service.dart';
import '../api/playfabapi.dart';
import 'key_service.dart';
import 'settings_service.dart';
import 'favorite_service.dart';
import 'cart_service.dart';
import 'key_filter.dart';

class SearchService {
  final PlayFabClient _client;
  final AuthService _authService;
  final SettingsService _settingsService;
  final FavoriteService _favoriteService = FavoriteService();
  final KeysService _keysService = KeysService.instance;
  List<CreatorResult>? _cachedCreatorResults;
  bool _isFetching = false;
  List<dynamic> _customDbResults = [];
  List<dynamic> _entitlementResults = [];
  List<dynamic> _cartResults = [];
  List<dynamic> _authResults = [];

  // Cache filter states, if they dont match, cache gets invalidated
  bool? _authCacheLoadSkinPersona;
  bool? _authCacheOnlyNewKeys;
  bool? _entitlementCacheLoadSkinPersona;
  bool? _entitlementCacheOnlyNewKeys;

  // Discovery cache
  HomeDiscoveryData? _cachedDiscoveryData;
  DateTime? _cachedDiscoveryTimestamp;
  Future<HomeDiscoveryData>? _inFlightDiscovery;
  static const Duration _discoveryCacheTtl = Duration(minutes: 10);

  static const String _skinKey = 's5s5ejuDru4uchuF2drUFuthaspAbepE';
  SearchService(this._client, this._authService, this._settingsService);

  static const Map<String, String> _languageToLocaleMap = {
    'en': 'neutral',
    'it': 'it-IT',
    'es': 'es-ES',
    'bg': 'bg-BG',
    'cs': 'cs-CZ',
    'da': 'da-DK',
    'de': 'de-DE',
    'el': 'el-GR',
    'fi': 'fi-FI',
    'fr': 'fr-FR',
    'hu': 'hu-HU',
    'id': 'id-ID',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'nb': 'nb-NO',
    'nl': 'nl-NL',
    'pl': 'pl-PL',
    'pt': 'pt-BR',
    'ru': 'ru-RU',
    'sk': 'sk-SK',
    'sv': 'sv-SE',
    'tr': 'tr-TR',
    'uk': 'uk-UA',
    'zh': 'zh-CN',
  };

  String? _extractUuid(String input) {
    final uuidRegex = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );

    final match = uuidRegex.firstMatch(input.trim());
    return match?.group(0);
  }

  Future<T> _withReAuth<T>(
    Future<T> Function() action, {
    bool retried = false,
  }) async {
    try {
      return await action();
    } on PlayFabException catch (e) {
      if (!retried && e.httpCode == 401) {
        await _authService.forceReAuthenticate();
        return _withReAuth(action, retried: true);
      }
      debugPrint('PlayFab error: $e');
      rethrow;
    } catch (e) {
      debugPrint('Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> performSearch(
    String query, {
    String filter = 'default',
    String orderBy = 'relevance',
    int skip = 0,
    int top = 300,
  }) async {
    return _withReAuth(() async {
      if (!_authService.isAuthenticated) {
        await _authService.authenticate();
      }

      // If keyFilter is 'Only not available', skins and persona are always available (owned)
      final keyFilter = await _settingsService.getKeyFilter();
      if (keyFilter == KeyFilterType.onlyNotAvailable &&
          (filter == 'skin' || filter == 'persona')) {
        return {'items': <SearchResult>[], 'count': 0};
      }

      // Get ShowSkins setting
      final showSkins = await _settingsService.getSkinsFilter();

      if (filter == 'creator') {
        final items = await _performCreatorSearch(query);
        return {'items': items, 'count': items.length};
      }

      if (filter == 'update') {
        final map = await _client.getItemsByHeaderComponent('recently.updated');
        final list = map.values.toList();
        final processed = await _processAndSortResults(
          list,
          searchQuery: query,
        );
        return {'items': processed, 'count': processed.length};
      }

      if (filter == 'new_dlc') {
        final map = await _client.getItemsByHeaderComponent(
          'editorial.row.new',
        );
        final list = map.values.toList();
        final processed = await _processAndSortResults(
          list,
          searchQuery: query,
        );
        return {'items': processed, 'count': processed.length};
      }

      if (filter == 'favorite') {
        await _favoriteService.initialize();
        final favs = _favoriteService.getAllFavorites();
        if (favs.isEmpty) return {'items': <SearchResult>[], 'count': 0};

        final map = await _client.multipleUUIDSearch(favs.toList());
        final items = map.values.toList();
        final processed = await _processAndSortResults(
          items,
          searchQuery: query,
        );
        return {'items': processed, 'count': processed.length};
      }

      final trimmedQuery = query.trim();
      final extractedUuid = _extractUuid(trimmedQuery);

      final String finalFilter = _buildFilter(filter, showSkins);

      if (extractedUuid != null) {
        // Handle UUID search
        final result = await _client.uuidSearch(extractedUuid);
        final item = result['Item'];
        final processed = await _processAndSortResults(
          item != null ? [item] : [],
        );
        return {'items': processed, 'count': item != null ? 1 : 0};
      }

      // Normal search
      final effectiveOrderBy = orderBy == 'relevance'
          ? (trimmedQuery.isNotEmpty ? '' : 'startDate DESC')
          : orderBy;

      final searchResult = await _client.search(
        effectiveOrderBy, // order by
        finalFilter, // filter
        top, // top
        skip, // skip
        trimmedQuery, // search term
      );

      final rawItems = searchResult['Items'] ?? <dynamic>[];
      final processedItems = await _processAndSortResults(
        rawItems,
        searchQuery: skip == 0
            ? trimmedQuery
            : null, // only score on first page, and not on pagination searches
      );

      return {'items': processedItems, 'count': searchResult['Count'] ?? 0};
    });
  }

  String _buildFilter(String filter, [bool showSkins = false]) {
    const String baseMarketplace =
        "(contentType eq 'MarketplaceDurableCatalog_V1.2')";
    const String skinExclusion = " and not tags/any(t: t eq 'skinpack')";

    String getBaseFilter({bool applySkinsFilter = false}) {
      if (!showSkins && applySkinsFilter) {
        return "$baseMarketplace$skinExclusion";
      }
      return baseMarketplace;
    }

    switch (filter) {
      case 'addon':
        return "${getBaseFilter()} and tags/any(t: t eq 'addon')";

      case 'world':
        return "${getBaseFilter()} and tags/any(t: t eq 'worldtemplate')";

      case 'skin':
        return "${getBaseFilter()} and tags/any(t: t eq 'skinpack')";

      case 'texture':
        return "${getBaseFilter()} and tags/any(t: t eq 'resourcepack')";

      case 'mashup':
        return "${getBaseFilter()} and tags/any(t: t eq 'mashup')";

      case 'vibrant':
        return "${getBaseFilter()} and tags/any(t: t eq 'tag.vibrantvisuals')";

      case 'hidden':
        if (!showSkins) {
          return "${getBaseFilter()} and tags/any(t: t eq 'hidden_offer')$skinExclusion";
        }
        return "${getBaseFilter()} and tags/any(t: t eq 'hidden_offer')";

      case 'persona':
        return "(contentType eq 'PersonaDurable')";

      case 'emote':
        return "(displayProperties/pieceType eq 'persona_emote')";

      case 'unfiltered':
        if (!showSkins) {
          return "not tags/any(t: t eq 'skinpack')";
        }
        return "";

      case 'scary':
        return "$baseMarketplace and not tags/any(t: t eq 'skinpack') and not tags/any(t: t eq 'resourcepack') and (tags/any(t: t eq 'tag.horror') or tags/any(t: t eq 'tag.halloween') or tags/any(t: t eq 'tag.haunted') or tags/any(t: t eq 'tag.scary_mobs') or tags/any(t: t eq 'tag.spooky'))";

      case 'sounds':
        return "$baseMarketplace and tags/any(t: t eq 'tag.category.audio')";

      case 'default':
      default:
        return getBaseFilter(applySkinsFilter: true);
    }
  }

  Future<List<CreatorResult>> _performCreatorSearch(String query) async {
    try {
      if (_cachedCreatorResults == null && !_isFetching) {
        _isFetching = true;
        final creators = await _withReAuth(() => _client.getCreators());
        // unmodifiable copy of the list
        _cachedCreatorResults = List<CreatorResult>.unmodifiable(
          creators
              .map((creatorData) => CreatorResult.fromMap(creatorData))
              .toList(),
        );

        _isFetching = false;
      }

      final results = _cachedCreatorResults?.toList() ?? [];

      if (query.trim().isEmpty) {
        return results;
      }

      return results
          .where(
            (creator) => creator.filterName.toLowerCase().contains(
              query.trim().toLowerCase(),
            ),
          )
          .toList();
    } catch (e) {
      _isFetching = false;
      _cachedCreatorResults = null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCreatorStatistics(String creatorId) async {
    return _withReAuth(() async {
      if (!_authService.isAuthenticated) {
        await _authService.authenticate();
      }

      final itemCounts = await _client.getCreatorItemCount(creatorId);

      return {'counts': itemCounts};
    });
  }

  Future<Map<String, dynamic>> searchCreatorItemsPaginated(
    String creatorId, {
    String? contentType,
    String? searchTerm,
    int skip = 0,
    int top = 300,
  }) async {
    return _withReAuth(() async {
      if (!_authService.isAuthenticated) {
        await _authService.authenticate();
      }

      final keyFilter = await _settingsService.getKeyFilter();
      if (keyFilter == KeyFilterType.onlyNotAvailable &&
          (contentType == 'skin' ||
              contentType == 'persona' ||
              contentType == 'capes')) {
        return {'items': <SearchResult>[], 'totalCount': 0};
      }

      final result = await _client.searchCreatorItemsPaginated(
        creatorId,
        contentType: contentType,
        searchTerm: searchTerm,
        skip: skip,
        top: top,
      );

      final items = await _processAndSortResults(
        result['items'],
        searchQuery: searchTerm,
      );

      return {'items': items, 'totalCount': result['totalCount']};
    });
  }

  Future<List<dynamic>> processCustomKeysFile(String filePath) async {
    try {
      if (!_authService.isAuthenticated) {
        await _authService.authenticate();
      }
      final file = File(filePath);
      final content = await file.readAsString();

      final validKeys = _parseAndValidateKeys(content);

      if (validKeys.isEmpty) {
        throw 'No valid keys found in the file';
      }

      final results = await _withReAuth(
        () => _client.processFriendlyUuid(validKeys),
      );

      _customDbResults = results;

      return results;
    } catch (e) {
      final errorMessage = e is String ? e : e.toString();
      throw 'Failed to process file: ${errorMessage.toLowerCase()}';
    }
  }

  // Cached result is used for customdb page, mcdec page and auth page
  // so the user doesnt need to research the data when he exit the page
  // and returns to it
  Future<List<SearchResult>> getCachedResults(
    KeysFileType keysFileType, {
    String? searchQuery,
    bool loadSkinPersona = false,
    bool onlyNewKeys = false,
  }) async {
    List<dynamic> results;

    // Check if cache is valid for current filter settings
    if (keysFileType == KeysFileType.entitlement) {
      if (_entitlementCacheLoadSkinPersona != loadSkinPersona ||
          _entitlementCacheOnlyNewKeys != onlyNewKeys) {
        return []; // Cache invalid
      }
      results = _entitlementResults;
    } else if (keysFileType == KeysFileType.receipt) {
      if (_authCacheLoadSkinPersona != loadSkinPersona ||
          _authCacheOnlyNewKeys != onlyNewKeys) {
        return [];
      }
      results = _authResults;
    } else {
      results = _customDbResults;
    }

    if (results.isEmpty) {
      return [];
    }

    return await _processAndSortResults(results, searchQuery: searchQuery);
  }

  int getCachedResultsCount(KeysFileType keysFileType) {
    if (keysFileType == KeysFileType.entitlement) {
      return _entitlementResults.length;
    } else if (keysFileType == KeysFileType.receipt) {
      return _authResults.length;
    } else {
      return _customDbResults.length;
    }
  }

  void clearCache(KeysFileType keysFileType) {
    if (keysFileType == KeysFileType.entitlement) {
      _entitlementResults = [];
      _entitlementCacheLoadSkinPersona = null;
      _entitlementCacheOnlyNewKeys = null;
    } else if (keysFileType == KeysFileType.receipt) {
      _authResults = [];
      _authCacheLoadSkinPersona = null;
      _authCacheOnlyNewKeys = null;
    } else {
      _customDbResults = [];
    }
  }

  Future<List<SearchResult>> getCachedCartResults({String? searchQuery}) async {
    if (_cartResults.isEmpty) {
      return [];
    }

    return await _processAndSortResults(_cartResults, searchQuery: searchQuery);
  }

  int getCachedCartResultsCount() {
    return _cartResults.length;
  }

  Map<String, String> _parseAndValidateKeys(String content) {
    final Map<String, String> validKeys = {};
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      if (line.contains(_skinKey)) {
        continue;
      }

      if (!line.contains('=')) {
        continue;
      }

      final parts = line.split('=');
      if (parts.length != 2) {
        continue;
      }

      final uuid = parts[0].trim();
      final key = parts[1].trim();

      if (!_isValidUuid(uuid)) {
        continue;
      }

      if (key.isEmpty || key.length != 32) {
        continue;
      }

      validKeys[uuid] = key;
    }

    return validKeys;
  }

  bool _isValidUuid(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }

  Future<List<SearchResult>> searchPersonalKeys(
    KeysFileType keysFileType, {
    bool loadSkinPersona = false,
    bool onlyNewKeys = false,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        await _authService.authenticate();
      }
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${keysFileType.fileName}');

      if (!await file.exists()) {
        throw '${keysFileType.fileName} file not found';
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        throw '${keysFileType.fileName} file is empty';
      }

      final Set<String> uuids = {};
      final lines = content.split('\n');

      final Set<String> existingManifestUUIDs = onlyNewKeys
          ? _keysService.mainManifestUuids
          : const {};

      for (int i = 1; i < lines.length; i++) {
        final trimmedLine = lines[i].trim();
        if (trimmedLine.isEmpty) continue;

        final parts = trimmedLine.split('\t');
        if (parts.length < 4 || parts[0].isEmpty) continue;

        // Filter out skin key if not loadingSkinPersona or if onlyNewKeys is true
        if (parts[3] == _skinKey && (!loadSkinPersona || onlyNewKeys)) {
          continue;
        }

        // Filter out existing keys if onlyNewKeys is true
        if (onlyNewKeys && parts.length >= 2) {
          final manifestUUID = parts[1].trim();
          if (existingManifestUUIDs.contains(manifestUUID)) {
            continue;
          }
        }

        uuids.add(parts[0]);
      }

      if (uuids.isEmpty) {
        if (onlyNewKeys) {
          // Cache empty results and store the filter state
          if (keysFileType == KeysFileType.entitlement) {
            _entitlementResults = [];
            _entitlementCacheLoadSkinPersona = loadSkinPersona;
            _entitlementCacheOnlyNewKeys = onlyNewKeys;
          } else if (keysFileType == KeysFileType.receipt) {
            _authResults = [];
            _authCacheLoadSkinPersona = loadSkinPersona;
            _authCacheOnlyNewKeys = onlyNewKeys;
          }
          return [];
        } else {
          throw 'No valid UUIDs found in ${keysFileType.fileName} file';
        }
      }

      final results = await _withReAuth(
        () => _client.multipleUUIDSearch(uuids.toList()),
      );
      final resultsList = results.values.toList();

      if (keysFileType == KeysFileType.entitlement) {
        _entitlementResults = resultsList;
        _entitlementCacheLoadSkinPersona = loadSkinPersona;
        _entitlementCacheOnlyNewKeys = onlyNewKeys;
      } else if (keysFileType == KeysFileType.receipt) {
        _authResults = resultsList;
        _authCacheLoadSkinPersona = loadSkinPersona;
        _authCacheOnlyNewKeys = onlyNewKeys;
      } else {
        _customDbResults = resultsList;
      }

      final searchResults = await _processAndSortResults(resultsList);
      return searchResults;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<SearchResult>> _processAndSortResults(
    List<dynamic> items, {
    String? searchQuery,
    String? keyFilter,
    String? localeCode,
  }) async {
    final effectiveKeyFilter =
        keyFilter ?? await _settingsService.getKeyFilter();
    final effectiveLocaleCode =
        localeCode ??
        (_languageToLocaleMap[await _settingsService.getApiLanguage()] ??
            'neutral');

    List<SearchResult> results;
    // If no search query, return all items without scoring
    if (searchQuery == null || searchQuery.isEmpty) {
      final allItems = items
          .map((item) => _convertItem(item, effectiveLocaleCode))
          .toList();
      results = _applyKeyFilter(allItems, effectiveKeyFilter);
    } else {
      final searchTerms = searchQuery
          .toLowerCase()
          .split(_wordSplitRegex)
          .where((t) => t.isNotEmpty)
          .toList();
      final scoredItems = <_ScoredItem>[];

      for (var item in items) {
        final score = _calculateItemScore(item, searchTerms);
        scoredItems.add(_ScoredItem(item, score));
      }

      // Sort by score (descending)
      scoredItems.sort((a, b) => b.score.compareTo(a.score));

      final converted = scoredItems
          .map((scored) => _convertItem(scored.item, effectiveLocaleCode))
          .toList();
      results = _applyKeyFilter(converted, effectiveKeyFilter);
    }

    return results;
  }

  Future<List<SearchResult>> searchCartItems() async {
    try {
      if (!_authService.isAuthenticated) {
        await _authService.authenticate();
      }

      final cartService = CartService();
      await cartService.initialize();

      final cartUUIDs = cartService.getAllCartItems();

      if (cartUUIDs.isEmpty) {
        _cartResults = [];
        return [];
      }

      final results = await _withReAuth(
        () => _client.multipleUUIDSearch(cartUUIDs),
      );
      final resultsList = results.values.toList();

      _cartResults = resultsList;

      final searchResults = await _processAndSortResults(resultsList);

      return searchResults;
    } catch (e) {
      throw e.toString();
    }
  }

  // these are used for test api
  AuthService get authService => _authService;

  Future<Map<String, dynamic>> loginWithCustomId({
    String? customId,
    bool? createAccount,
  }) async {
    return _client.loginWithCustomId(
      customId: customId,
      createAccount: createAccount,
      saveToConfig: false,
    );
  }

  Future<Map<String, dynamic>> rawPlayFabRequest(
    String endpoint,
    Map<String, dynamic> data, {
    Map<String, String>? additionalHeaders,
    bool usePersonalAccount = false,
  }) async {
    return _withReAuth(() async {
      if (!_authService.isAuthenticated) {
        await _authService.authenticate();
      }
      return _client.sendPlayFabRequest(
        endpoint,
        data,
        additionalHeaders,
        usePersonalAccount,
      );
    });
  }

  List<SearchResult> _applyKeyFilter(
    List<SearchResult> items,
    String keyFilter,
  ) {
    switch (keyFilter) {
      case KeyFilterType.onlyAvailable:
        return items.where((item) => item.isOwned).toList();
      case KeyFilterType.onlyNotAvailable:
        return items.where((item) => !item.isOwned).toList();
      case KeyFilterType.showAll:
      default:
        return items;
    }
  }

  static final RegExp _wordSplitRegex = RegExp(r'[^a-z0-9]+');

  double _calculateItemScore(dynamic item, List<String> searchTerms) {
    double score = 0;
    final title = (item['Title']?['neutral'] ?? '').toString().toLowerCase();
    final titleWords = title.split(_wordSplitRegex);
    final tags =
        (item['Tags'] as List<dynamic>?)
            ?.map((t) => t.toString().toLowerCase())
            .toList() ??
        [];

    int matchedCount = 0;
    for (final term in searchTerms) {
      if (term.isEmpty) continue;
      bool matched = false;

      // Title matches
      if (titleWords.contains(term)) {
        score += 5.0;
        matched = true;
      } else if (title.contains(term)) {
        score += 3.0;
        matched = true;
      }

      // Tag matches
      if (tags.any((tag) => tag.contains(term))) {
        score += 2.0;
        matched = true;
      }

      if (matched) {
        matchedCount++;
      }
    }

    // if item matches all search terms
    if (searchTerms.length > 1 && matchedCount >= searchTerms.length) {
      score += 15.0;
    }

    return score;
  }

  String _extractLocalizedString(
    Map<String, dynamic>? languageObject,
    String localeCode,
    String defaultValue,
  ) {
    if (languageObject == null) return defaultValue;

    if (languageObject.containsKey(localeCode)) {
      final value = languageObject[localeCode];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    // Fallback to neutral
    if (languageObject.containsKey('neutral')) {
      final value = languageObject['neutral'];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    // Fallback to en-US (some fields like faq/howTo only serve en-US)
    if (localeCode != 'en-US' && languageObject.containsKey('en-US')) {
      final value = languageObject['en-US'];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    return defaultValue;
  }

  SearchResult _convertItem(dynamic item, String localeCode) {
    final title = _extractLocalizedString(
      item['Title'],
      localeCode,
      'Title not available',
    );

    final creator =
        item['DisplayProperties']?['creatorName'] ?? 'Unknown Creator';
    String? creatorId;
    final creatorEntityKey = item['CreatorEntityKey'];
    if (creatorEntityKey != null) {
      final id = creatorEntityKey['Id'];
      final typeString = creatorEntityKey['TypeString'];
      if (id != null && typeString != null) {
        creatorId = '$typeString!$id';
      }
    }

    final description = _extractLocalizedString(
      item['Description'],
      localeCode,
      'Description not available',
    );

    final dlcId = item['Id'];
    final videoUrl = item['DisplayProperties']?['videoUrl'];

    final changelogObject = item['DisplayProperties']?['publicChangelog'];
    String? changelog;
    if (changelogObject != null) {
      final rawChangelog = _extractLocalizedString(
        changelogObject,
        localeCode,
        '',
      );
      changelog = (rawChangelog.trim().isNotEmpty) ? rawChangelog : null;
    }

    final price = item['DisplayProperties']?['price'];

    final String creationDate = item['CreationDate'];
    final String lastModifiedDate = item['LastModifiedDate'];

    String? version;
    final packIdentity = item['DisplayProperties']?['packIdentity'];
    // we only need the first occurrence
    if (packIdentity is List && packIdentity.isNotEmpty) {
      version = packIdentity[0]['version'];
    }

    final rawPieceType = item['DisplayProperties']?['pieceType'] as String?;
    final bool isEmote = rawPieceType == 'persona_emote';
    final bool isPersonaPiece =
        !isEmote &&
        ((rawPieceType != null && rawPieceType.startsWith('persona_')) ||
            (item['ContentType'] == 'PersonaDurable' && !isEmote) ||
            (item['DisplayProperties']?['packIdentity'] is List &&
                (item['DisplayProperties']['packIdentity'] as List).any(
                  (p) => p['type'] == 'persona_piece',
                )));

    String? imageUrl;
    String? imagePanorama;
    String? packIconUrl;
    List<String> extraImages = [];

    if (item['Images'] != null) {
      for (var img in item['Images']) {
        final imgType = (img['Type'] as String?)?.toLowerCase();
        final imgTag = (img['Tag'] as String?)?.toLowerCase();
        final imgUrl = img['Url'] as String?;

        if (imgType == 'thumbnail') {
          imageUrl = imgUrl;
        }

        if (imgTag == 'packicon' && imgUrl != null) {
          packIconUrl = imgUrl;
        }

        if (imgTag == 'screenshot' && imgUrl != null) {
          extraImages.add(imgUrl);
        }

        if (imgTag == 'panorama' && imgUrl != null) {
          imagePanorama = imgUrl;
        }
      }

      // Fallback
      if (imageUrl == null && item['Images'].isNotEmpty) {
        imageUrl = item['Images'][0]['Url'];
      }
    }

    // Extract download links grouped by tags (variants)
    List<ContentVariant> downloadVariants = [];
    List<String> downloadUrls = [];
    String? skinBinaryUrl;
    String? personaBinaryUrl;
    final contents = item['Contents'] as List<dynamic>?;
    if (contents != null && contents.isNotEmpty) {
      for (var content in contents) {
        final type = (content['Type'] as String?)?.toLowerCase();
        if (type == 'skinbinary') {
          final url = content['Url'] as String?;
          if (url != null && url.isNotEmpty) {
            final rawTags = content['Tags'] as List<dynamic>? ?? [];
            if (rawTags.isEmpty) {
              skinBinaryUrl = url;
              break;
            }
            skinBinaryUrl ??= url;
          }
        } else if (type == 'personabinary') {
          final url = content['Url'] as String?;
          if (url != null && url.isNotEmpty) {
            final rawTags = content['Tags'] as List<dynamic>? ?? [];
            if (rawTags.isEmpty) {
              personaBinaryUrl = url;
              break;
            }
            personaBinaryUrl ??= url;
          }
        }
      }

      // Group content entries by their sorted tags
      final Map<String, List<Map<String, String>>> groups = {};
      for (var content in contents) {
        final url = content['Url'];
        if (url == null || url is! String) continue;

        final rawTags = content['Tags'] as List<dynamic>? ?? [];
        final sortedTags = rawTags.map((t) => t.toString()).toList()..sort();
        final groupKey = sortedTags.join('|');

        groups.putIfAbsent(groupKey, () => []);
        groups[groupKey]!.add({'url': url});
      }

      // Build ContentVariant list, default (empty tags) first
      final sortedKeys = groups.keys.toList()
        ..sort((a, b) {
          if (a.isEmpty) return -1;
          if (b.isEmpty) return 1;
          return a.compareTo(b);
        });

      for (final key in sortedKeys) {
        final entries = groups[key]!;
        final tagList = key.isEmpty ? <String>[] : key.split('|');
        final label = tagList.isEmpty ? 'Default' : tagList.join(', ');

        downloadVariants.add(
          ContentVariant(
            label: label,
            tags: tagList,
            urls: entries.map((e) => e['url']!).toList(),
          ),
        );
      }

      if (downloadVariants.isNotEmpty) {
        downloadUrls = downloadVariants.first.urls;
      }
    }

    final ratingData = item['Rating'];
    final avgStars = ratingData?['Average']?.toDouble();
    final totalStars = ratingData?['TotalCount']?.toInt();

    // Extract pack type
    final List<dynamic> tags = item['Tags'] is List
        ? item['Tags'] as List<dynamic>
        : [];
    final String contentType = item['ContentType'] is String
        ? item['ContentType'] as String
        : '';

    final packType = tags.contains('skinpack')
        ? 'SkinPack'
        : tags.contains('persona_piece') ||
              contentType.contains('PersonaDurable')
        ? 'Persona'
        : tags.contains('worldtemplate')
        ? 'World'
        : tags.contains('resourcepack')
        ? 'TexturePack'
        : tags.contains('mashup')
        ? 'Mashup'
        : tags.contains('addon')
        ? 'Addon'
        : contentType.contains('3PServerContent_V1.2')
        ? 'Server content'
        : 'DLC';

    final bool hasVibrantVisuals = tags.contains('tag.vibrantvisuals');

    // Check ownership
    final bool isOwned = packType == 'SkinPack' || packType == 'Persona'
        ? true
        : _keysService.isKeyAvailable(dlcId);

    // FAQ entries
    List<FaqEntry>? faqEntries;
    final faqData = item['DisplayProperties']?['faq'];
    if (faqData != null) {
      final rawEntries = faqData['faqEntries'] as List<dynamic>?;
      if (rawEntries != null && rawEntries.isNotEmpty) {
        final sorted = List<dynamic>.from(rawEntries)
          ..sort(
            (a, b) => ((a['rowIndex'] as int?) ?? 0).compareTo(
              (b['rowIndex'] as int?) ?? 0,
            ),
          );
        faqEntries = sorted.map((e) {
          return (
            heading: _extractLocalizedString(
              e['heading'] as Map<String, dynamic>?,
              localeCode,
              '',
            ),
            content: _extractLocalizedString(
              e['content'] as Map<String, dynamic>?,
              localeCode,
              '',
            ),
          );
        }).toList();
      }
    }

    // how-to entries
    String? howToTitle;
    List<HowToEntry>? howToEntries;
    final howToData = item['DisplayProperties']?['howTo'] as List<dynamic>?;
    if (howToData != null && howToData.isNotEmpty) {
      final List<HowToEntry> steps = [];
      for (final entry in howToData) {
        final alignment = entry['headingAlignment'] as String?;
        final headingObj = entry['heading'] as Map<String, dynamic>?;
        final contentObj = entry['content'] as Map<String, dynamic>?;

        // 'center' heading is the title
        if (alignment == 'center' && headingObj != null && howToTitle == null) {
          howToTitle = _extractLocalizedString(headingObj, localeCode, '');
          continue;
        }

        final heading = headingObj != null
            ? _extractLocalizedString(headingObj, localeCode, '')
            : null;
        final content = contentObj != null
            ? _extractLocalizedString(contentObj, localeCode, '')
            : null;

        List<String>? images;
        final rawImages = entry['images'] as List<dynamic>?;
        if (rawImages != null && rawImages.isNotEmpty) {
          final urls = rawImages
              .whereType<Map>()
              .map((img) => (img['url'] ?? img['Url']) as String?)
              .where((url) => url != null && url.isNotEmpty)
              .cast<String>()
              .toList();
          if (urls.isNotEmpty) {
            images = urls;
          }
        }

        if ((heading != null && heading.isNotEmpty) ||
            (content != null && content.isNotEmpty) ||
            (images != null && images.isNotEmpty)) {
          steps.add((heading: heading, content: content, images: images));
        }
      }
      if (steps.isNotEmpty) {
        howToEntries = steps;
      }
    }

    return SearchResult(
      title: title,
      creator: creator,
      creatorId: creatorId,
      imageUrl: imageUrl,
      description: description,
      avgStars: avgStars,
      totalStars: totalStars,
      downloadUrls: downloadUrls,
      downloadVariants: downloadVariants,
      dlcId: dlcId,
      packType: packType,
      extraImages: extraImages,
      imagePanorama: imagePanorama,
      packIconUrl: packIconUrl,
      videoUrl: videoUrl,
      changelog: changelog,
      isOwned: isOwned,
      price: price,
      hasVibrantVisuals: hasVibrantVisuals,
      creationDate: creationDate,
      lastModifiedDate: lastModifiedDate,
      version: version,
      isEmote: isEmote,
      isPersonaPiece: isPersonaPiece,
      skinBinaryUrl: skinBinaryUrl,
      personaBinaryUrl: personaBinaryUrl,
      faqEntries: faqEntries,
      howToTitle: howToTitle,
      howToEntries: howToEntries,
    );
  }

  void clearDiscoveryCache() {
    _cachedDiscoveryData = null;
    _cachedDiscoveryTimestamp = null;
    _inFlightDiscovery = null;
  }

  Future<HomeDiscoveryData> getHomeDiscovery({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      if (_cachedDiscoveryData != null &&
          _cachedDiscoveryTimestamp != null &&
          DateTime.now().difference(_cachedDiscoveryTimestamp!) <
              _discoveryCacheTtl) {
        return _cachedDiscoveryData!;
      }
      if (_inFlightDiscovery != null) {
        return await _inFlightDiscovery!;
      }
    }

    final future = _fetchHomeDiscovery();
    _inFlightDiscovery = future;
    try {
      return await future;
    } finally {
      if (_inFlightDiscovery == future) {
        _inFlightDiscovery = null;
      }
    }
  }

  Future<HomeDiscoveryData> _fetchHomeDiscovery() async {
    return _withReAuth(() async {
      if (!_authService.isAuthenticated) {
        await _authService.authenticate();
      }

      final settings = await Future.wait([
        _settingsService.getSkinsFilter(),
        _settingsService.getKeyFilter(),
        _settingsService.getApiLanguage(),
      ]);

      final showSkins = settings[0] as bool;
      final keyFilter = settings[1] as String;
      final apiLanguage = settings[2] as String;
      final localeCode = _languageToLocaleMap[apiLanguage] ?? 'neutral';

      // Calculate 21 days ago in ISO format (e.g. 2026-08-18T00:00:00Z)
      final twentyOneDaysAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 21),
      );
      final dateIso = '${twentyOneDaysAgo.toIso8601String().split('.')[0]}Z';
      final spotlightFilter =
          "(contentType eq 'MarketplaceDurableCatalog_V1.2') and (CreationDate ge $dateIso) and (not tags/any(t: t eq 'skinpack'))";

      // Concurrently run all catalog section searches
      final responses = await Future.wait([
        _client.search('Rating/TotalCount desc', spotlightFilter, 4, 0, ''),
        _client.search(
          'startDate DESC',
          _buildFilter('default', showSkins),
          8,
          0,
          '',
        ),
        _client.search('startDate DESC', _buildFilter('addon'), 8, 0, ''),
        _client.search('startDate DESC', _buildFilter('scary'), 8, 0, ''),
        _client.search('startDate DESC', _buildFilter('world'), 8, 0, ''),
        // temp disabled until sound packs are purchasable
        // mojang said later on this year so there isnt a clear date
        //_client.search('startDate DESC', _buildFilter('sounds'), 8, 0, ''),
        _client.search('startDate DESC', _buildFilter('texture'), 8, 0, ''),
        _client.search('startDate DESC', _buildFilter('mashup'), 8, 0, ''),
      ]);

      var spotlightRaw = (responses[0]['Items'] as List<dynamic>?) ?? [];

      // Fallback to top rated recent items if window has no matches
      if (spotlightRaw.isEmpty) {
        final fallbackSpotlight = await _client.search(
          'Rating/TotalCount desc',
          _buildFilter('default', showSkins),
          4,
          0,
          '',
        );
        spotlightRaw = (fallbackSpotlight['Items'] as List<dynamic>?) ?? [];
      }

      final processed = await Future.wait([
        _processAndSortResults(
          spotlightRaw,
          keyFilter: keyFilter,
          localeCode: localeCode,
        ),
        _processAndSortResults(
          responses[1]['Items'] ?? [],
          keyFilter: keyFilter,
          localeCode: localeCode,
        ),
        _processAndSortResults(
          responses[2]['Items'] ?? [],
          keyFilter: keyFilter,
          localeCode: localeCode,
        ),
        _processAndSortResults(
          responses[3]['Items'] ?? [],
          keyFilter: keyFilter,
          localeCode: localeCode,
        ),
        _processAndSortResults(
          responses[4]['Items'] ?? [],
          keyFilter: keyFilter,
          localeCode: localeCode,
        ),
        // _processAndSortResults(
        //   responses[5]['Items'] ?? [],
        //   keyFilter: keyFilter,
        //   localeCode: localeCode,
        // ),
        _processAndSortResults(
          responses[5]['Items'] ?? [],
          keyFilter: keyFilter,
          localeCode: localeCode,
        ),
        _processAndSortResults(
          responses[6]['Items'] ?? [],
          keyFilter: keyFilter,
          localeCode: localeCode,
        ),
      ]);

      final data = HomeDiscoveryData(
        spotlight: processed[0],
        newReleases: processed[1],
        addons: processed[2],
        scaryDlc: processed[3],
        worlds: processed[4],
        sounds: const [],
        textures: processed[5],
        mashups: processed[6],
        timestamp: DateTime.now(),
      );

      _cachedDiscoveryData = data;
      _cachedDiscoveryTimestamp = DateTime.now();

      return data;
    });
  }
}

class _ScoredItem {
  final dynamic item;
  final double score;

  _ScoredItem(this.item, this.score);
}
