import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart' show debugPrint;
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';
import '../services/key_service.dart';
import '../models/xbox_playfab_models.dart';
import '../services/settings_service.dart';
import 'environment_service.dart';
import 'mc_api.dart';
import 'minecraft_endpoint_service.dart';
import 'dart:async' show unawaited;
import '../services/upload_keys.dart';

class PlayFabException implements Exception {
  final int errorCode; // PlayFab errorCode (eg 1199, 1336)
  final int httpCode; // HTTP status code (eg 401, 429)
  final String message;

  PlayFabException(this.httpCode, this.message, {this.errorCode = 0});

  @override
  String toString() => 'PlayFabException($httpCode/$errorCode): $message';
}

class PlayFabClient {
  final SettingsService _settingsService = SettingsService.instance;

  static void dispose() {
    _httpClient.close(force: true);
  }

  String _titleId = EnvironmentService.defaultEnv.titleId;
  String _sharedSecret = EnvironmentService.defaultEnv.sharedSecret;

  String get _envPrefix => _titleId.toLowerCase();
  String _envKey(String key) => '${_envPrefix}_$key';
  String envKey(String key) => _envKey(key);

  String get tokenCacheFileName => _envKey('playfab_mc_token_cache');

  String playfabDomain =
      "https://${EnvironmentService.defaultEnv.titleId.toLowerCase()}.playfabapi.com";

  Future<void> initEnvironment() async {
    final env = await EnvironmentService.instance.getActiveEnvironment();
    _titleId = env.titleId;
    _sharedSecret = env.sharedSecret;
    playfabDomain = "https://${_titleId.toLowerCase()}.playfabapi.com";
    EnvironmentService.instance.cacheActiveEnvironment(env);
    MinecraftApi.instance.setEnvironment(env);
  }

  Map<String, dynamic> playfabSettings = {};
  final Map<String, String> _baseHeaders = {
    'User-Agent': 'libhttpclient/1.0.0.0',
    'Content-Type': 'application/json',
    'Accept-Language': 'en-US',
  };

  // Separate headers for guest account (normal login)
  final Map<String, String> _guestHeaders = {};

