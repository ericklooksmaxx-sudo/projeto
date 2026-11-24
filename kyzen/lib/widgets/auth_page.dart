import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:kyzen/microsoft_auth/linux_deep_link.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../microsoft_auth/live_auth.dart';
import '../microsoft_auth/xbox_auth.dart';
import '../api/playfabapi.dart';
import '../api/mc_api.dart';
import '../api/minecraft_endpoint_service.dart';
import '../decrypt/receipt_keys.dart';
import '../services/key_service.dart';
import 'package:app_links/app_links.dart';
import '../services/minecoin_state_auth.dart';
import '../services/settings_service.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import '../services/cart_service.dart';
import 'cart_page.dart';
import '../services/search_service.dart';
import 'styled_buttons.dart';
import 'auth_dlc_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.keysService,
    required this.searchService,
    this.onBack,
    required this.pageSize,
  });
  final KeysService keysService;
  final SearchService searchService;
  final VoidCallback? onBack;
  final int pageSize;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isFullyAuthenticated = false;
  String? _statusMessage;
  String? _authUrl;
  LiveConnectAuth? _auth;
  int _receiptKeysCount = 0;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final SettingsService _settingsService = SettingsService.instance;
  final MinecoinService _minecoinService = MinecoinService.instance;
  final MinecraftApi _minecraftApi = MinecraftApi.instance;
  final PlayFabClient _client = PlayFabClient.instance;
  final CartService _cartService = CartService();
  bool _onlyNewKeys = false;
  String? _xuid;
  String? _avatarUrl;
  String? _username;
  bool _avatarFailed = false;
  bool _linuxDesktopEntryCreated = false;
  int? _minecoinBalance;
  bool _isLoadingBalance = false;
  int _cartCount = 0;

  String? _cachedMcToken;
  DateTime? _mcTokenExpiry;
  String? _cachedEntityToken;
  DateTime? _entityTokenExpiry;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserData();
    _initializeCart();
    _initializeAppState();
  }

  Future<void> _initializeAppState() async {
    await _loadCachedPlayFabTokens();
    await _initializeAuth();
    await _loadMinecoinBalance();
  }

  bool _isDesktop() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _cleanupLinuxDeepLink();
    _auth = null;
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final onlyNewKeys = await _settingsService.getKeyExport();
      if (mounted) {
        setState(() {
          _onlyNewKeys = onlyNewKeys;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final userDataFile = File('${documentsDir.path}/user_data.json');

      if (await userDataFile.exists()) {
        final jsonString = await userDataFile.readAsString();
        final userData = json.decode(jsonString) as Map<String, dynamic>;

        final xuid = userData['xuid'] as String?;

        if (mounted) {
          setState(() {
            _xuid = xuid;
            _avatarUrl = MinecraftEndpoints.profileAvatarUrl(xuid);
            _username = userData['username'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _saveUserData() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final userDataFile = File('${documentsDir.path}/user_data.json');

      final userData = {'xuid': _xuid, 'username': _username};

      await userDataFile.writeAsString(json.encode(userData));
    } catch (e) {
      debugPrint('Error saving user data: $e');
    }
  }

  Future<void> _clearUserData() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final userDataFile = File('${documentsDir.path}/user_data.json');

      if (await userDataFile.exists()) {
        await userDataFile.delete();
      }
      if (mounted) {
        setState(() {
          _xuid = null;
          _avatarUrl = null;
          _username = null;
        });
      }
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  Future<void> _loadCachedPlayFabTokens() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tokenFile = File(
        '${documentsDir.path}/${_client.tokenCacheFileName}.json',
      );

      if (await tokenFile.exists()) {
        final jsonString = await tokenFile.readAsString();
        final tokenData = json.decode(jsonString) as Map<String, dynamic>;

        final mcTokenExpiry = DateTime.parse(tokenData['mcTokenExpiry']);
        final entityTokenExpiry = DateTime.parse(
          tokenData['entityTokenExpiry'],
        );

        // Check if tokens are still valid
        if (DateTime.now().isBefore(mcTokenExpiry) &&
            DateTime.now().isBefore(entityTokenExpiry)) {
          if (!mounted) return;
          setState(() {
            _cachedMcToken = tokenData['mcToken'];
            _mcTokenExpiry = mcTokenExpiry;
            _cachedEntityToken = tokenData['entityToken'];
            _entityTokenExpiry = entityTokenExpiry;
          });

          // Restore entity token to personal headers
          if (_cachedEntityToken != null) {
            _client.restorePersonalEntityToken(_cachedEntityToken!);
          }
        } else {
          await tokenFile.delete();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached PlayFab tokens: $e');
    }
  }

  // Save mcToken and EntityToken to cache
  Future<void> _savePlayFabTokensToCache({
    required String mcToken,
    required DateTime mcTokenExpiry,
    required String entityToken,
    required DateTime entityTokenExpiry,
  }) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tokenFile = File(
        '${documentsDir.path}/${_client.tokenCacheFileName}.json',
      );

      final tokenData = {
        'mcToken': mcToken,
        'mcTokenExpiry': mcTokenExpiry.toIso8601String(),
        'entityToken': entityToken,
        'entityTokenExpiry': entityTokenExpiry.toIso8601String(),
      };

      await tokenFile.writeAsString(json.encode(tokenData));
      if (!mounted) return;
      setState(() {
        _cachedMcToken = mcToken;
        _mcTokenExpiry = mcTokenExpiry;
        _cachedEntityToken = entityToken;
        _entityTokenExpiry = entityTokenExpiry;
      });
    } catch (e) {
      debugPrint('Error saving PlayFab tokens to cache: $e');
    }
  }

  // Clear cached mcToken/EntityToken
  Future<void> _clearPlayFabTokenCache() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tokenFile = File(
        '${documentsDir.path}/${_client.tokenCacheFileName}.json',
      );

      if (await tokenFile.exists()) {
        await tokenFile.delete();
      }
      if (!mounted) return;
      setState(() {
        _cachedMcToken = null;
        _mcTokenExpiry = null;
        _cachedEntityToken = null;
        _entityTokenExpiry = null;
      });
    } catch (e) {
      debugPrint('Error clearing PlayFab token cache: $e');
    }
  }

  // Check if cached mcToken is still valid
  bool _isMcTokenValid() {
    if (_cachedMcToken == null || _mcTokenExpiry == null) {
      return false;
    }
    if (_cachedEntityToken == null || _entityTokenExpiry == null) {
      return false;
    }
    return DateTime.now().isBefore(_mcTokenExpiry!) &&
        DateTime.now().isBefore(_entityTokenExpiry!);
  }

  Future<void> _updateOnlyNewKeysSetting(bool value) async {
    try {
      await _settingsService.setKeyExport(value);
      if (mounted) {
        setState(() {
          _onlyNewKeys = value;
        });
      }
    } catch (e) {
      debugPrint('Error updating settings: $e');
    }
  }

  Future<void> _initializeAppLinks() async {
    _appLinks = AppLinks();

    // Handle app links when the app is already running
    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('App link error: $err');
      },
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme == 'ms-xal-0000000048183522' && uri.host == 'auth') {
      if (_isAuthenticated || _isLoading) {
        return;
      }

      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        setState(() {
          _statusMessage = context.l10n.authenticationFailed(error);
          _isLoading = false;
        });
        return;
      }

      if (code != null) {
        setState(() {
          _isLoading = true;
          _statusMessage = context.l10n.exchangingToken;
        });

        try {
          await _auth!.exchangeCodeForToken(code: code);

          setState(() {
            _isAuthenticated = true;
            _statusMessage = context.l10n.authenticationSuccessful;
            _isLoading = false;
            _authUrl = null;
          });

          await _completeFullAuthentication();
        } catch (e) {
          debugPrint('Token exchange error: $e');
          setState(() {
            _statusMessage = context.l10n.failedToExchangeToken(e.toString());
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _statusMessage = context.l10n.noAuthorizationCodeReceived;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeAuth() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final tokenPath = '${documentsDir.path}/personal_token.json';

    _auth = LiveConnectAuth(tokenFilePath: tokenPath);
    await _checkExistingAuth();
    await _loadKeysCount();
  }

  Future<void> _loadKeysCount() async {
    try {
      final receiptCount = await widget.keysService.getKeysCount(
        KeysFileType.receipt,
      );

      if (mounted) {
        setState(() {
          _receiptKeysCount = receiptCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading keys count: $e');
    }
  }

  Future<void> _copyKeys(KeysFileType fileType) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final formattedKeys = await widget.keysService.getFormattedKeysAsString(
        fileType,
      );

      if (formattedKeys.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = context.l10n.noNewKeysCopy;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.noNewKeysCopy),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      await widget.keysService.copyKeysToClipboard(formattedKeys);

      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.keysCopyClipboard;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.keysCopyClipboard),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.errorCopyingKeys(e.toString());
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorCopyingKeys(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareKeys(KeysFileType fileType) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final formattedKeys = await widget.keysService.getFormattedKeysAsString(
        fileType,
      );

      if (formattedKeys.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = context.l10n.noNewKeysShare;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.noNewKeysShare),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      await widget.keysService.shareKeys(fileType, formattedKeys);

      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.keysShared;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.errorSharingKeys(e.toString());
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorSharingKeys(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveKeys(KeysFileType fileType) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final formattedKeys = await widget.keysService.getFormattedKeysAsString(
        fileType,
      );

      if (formattedKeys.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = context.l10n.noNewKeysShare;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.noNewKeysShare),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      await widget.keysService.saveKeys(fileType, formattedKeys);

      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.keysSaved;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.keysSavedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.errorSavingKeys(e.toString());
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorSavingKeys(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error saving keys: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkExistingAuth() async {
    if (_auth == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _statusMessage = context.l10n.authCheck;
      });
    }

    try {
      final isAuthenticated = await _auth!.isAuthenticated();

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
          _statusMessage = isAuthenticated
              ? context.l10n.alreadyAuth
              : context.l10n.readyAuth;
        });
      }

      if (isAuthenticated && _isMcTokenValid()) {
        if (mounted) {
          setState(() {
            _isFullyAuthenticated = true;
          });
        }
      } else if (isAuthenticated) {
        await _completeFullAuthentication();
      }
    } catch (e) {
      debugPrint('Unexpected error during auth check: $e');

      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _statusMessage = context.l10n.readyAuth;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cleanupLinuxDeepLink() async {
    if (!Platform.isLinux) return;

    try {
      await LinuxDeepLink.cleanupTempDesktopEntries();
    } catch (e) {
      debugPrint('Error deleting temporary desktop entries: $e');
    } finally {
      _linuxDesktopEntryCreated = false;
    }
  }

  /// Generates the Authorization URL and displays it in a card
  Future<void> _startAuthentication() async {
    if (_auth == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate the authorization URL
      final authUrl = _auth!.getAuthorizationUrl();

      if (Platform.isLinux && !_linuxDesktopEntryCreated) {
        await LinuxDeepLink.createTempDesktopEntry();
        _linuxDesktopEntryCreated = true;
      }

      // Initialize app links when we need to handle the callback
      await _initializeAppLinks();

      setState(() {
        _authUrl = authUrl;
        _statusMessage = context.l10n.authURL;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Authentication URL generation error: $e');
      _cleanupLinuxDeepLink();
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error generating authentication URL: $e';
      });
    }
  }

  Future<void> _loadMinecoinBalance({bool forceRefresh = false}) async {
    if (!_isFullyAuthenticated) {
      return;
    }

    if (_minecoinService.hasLoadedMinecoinBalance && !forceRefresh) {
      setState(() {
        _minecoinBalance = _minecoinService.minecoinBalance;
      });
      return;
    }

    if (_cachedMcToken == null || !_isMcTokenValid()) {
      return;
    }

    setState(() {
      _isLoadingBalance = true;
    });

    try {
      final balance = await _minecraftApi.getMinecoinBalance(
        _cachedMcToken!,
        true,
      );

      _minecoinService.setBalance(balance);

      if (mounted) {
        setState(() {
          _minecoinBalance = balance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Minecoin balance: $e');
      _minecoinService.reset();
      if (mounted) {
        setState(() {
          _minecoinBalance = null;
          _isLoadingBalance = false;
        });
      }
    }
  }

  Future<void> _initializeCart() async {
    await _cartService.initialize();
    if (mounted) {
      setState(() {
        _cartCount = _cartService.getCartCount();
      });
    }
  }

  void _updateCartCount(int newCount) {
    if (mounted) {
      setState(() {
        _cartCount = newCount;
      });
    }
  }

  /// Launches the generated auth URL in the browser
  Future<void> _launchUrl() async {
    if (_authUrl == null) return;

    try {
      final uri = Uri.parse(_authUrl!);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );

      if (launched) {
        setState(() {
          _statusMessage = context.l10n.completeAuth;
        });
      } else {
        setState(() {
          _statusMessage = context.l10n.authPageFail;
        });
      }
    } catch (e) {
      debugPrint('Launch URL error: $e');
      setState(() {
        _statusMessage = context.l10n.errorOpeningAuthPage(e.toString());
      });
    }
  }

  Future<void> _logout() async {
    if (_auth == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = context.l10n.logout;
    });

    try {
      await _auth!.clearStoredToken();
      await _clearUserData();
      await _clearPlayFabTokenCache();
      _minecoinService.reset();
      _client.clearPersonalHeaders();

      setState(() {
        _isAuthenticated = false;
        _isFullyAuthenticated = false;
        _minecoinBalance = null;
        _statusMessage = context.l10n.logoutOk;
        _authUrl = null;
        _avatarUrl = null;
        _username = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error logging out: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _completeFullAuthentication() async {
    if (_auth == null || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isMcTokenValid()) {
        setState(() {
          _statusMessage = context.l10n.usingCachedSession;
          _isFullyAuthenticated = true;
          _isLoading = false;
        });
        await _loadMinecoinBalance();
        return;
      }

      if (!mounted) return;
      setState(() => _statusMessage = context.l10n.loadingMinecraftKeys);

      final oauthToken = await _auth!.getToken();
      final xboxAuth = XboxAuthService();

      if (!mounted) return;
      setState(() => _statusMessage = context.l10n.requestingXboxLiveToken);
      final xblToken = await xboxAuth.requestXBLToken(oauthToken);

      if (!mounted) return;
      setState(() => _statusMessage = context.l10n.loggingInToPlayFab);
      final loginResult = await _client.loginWithXbox(
        xblToken.authorizationHeader,
      );

      if (loginResult.xboxUserId != null) {
        final xuid = loginResult.xboxUserId!;
        if (!mounted) return;
        setState(() {
          _xuid = xuid;
          _avatarUrl = MinecraftEndpoints.profileAvatarUrl(xuid);
        });
      }

      if (!mounted) return;
      setState(() => _statusMessage = context.l10n.gettingUserInformation);
      try {
        final username = await _client.getUserPublisherData();
        if (username != null) {
          if (!mounted) return;
          setState(() {
            _username = username;
          });
        }
      } catch (e) {
        debugPrint('Error getting publisher data: $e');
      }

      await _saveUserData();

      if (!mounted) return;
      setState(() => _statusMessage = context.l10n.gettingEntityToken);
      final entityTokenResult = await _client.getEntityTokenPersonal(
        loginResult.playFabId,
      );

      if (!mounted) return;
      setState(() => _statusMessage = context.l10n.startingMinecraftSession);
      final mcTokenResult = await _minecraftApi.startMinecraftSession(
        loginResult.sessionTicket,
        true,
      );

      await _savePlayFabTokensToCache(
        mcToken: mcTokenResult['token'],
        mcTokenExpiry: mcTokenResult['expiry'],
        entityToken: entityTokenResult.entityToken,
        entityTokenExpiry: entityTokenResult.tokenExpiration,
      );

      if (!mounted) return;
      setState(() {
        _isFullyAuthenticated = true;
        _statusMessage = context.l10n.loadingMinecoinBalance;
      });

      await _loadMinecoinBalance(forceRefresh: true);

      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.authenticationSuccessful;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error completing authentication: $e';
        _isFullyAuthenticated = false;
      });

      if (_cachedMcToken != null) {
        await _clearPlayFabTokenCache();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadKeys() async {
    if (_auth == null || !_isFullyAuthenticated) {
      setState(() {
        _statusMessage = context.l10n.completeAuthFirst;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String mcToken;

      if (_isMcTokenValid()) {
        setState(() => _statusMessage = context.l10n.usingCachedSession);
        mcToken = _cachedMcToken!;
      } else {
        // If token expired, re-authenticate
        await _completeFullAuthentication();
        if (!_isMcTokenValid()) {
          throw Exception('Failed to refresh Minecraft session');
        }
        mcToken = _cachedMcToken!;
      }

      setState(() => _statusMessage = context.l10n.loadingMinecraftInventory);
      final inventory = await _minecraftApi.getMinecraftInventory(
        mcToken,
        true,
      );
      final keyCount = await ReceiptProcessor.processBase64Receipt(
        inventory['result']['receipt'],
      );

      // we clear cache used on auth dlc page so it should automatically fetch the new data
      widget.searchService.clearCache(KeysFileType.receipt);

      setState(() {
        _statusMessage = context.l10n.successfullyLoadedKeys(keyCount);
      });

      await _loadKeysCount();
    } catch (e) {
      if (!mounted) return;
      String errorMessage;

      final errorString = e.toString().toLowerCase();

      if (errorString.contains('401') || errorString.contains('unauthorized')) {
        errorMessage = context.l10n.sessionExpired;
        if (_cachedMcToken != null) {
          await _clearPlayFabTokenCache();
        }
      } else if (errorString.contains('403') ||
          errorString.contains('forbidden')) {
        errorMessage = context.l10n.accessDenied;
      } else if (errorString.contains('timeout') ||
          errorString.contains('connection')) {
        errorMessage = context.l10n.connectionTimeout;
      } else if (errorString.contains('500') ||
          errorString.contains('502') ||
          errorString.contains('503')) {
        errorMessage = context.l10n.serverError;
      } else {
        errorMessage = mounted
            ? context.l10n.errorLoadingKeys(e.toString())
            : 'Error loading keys: $e';
      }

      if (mounted) {
        setState(() {
          _statusMessage = errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.copyClipboard),
        duration: const Duration(milliseconds: 440),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // display back button on the drawer view
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: context.l10n.backToSettings,
              )
            : null,
        title: Text(context.l10n.microsoftAuth),
        forceMaterialTransparency: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_username != null) _buildUserGreeting(),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Stack(
                        children: [
                          Align(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isFullyAuthenticated
                                      ? Icons.check_circle
                                      : Icons.account_circle,
                                  size: 48,
                                  color: _isFullyAuthenticated
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isFullyAuthenticated
                                      ? context.l10n.authOk
                                      : context.l10n.authNotOk,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                if (_statusMessage != null)
                                  Text(
                                    _statusMessage!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                          if (_isFullyAuthenticated && _minecoinBalance != null)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                                    width: 1.1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/minecoin.png',
                                      width: 20,
                                      height: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_minecoinBalance',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 2),
                                    _isLoadingBalance
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : InkWell(
                                            onTap: () => _loadMinecoinBalance(
                                              forceRefresh: true,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3),
                                              child: Icon(
                                                Icons.refresh,
                                                size: 16,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_authUrl != null) ...[
                    const SizedBox(height: 5),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.link,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n.urlAuth,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _authUrl!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontFamily: 'monospace'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 3,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _copyToClipboard(_authUrl!),
                                    icon: const Icon(Icons.copy),
                                    tooltip: context.l10n.copyUrl,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _launchUrl,
                                    icon: const Icon(Icons.open_in_browser),
                                    label: Text(
                                      context.l10n.openAuthPageButton,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  if (_receiptKeysCount > 0) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.key,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.loadedKeys,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    Text(
                                      '$_receiptKeysCount',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    context.l10n.exportNewKeys,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                Switch(
                                  value: _onlyNewKeys,
                                  onChanged: _updateOnlyNewKeysSetting,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: StyledButton(
                                    onTap: () =>
                                        _copyKeys(KeysFileType.receipt),
                                    icon: Icons.copy,
                                    label: context.l10n.copy,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: StyledButton(
                                    onTap: () => _isDesktop()
                                        ? _saveKeys(KeysFileType.receipt)
                                        : _shareKeys(KeysFileType.receipt),
                                    icon: _isDesktop()
                                        ? Icons.save
                                        : Icons.share,
                                    label: _isDesktop()
                                        ? context.l10n.save
                                        : context.l10n.share,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            StyledButton(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AuthDlcPage(
                                      keysService: widget.keysService,
                                      searchService: widget.searchService,
                                      pageSize: widget.pageSize,
                                    ),
                                  ),
                                );
                              },
                              icon: Icons.open_in_new_rounded,
                              label: context.l10n.openDlcsList,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_isFullyAuthenticated)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _loadKeys,
                          icon: const Icon(Icons.key),
                          label: Text(context.l10n.loadKeysButton),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: Text(context.l10n.logoutButton),
                        ),
                      ],
                    )
                  else if (_isAuthenticated && !_isFullyAuthenticated)
                    // User has OAuth token but needs to complete full auth
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _completeFullAuthentication,
                          icon: const Icon(Icons.sync),
                          label: Text(context.l10n.completeAuthButton),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: Text(context.l10n.logoutButton),
                        ),
                      ],
                    )
                  else if (_authUrl == null)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _startAuthentication,
                        icon: const Icon(Icons.login),
                        label: Text(context.l10n.startAuthButton),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_isFullyAuthenticated)
            // cart icon
            Positioned(
              top: 0,
              right: 8,
              child: Material(
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartPage(
                          searchService: widget.searchService,
                          pageSize: widget.pageSize,
                          onCartChanged: _updateCartCount,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          size: 28,
                        ),
                        if (_cartCount > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  '$_cartCount',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserGreeting() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final double avatarWidth = (availableWidth * 0.40).clamp(120.0, 250.0);

        final usernameText = RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.headlineSmall,
            children: [
              TextSpan(text: context.l10n.greetings),
              TextSpan(
                text: _username!,
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '!'),
            ],
          ),
        );

        final avatarSlot = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: avatarWidth,
            height: avatarWidth * (4 / 3),
            child: _avatarBox(),
          ),
        );

        return Row(
          children: [
            avatarSlot,
            Expanded(child: usernameText),
          ],
        );
      },
    );
  }

  Widget _avatarBox() {
    if (_avatarUrl == null || _avatarFailed) {
      return Image.asset('assets/avatar.png', fit: BoxFit.cover);
    }
    return FadeInImage.assetNetwork(
      placeholder: 'assets/avatar.png',
      image: _avatarUrl!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 100),
      imageErrorBuilder: (ctx, err, st) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_avatarFailed) {
            setState(() {
              _avatarFailed = true;
            });
          }
        });
        return Image.asset('assets/avatar.png', fit: BoxFit.cover);
      },
    );
  }
}