  // Separate headers for personal account
  final Map<String, String> _personalHeaders = {};

  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 30);

  PlayFabClient._internal() {
    configLoad();
  }

  static final PlayFabClient instance = PlayFabClient._internal();
  factory PlayFabClient() => instance;

  Future<Map<String, dynamic>> sendPlayFabRequest(
    String endpoint,
    Map<String, dynamic> data, [
    Map<String, String>? additionalHeaders,
    bool usePersonalAccount = false,
  ]) async {
    final uri = Uri.parse(playfabDomain + endpoint);

    final requestHeaders = Map<String, String>.from(_baseHeaders);

    if (usePersonalAccount) {
      requestHeaders.addAll(_personalHeaders);
    } else {
      requestHeaders.addAll(_guestHeaders);
    }

    if (additionalHeaders != null) {
      requestHeaders.addAll(additionalHeaders);
    }

    HttpClientRequest? request;
    HttpClientResponse? response;

    try {
      // persistent HttpClient instead of http.post (more efficient)
      request = await _httpClient.postUrl(uri);

      requestHeaders.forEach((key, value) {
        request!.headers.set(key, value);
      });

      final jsonData = jsonEncode(data);
      final bytes = utf8.encode(jsonData);
      request.add(bytes);

      response = await request.close();

      final decodedBody = await response.transform(utf8.decoder).join();
      final responseData = jsonDecode(decodedBody) as Map<String, dynamic>;

      if (responseData.containsKey('code') && responseData['code'] != 200) {
        final errorMessage =
            responseData['errorMessage'] as String? ?? 'HTTP request failed';
        final httpCode = responseData['code'] as int;
        final errorCode = responseData['errorCode'] as int? ?? 0;
        throw PlayFabException(httpCode, errorMessage, errorCode: errorCode);
      }

      if (responseData.containsKey('data')) {
        return responseData['data'] as Map<String, dynamic>;
      }

      return responseData;
    } on SocketException catch (e) {
      throw PlayFabException(0, 'Network error: ${e.message}');
    } on HttpException catch (e) {
      throw PlayFabException(0, 'HTTP error: ${e.message}');
    } on FormatException catch (e) {
      throw PlayFabException(0, 'Response parsing error: ${e.message}');
    } catch (e) {
      if (e is PlayFabException) {
        rethrow;
      }
      throw PlayFabException(0, 'Unexpected error: ${e.toString()}');
    }
  }

  void clearPersonalHeaders() {
    _personalHeaders.clear();
  }

  void restorePersonalEntityToken(String entityToken) {
    _personalHeaders['X-EntityToken'] = entityToken;
  }

  void clearGuestEntityTokenCache() {
    configSet(_envKey('GUEST_ENTITY_TOKEN'), '');
    configSet(_envKey('GUEST_TOKEN_EXPIRATION'), '');
    _guestHeaders.remove('X-EntityToken');
  }

  String genCustomId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return "MCPF${hex.encode(values).toUpperCase()}";
  }

  String genPlayerSecret() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(values);
  }

  String genPlayFabTimestamp() {
    final now = DateTime.now().toUtc();
    return now.toIso8601String();
  }

  String genPlayFabSignature(
    String requestBody,
    String timestamp, [
    String? secret,
  ]) {
    final playerSecret = secret ?? configGet(_envKey('PLAYER_SECRET'));
    if (playerSecret == null) throw Exception('Player secret not found');
    final message = utf8.encode("$requestBody.$timestamp.$playerSecret");
    final digest = sha256.convert(message);
    return base64.encode(digest.bytes);
  }

  Future<Uint8List> getMojangCsp() async {
    final response = await sendPlayFabRequest('/Client/GetTitlePublicKey', {
      'TitleId': _titleId,
      'TitleSharedSecret': _sharedSecret,
    });
    return base64.decode(response['RSAPublicKey']);
  }

  RSAPublicKey importCspKey(Uint8List csp) {
    final e = ByteData.view(csp.buffer, 0x10, 4).getUint32(0, Endian.little);
    final nBytes = csp.sublist(0x14);
    final reversedN = nBytes.reversed.toList();
    final n = BigInt.parse(hex.encode(reversedN), radix: 16);
    return RSAPublicKey(n, BigInt.from(e));
  }

  Future<String> get _settingsFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/api.json';
  }

  Future<void> configLoad() async {
    try {
      final filePath = await _settingsFilePath;
      final file = File(filePath);

      bool fileExists = await file.exists();

      if (fileExists) {
        final contents = await file.readAsString();
        playfabSettings = jsonDecode(contents);
      } else {
        playfabSettings = {};
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      debugPrint('Error details: ${e.toString()}');
      playfabSettings = {};
    }
  }

  String? configGet(String key) {
    return playfabSettings[key]?.toString();
  }

  Future<String> configSet(String key, String newValue) async {
    try {
      playfabSettings[key] = newValue;

      final filePath = await _settingsFilePath;
      final file = File(filePath);

      String jsonContent = jsonEncode(playfabSettings);

      await file.writeAsString(jsonContent);

      return newValue;
    } catch (e) {
      debugPrint('Error saving settings: $e');
      debugPrint('Error details: ${e.toString()}');
      return '';
    }
  }

  Future<void> saveGuestEntityToken(String token, String expiration) async {
    await configSet(_envKey('GUEST_ENTITY_TOKEN'), token);
    await configSet(_envKey('GUEST_TOKEN_EXPIRATION'), expiration);
  }

  Future<bool> restoreGuestEntityTokenFromCache() async {
    await configLoad();
    final token = configGet(_envKey('GUEST_ENTITY_TOKEN'));
    final expirationStr = configGet(_envKey('GUEST_TOKEN_EXPIRATION'));

    if (token == null || token.isEmpty || expirationStr == null) return false;

    try {
      final expiration = DateTime.parse(expirationStr);
      // 5-minute subtracted to avoid using a token that's about to expire
      if (DateTime.now().toUtc().isAfter(
        expiration.subtract(const Duration(minutes: 5)),
      )) {
        return false;
      }

      _guestHeaders['X-EntityToken'] = token;
      return true;
    } catch (e) {
      debugPrint('Failed to parse cached token expiration: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> loginWithCustomId({
    String? customId,
    bool? createAccount,
    bool saveToConfig = true,
    int maxRetries = 3,
  }) async {
    await configLoad();

    String? targetCustomId = customId?.trim();
    final bool customIdExplicitlyGiven =
        targetCustomId != null && targetCustomId.isNotEmpty;

    if (!customIdExplicitlyGiven) {
      targetCustomId = configGet(_envKey('CUSTOM_ID'));
    }

    String? playerSecret = configGet(_envKey('PLAYER_SECRET'));

    final bool savedCustomIdMatches =
        targetCustomId != null &&
        targetCustomId.isNotEmpty &&
        configGet(_envKey('CUSTOM_ID')) == targetCustomId;

    bool customIdExists = targetCustomId != null && targetCustomId.isNotEmpty;
    bool playerSecretExists =
        playerSecret != null && playerSecret.isNotEmpty && savedCustomIdMatches;
    bool createNewAccount =
        createAccount ?? (!customIdExists || !playerSecretExists);

    // If we need to create an account, generate BOTH values before saving anything
    if (createNewAccount) {
      if (!customIdExists) {
        targetCustomId = genCustomId();
      }

      if (!playerSecretExists || createAccount == true) {
        playerSecret = genPlayerSecret();
      }

      if (saveToConfig) {
        await configSet(_envKey('CUSTOM_ID'), targetCustomId);
        await configSet(_envKey('PLAYER_SECRET'), playerSecret);

        await configLoad();
      }
    }

    int retryCount = 0;
    Map<String, dynamic>? response;

    while (retryCount <= maxRetries) {
      try {
        if (createNewAccount || retryCount > 0) {
          // For new accounts or retries after "User not found", use encrypted request
          response = await _performEncryptedLogin(
            targetCustomId!,
            playerSecret!,
          );
        } else {
          // For existing accounts
          response = await _performNormalLogin(targetCustomId!, playerSecret!);
        }

        final entityToken = response['EntityToken']?['EntityToken'] as String?;
        if (entityToken != null) {
          _guestHeaders['X-EntityToken'] = entityToken;
        }

        return response;
      } catch (e) {
        if (e is PlayFabException) {
          if (e.errorCode == 1001) {
            // User not found
            debugPrint(
              'User not found (attempt ${retryCount + 1}), switching to create account mode',
            );
            createNewAccount = true;
            retryCount++;

            if (retryCount > maxRetries) {
              throw Exception(
                'Failed to create account after $maxRetries attempts: User not found',
              );
            }

            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          } else if (e.httpCode == 400) {
            // User not found
            String errorMessage = e.message.toLowerCase();
            if (errorMessage.contains('user not found')) {
              debugPrint(
                'User not found (error 400: ${e.message}) (attempt ${retryCount + 1}), switching to create account mode',
              );
              createNewAccount = true;
              retryCount++;

              if (retryCount > maxRetries) {
                throw Exception(
                  'Failed to create account after $maxRetries attempts: User not found',
                );
              }

              await Future.delayed(const Duration(milliseconds: 500));
              continue;
            } else {
              throw Exception('PlayFab error ${e.errorCode}: ${e.message}');
            }
          } else if (e.errorCode == 1199 || e.httpCode == 429) {
            // Rate limit
            int delayMs = _calculateRateLimitDelay(retryCount);
            debugPrint(
              'Rate limit hit (attempt ${retryCount + 1}), waiting ${delayMs}ms',
            );

            await Future.delayed(Duration(milliseconds: delayMs));
            retryCount++;

            if (retryCount > maxRetries) {
              throw Exception('Rate limit exceeded after $maxRetries attempts');
            }
            continue;
          } else {
            throw Exception('PlayFab error ${e.errorCode}: ${e.message}');
          }
        } else {
          rethrow;
        }
      }
    }

    throw Exception('Login failed after $maxRetries attempts');
  }

  Future<Map<String, dynamic>> _performEncryptedLogin(
    String customId,
    String playerSecret,
  ) async {
    final basePayload = {
      'TitleId': _titleId,
      'CreateAccount': true,
      'InfoRequestParameters': {
        'GetPlayerProfile': true,
        'GetUserAccountInfo': true,
      },
    };

    final toEnc = utf8.encode(
      jsonEncode({'CustomId': customId, 'PlayerSecret': playerSecret}),
    );

    final pubKey = importCspKey(await getMojangCsp());
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(pubKey));

    final encrypted = cipher.process(Uint8List.fromList(toEnc));

    final encryptedPayload = Map<String, dynamic>.from(basePayload)
      ..['EncryptedRequest'] = base64.encode(encrypted);

    return await sendPlayFabRequest(
      '/Client/LoginWithCustomID',
      encryptedPayload,
    );
  }

  Future<Map<String, dynamic>> _performNormalLogin(
    String customId,
    String playerSecret,
  ) async {
    final payload = {
      'TitleId': _titleId,
      'CustomId': customId,
      'CreateAccount': false,
      'InfoRequestParameters': {
        'GetPlayerProfile': true,
        'GetUserAccountInfo': true,
      },
    };

    final timestamp = genPlayFabTimestamp();
    final signature = genPlayFabSignature(
      jsonEncode(payload),
      timestamp,
      playerSecret,
    );

    return await sendPlayFabRequest('/Client/LoginWithCustomID', payload, {
      'X-PlayFab-Signature': signature,
      'X-PlayFab-Timestamp': timestamp,
    });
  }

  int _calculateRateLimitDelay(int retryCount) {
    // Exponential backoff with jitter
    int baseDelay = 1000; // 1 second
    int exponentialDelay = baseDelay * (1 << retryCount); // 2^retryCount
    int maxDelay = 30000; // Max 30 seconds

    // Add some randomness to avoid thundering herd
    int jitter = Random().nextInt(1000); // 0-1000ms

    return math.min(exponentialDelay + jitter, maxDelay);
  }

  Future<XboxLoginResultPersonaPlayer> loginWithXbox(String xboxToken) async {
    final response = await sendPlayFabRequest(
      '/Client/LoginWithXbox',
      {
        "CreateAccount": true,
        "InfoRequestParameters": {
          "GetPlayerProfile": true,
          "GetUserAccountInfo": true,
        },
        "TitleId": _titleId,
        "XboxToken": xboxToken,
      },
      null,
      true, // Use personal account headers
    );

    final sessionTicket = response['SessionTicket'] as String?;
    if (sessionTicket == null) {
      throw Exception('Missing session ticket in login response');
    }

    final playFabId = response['PlayFabId'] as String?;
    if (playFabId == null) {
      throw Exception('Missing PlayFabId in login response');
    }

    String? xboxUserId;
    try {
      xboxUserId =
          response['InfoResultPayload']?['AccountInfo']?['XboxInfo']?['XboxUserId']
              as String?;
    } catch (e) {
      debugPrint('Error parsing XboxUserId: $e');
    }

    String? entityToken;
    try {
      entityToken = response['EntityToken']?['EntityToken'] as String?;
      if (entityToken != null) {
        _personalHeaders['X-EntityToken'] = entityToken;
      }
    } catch (e) {
      debugPrint('Error parsing EntityToken: $e');
    }

    return XboxLoginResultPersonaPlayer(
      sessionTicket: sessionTicket,
      playFabId: playFabId,
      xboxUserId: xboxUserId,
      entityToken: entityToken,
    );
  }

  // Get username for personal account (auth login)
  Future<String?> getUserPublisherData({bool forPersonalAccount = true}) async {
    final response = await sendPlayFabRequest(
      '/Client/GetUserPublisherData',
      {},
      null,
      forPersonalAccount,
    );

    try {
      final data = response['Data'] as Map<String, dynamic>?;
      if (data == null || data.isEmpty) return "?";

      return (data['GamertagHint'] as Map<String, dynamic>?)?['Value']
          as String?;
    } catch (e) {
      debugPrint('Error parsing username from publisher data: $e');
      return null;
    }
  }

  Future<EntityTokenResult> getEntityTokenPersonal(String playfabId) async {
    final response = await sendPlayFabRequest(
      '/Authentication/GetEntityToken',
      {
        'Entity': {'Id': playfabId, 'Type': 'master_player_account'},
      },
      null,
      true, // Always use personal account
    );

    final entityToken = response['EntityToken'] as String?;
    final tokenExpirationStr = response['TokenExpiration'] as String?;
    final entityId = response['Entity']?['Id'] as String?;

    if (entityToken == null || tokenExpirationStr == null || entityId == null) {
      throw Exception('Missing required fields in entity token response');
    }

    final tokenExpiration = DateTime.parse(tokenExpirationStr).toLocal();

    _personalHeaders['X-EntityToken'] = entityToken;

    return EntityTokenResult(
      entityToken: entityToken,
      tokenExpiration: tokenExpiration,
      entityId: entityId,
    );
  }

  Future<PurchaseItemResult> purchaseItemById({
    required String itemId,
    required String expectedPrice,
  }) async {
    final data = {
      "Currencies": [
        {
          "CurrencyId": MinecraftEndpoints.currencyId,
          "ExpectedPrice": expectedPrice,
        },
      ],
      "ItemId": itemId,
      "ReturnInventory": false,
    };

    try {
      await sendPlayFabRequest(
        '/Catalog/PurchaseItemById',
        data,
        null,
        true, // Always use personal account
      );

      // Case 1: Successful purchase (200)
      return PurchaseItemResult(success: true);
    } on PlayFabException catch (e) {
      // Case 2: Already owned (400 - not stackable)
      // Case 3: Insufficient funds (422)
      // Case 4: Not purchasable (400)
      return PurchaseItemResult(
        success: false,
        errorCode: e.httpCode.toString(),
        errorMessage: e.message,
      );
    } catch (e) {
      return PurchaseItemResult(
        success: false,
        errorCode: '0',
        errorMessage: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> getEntityToken(String playfabId) async {
    final response = await sendPlayFabRequest(
      '/Authentication/GetEntityToken',
      {
        'Entity': {'Id': playfabId, 'Type': 'master_player_account'},
      },
      null,
      false, // Always use guest account
    );

    final entityToken = response['EntityToken'] as String?;
    final tokenExpiration = response['TokenExpiration'] as String?;

    if (entityToken != null) {
      _guestHeaders['X-EntityToken'] = entityToken;

      if (tokenExpiration != null) {
        await saveGuestEntityToken(entityToken, tokenExpiration);
      }
    }

    return response;
  }

  // Single uuid search, can retrieve items also outside from a namespace
  Future<Map<String, dynamic>> uuidSearch(String dlcId) async {
    return sendPlayFabRequest('/Catalog/GetPublishedItem', {
      'ETag': '',
      'ItemId': dlcId,
    });
  }

  Future<String> _getSelect() async {
    final lang = await _settingsService.getApiLanguage();
    // this is just a small optimization, we only select title and description if the user is using another language
    return lang == 'en'
        ? 'contents, images'
        : 'contents, images, title, description';
  }

  Future<Map<String, dynamic>> search(
    String orderBy,
    String filter,
    int top,
    int skip,
    String searchName,
  ) async {
    final trimmedSearch = searchName.trim();

    // Wrap in quotes only if the search contains special characters
    final hasSpecialChars =
        trimmedSearch.contains('[') ||
        trimmedSearch.contains(']') ||
        trimmedSearch.contains('(') ||
        trimmedSearch.contains(')') ||
        trimmedSearch.contains(':');

    // to prevent from getting "garbage" results that have almost 0 match with the query if the user is using specific sorting (date/rating)
    // we wrap multi-word in quotes to get more precise results. not applied by the "relevance" order, since if the ordertype is omitted playfab auto score items by relevancy (thought idk why mc didn't do it in this way on older versions since every rq had an ordertype set)
    final isExplicitlySorted = orderBy.trim().isNotEmpty;
    final hasSpaces = trimmedSearch.contains(' ');

    final needsQuotes = hasSpecialChars || (isExplicitlySorted && hasSpaces);
    final formattedSearch = needsQuotes ? '"$trimmedSearch"' : trimmedSearch;

    return sendPlayFabRequest('/Catalog/Search', {
      'count': true,
      'filter': filter,
      'search': formattedSearch,
      'orderBy': orderBy,
      'scid': '4fc10100-5f7a-4470-899b-280835760c07',
      'select': await _getSelect(),
      'top': top,
      'skip': skip,
    });
  }

  Future<Map<String, dynamic>> searchFriendlyUuid(
    String query,
    String orderBy,
    String select,
    int top,
    int skip,
    List<String> customIds,
  ) async {
    final filterParts = customIds
        .map(
          (id) =>
              "contentType eq 'MarketplaceDurableCatalog_V1.2' and tags/any(t: t eq '$id')",
        )
        .toList();
    final filterQuery = filterParts.join(' or ');

    return sendPlayFabRequest('/Catalog/Search', {
      'count': true,
      'query': query,
      'filter': filterQuery,
      'orderBy': orderBy,
      'scid': '4fc10100-5f7a-4470-899b-280835760c07',
      'select': select,
      'top': top,
      'skip': skip,
    });
  }

  Future<List<dynamic>> processFriendlyUuid(
    Map<String, String> friendlyUuid,
  ) async {
    const int maxSearch = 150;
    final Map<String, List<Map<String, dynamic>>> resultsDict = {};
    final List<dynamic> allItems = [];

    final friendlyUuidKeys = friendlyUuid.keys.toList();

    for (int i = 0; i < friendlyUuidKeys.length; i += maxSearch) {
      final chunk = friendlyUuidKeys.skip(i).take(maxSearch).toList();

      final searchResult = await searchFriendlyUuid(
        '',
        'creationDate ASC',
        await _getSelect(),
        maxSearch,
        0,
        chunk,
      );

      final searchResults = searchResult['Items'] as List<dynamic>?;

      if (searchResults != null && searchResults.isNotEmpty) {
        allItems.addAll(searchResults);

        for (final item in searchResults) {
          final itemMap = item as Map<String, dynamic>;
          final resultUuid = itemMap['Id'] as String;

          if (!resultsDict.containsKey(resultUuid)) {
            resultsDict[resultUuid] = [];
          }
          resultsDict[resultUuid]!.add(itemMap);
        }
      } else {
        final endRange = (i + maxSearch < friendlyUuidKeys.length)
            ? i + maxSearch
            : friendlyUuidKeys.length;
        debugPrint('No results found for ${i + 1}-$endRange');
      }
    }

    await _saveProcessedResults(resultsDict, friendlyUuid);

    return allItems;
  }

  Future<void> _saveProcessedResults(
    Map<String, List<Map<String, dynamic>>> resultsDict,
    Map<String, String> friendlyUuid,
  ) async {
    final uniqueLines = <String>{};
    final validatedKeys = <String, String>{};

    for (final entry in resultsDict.entries) {
      final resultUuid = entry.key;
      final items = entry.value;

      for (final item in items) {
        final displayProperties =
            item['DisplayProperties'] as Map<String, dynamic>?;
        if (displayProperties != null) {
          final packIdentity =
              displayProperties['packIdentity'] as List<dynamic>?;
          if (packIdentity != null) {
            for (final identity in packIdentity) {
              final identityMap = identity as Map<String, dynamic>;
              final uuid = identityMap['uuid'] as String?;

              if (uuid != null && friendlyUuid.containsKey(uuid)) {
                final packType =
                    (identityMap['type'] as String?)?.replaceAll(
                      'worldtemplate',
                      'world_template',
                    ) ??
                    '';
                final customId = uuid;
                final key = friendlyUuid[customId]!;
                final line = '$resultUuid\t$customId\t$packType\t$key';
                uniqueLines.add(line);
                validatedKeys[customId] = key;
              }
            }
          }
        }
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/personal_keys.tsv');

    try {
      final header = 'MarketUUID\tManifestUUID\tTypePack\tKey';
      final content = '$header\n${uniqueLines.join('\n')}';

      await file.writeAsString(content);

      // Invalidate KeysService to force reload with new keys
      await KeysService.instance.invalidateKeys();

      if (validatedKeys.isNotEmpty) {
        // runs async so it doesnt get integrated into the loading ui
        unawaited(
          UploadKeysService.uploadKeysWithRetry(validatedKeys).catchError((e) {
            debugPrint('Upload error: $e');
            return false;
          }),
        );
      }
    } catch (e) {
      throw Exception('Failed to save processed keys: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchUUID({
    required String query,
    required String orderBy,
    required String select,
    required int top,
    required int skip,
    required dynamic customIds,
  }) async {
    String filterQuery;

    if (customIds is String) {
      filterQuery = "Id eq '$customIds'";
    } else if (customIds is List<String>) {
      filterQuery = customIds.map((id) => "Id eq '$id'").join(" or ");
    } else {
      throw ArgumentError(
        "Invalid type for customIds. It should be a String or List<String>.",
      );
    }

    final requestPayload = {
      "count": true,
      "query": query,
      "filter": filterQuery,
      "orderBy": orderBy,
      "scid": "4fc10100-5f7a-4470-899b-280835760c07",
      "select": select,
      "top": top,
      "skip": skip,
    };

    final response = await sendPlayFabRequest(
      "/Catalog/Search",
      requestPayload,
    );
    final items = response["Items"] as List<dynamic>? ?? [];

    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, Map<String, dynamic>>> multipleUUIDSearch(
    dynamic customId,
  ) async {
    const int maxSearch = 300;
    final Map<String, Map<String, dynamic>> resultsDict = {};

    List<String> customIds;
    if (customId is List<String>) {
      customIds = customId;
    } else if (customId is String) {
      customIds = [customId];
    } else {
      throw ArgumentError("customId must be either a String or List<String>");
    }

    for (int i = 0; i < customIds.length; i += maxSearch) {
      final chunk = customIds.skip(i).take(maxSearch).toList();

      final searchResult = await searchUUID(
        query: "",
        orderBy: "creationDate DESC",
        select: await _getSelect(),
        top: maxSearch,
        skip: 0,
        customIds: chunk,
      );

      if (searchResult.isNotEmpty) {
        for (final item in searchResult) {
          final id = item["Id"] as String?;
          if (id != null) {
            resultsDict[id] = item;
          }
        }
      } else {
        final endRange = (i + maxSearch < customIds.length)
            ? i + maxSearch
            : customIds.length;
        debugPrint("No results found for ${i + 1}-$endRange");
      }
    }

    return resultsDict;
  }

  // this gets the latest updated dlc/new dlc
  Future<List<String>> getProductIdsByHeaderComponent(String headerText) async {
    try {
      final queryData = {
        "filter": "(contentType eq 'QueryManifest_V2.1.0')",
        "orderBy": "CreationDate desc",
        "scid": "4fc10100-5f7a-4470-899b-280835760c07",
        "top": 5,
        "skip": 0,
      };
      final response = await sendPlayFabRequest('/Catalog/Search', queryData);
      if (response['Items'] == null || (response['Items'] as List).isEmpty) {
        return [];
      }

      final items = response['Items'] as List;
      Map<String, dynamic>? targetComponent;

      // Search through all items until we find the header
      // usually it should apppear on the first or second item in some cases
      for (final item in items) {
        final displayProperties = item['DisplayProperties'];
        if (displayProperties == null ||
            displayProperties['screenLayoutQueries'] == null) {
          continue;
        }

        final screenLayoutQueries =
            displayProperties['screenLayoutQueries'] as List;

        for (final query in screenLayoutQueries) {
          final headerComp = query['headerComp'];
          if (headerComp != null && headerComp['headerText'] == headerText) {
            targetComponent = query;
            break;
          }
        }

        if (targetComponent != null) {
          break;
        }
      }

      if (targetComponent == null) {
        debugPrint('No component with "$headerText" header found');
        return [];
      }

      final List<String> allUuids = [];
      final queries = targetComponent['queries'] as List?;
      if (queries != null) {
        for (final query in queries) {
          final queryProductIds = query['productIds'] as List?;
          if (queryProductIds != null) {
            for (final productId in queryProductIds) {
              if (productId is String && !allUuids.contains(productId)) {
                allUuids.add(productId);
              }
            }
          }
          final queryOrTags = query['orTags'] as List?;
          if (queryOrTags != null) {
            for (final orTag in queryOrTags) {
              if (orTag is String && !allUuids.contains(orTag)) {
                allUuids.add(orTag);
              }
            }
          }
        }
      }
      return allUuids;
    } catch (e) {
      debugPrint('Error in getProductIdsByHeaderComponent for $headerText: $e');
      if (e is PlayFabException) {
        rethrow;
      }
      throw PlayFabException(
        0,
        'Failed to get product IDs for header $headerText: ${e.toString()}',
      );
    }
  }

  Future<Map<String, Map<String, dynamic>>> getItemsByHeaderComponent(
    String headerText,
  ) async {
    try {
      final productIds = await getProductIdsByHeaderComponent(headerText);
      if (productIds.isEmpty) {
        debugPrint('No product IDs found for header: $headerText');
        return {};
      }
      final itemsMap = await multipleUUIDSearch(productIds);
      return itemsMap;
    } catch (e) {
      debugPrint('Error in getItemsByHeaderComponent for $headerText: $e');
      rethrow;
    }
  }

  static Map<String, String> _catalogTagFilters(String creatorId) => {
    'texture': "tags/any(t: t eq 'resourcepack')",
    'world': "tags/any(t: t eq 'worldtemplate')",
    'mashup': "tags/any(t: t eq 'mashup')",
    'addon': "tags/any(t: t eq 'addon')",
    'persona': "(contentType eq 'PersonaDurable')",
    'skin': "tags/any(t: t eq 'skinpack')",
    // Mojang id, other creators don't have capes so it would be kinda redundant to check
    if (creatorId == "master_player_account!301F442C3B63DC20")
      'capes': "(displayProperties/pieceType eq 'persona_capes')",
  };

  Future<Map<String, dynamic>> searchCreatorItemsPaginated(
    String creatorId, {
    String? contentType,
    String? searchTerm,
    int skip = 0,
    int top = 300,
  }) async {
    final tagsFilter = _catalogTagFilters(creatorId);

    List<String> filterParts = ["creatorId eq '$creatorId'"];

    if (contentType != null && tagsFilter.containsKey(contentType)) {
      filterParts.add(tagsFilter[contentType]!);
    }

    String filterQuery = filterParts.join(' and ');

    if (contentType != 'persona' && contentType != 'capes') {
      filterQuery =
          "contentType eq 'MarketplaceDurableCatalog_V1.2' and $filterQuery";
    }

    Map<String, dynamic> requestPayload = {
      'count': true,
      'filter': '($filterQuery)',
      'orderBy': 'startDate DESC',
      'scid': '4fc10100-5f7a-4470-899b-280835760c07',
      'select': await _getSelect(),
      'top': top,
      'skip': skip,
    };

    if (searchTerm != null && searchTerm.isNotEmpty) {
      final trimmedSearch = searchTerm.trim();
      // Wrap in quotes only if the search contains (multi-word) or special characters
      final needsQuotes =
          trimmedSearch.contains(' ') ||
          trimmedSearch.contains('[') ||
          trimmedSearch.contains(']') ||
          trimmedSearch.contains('(') ||
          trimmedSearch.contains(')') ||
          trimmedSearch.contains(':');
      final formattedSearch = needsQuotes ? '"$trimmedSearch"' : trimmedSearch;
      requestPayload['search'] = formattedSearch;
    }

    final response = await sendPlayFabRequest(
      '/Catalog/Search',
      requestPayload,
    );
    final int totalCount = response['Count'] ?? 0;

    final List<Map<String, dynamic>> items =
        (response['Items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];

    return {'items': items, 'totalCount': totalCount};
  }

  Future<Map<String, int>> getCreatorItemCount(String creatorId) async {
    final tagsFilter = _catalogTagFilters(creatorId);

    // Create a list of futures for all requests
    final List<Future<MapEntry<String, int>>> futures = tagsFilter.entries.map((
      entry,
    ) async {
      final String filterType = entry.key;
      final String filterQuery = entry.value;

      final Map<String, dynamic> requestPayload = {
        "count": true,
        "filter": "(creatorId eq '$creatorId' and $filterQuery)",
        "top": "1",
        "scid": "4fc10100-5f7a-4470-899b-280835760c07",
      };

      try {
        final response = await sendPlayFabRequest(
          "/Catalog/Search",
          requestPayload,
        );
        return MapEntry(
          filterType,
          response.containsKey('Count') ? response['Count'] as int? ?? 0 : 0,
        );
      } catch (e) {
        debugPrint('Error fetching count for $filterType: $e');
        return MapEntry(filterType, 0);
      }
    }).toList();

    final List<MapEntry<String, int>> results = await Future.wait(futures);

    return Map.fromEntries(results);
  }

  Future<List<Map<String, String>>> getCreators() async {
    final requestPayload = {
      "filter": "(contentType eq 'StoreConfig_V1.1')",
      "orderBy": "startDate desc",
      "scid": "4fc10100-5f7a-4470-899b-280835760c07",
    };

    final response = await sendPlayFabRequest(
      "/Catalog/Search",
      requestPayload,
    );
    final List<Map<String, String>> creators = [];

    if (response.containsKey('Items') &&
        response['Items'] is List &&
        response['Items'].isNotEmpty) {
      final firstItem = response['Items'][0];
      if (firstItem.containsKey('DisplayProperties') &&
          firstItem['DisplayProperties'].containsKey('storeFilters')) {
        final filters = firstItem['DisplayProperties']['storeFilters'];
        for (var filterItem in filters) {
          if (filterItem['filterType'] == 'creator' &&
              filterItem.containsKey('toggles')) {
            for (var toggle in filterItem['toggles']) {
              creators.add({
                'filterId': toggle['filterId'] ?? '',
                'filterName': toggle['filterName'] ?? '',
              });
            }
          }
        }
      }
    }

    return creators;
  }
}
