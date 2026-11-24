import 'dart:math';
import 'package:flutter/services.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'models/search_result.dart';
import 'models/home_discovery_data.dart';
import 'services/auth_service.dart';
import 'services/search_service.dart';
import 'services/download_service.dart';
import 'services/emote_service.dart';
import 'services/skin_service.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/search_result_item.dart';
import 'widgets/search_result_grid_item.dart';
import 'widgets/home_discovery_view.dart';
import 'widgets/bottom_navigation.dart';
import 'widgets/downloads_tab.dart';
import 'api/playfabapi.dart';
import 'decrypt/dlc_dec.dart';
import 'services/permission.dart';
import 'dart:io';
import 'services/key_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/custom_toast.dart';
import 'widgets/creators_list.dart';
import 'widgets/settings_tab.dart';
import 'services/settings_service.dart';
import 'services/key_filter.dart';
import 'widgets/theme.dart';
import 'widgets/debug_terminal.dart';
import 'l10n/app_localizations.dart';
import 'widgets/loading_screen.dart';
import 'services/notifications/notification_service.dart';
import 'services/background_service.dart';
import 'decrypt/entitlement.dart';
import 'microsoft_auth/windows_deep_link.dart';
import 'services/android_deep_link_dlc.dart';
import 'widgets/auth_page.dart';
import 'services/favorite_service.dart';
import 'widgets/update_dialog.dart';
import 'widgets/free_droid_warn_dialog.dart';
import 'widgets/notification_permission_dialog.dart';
import 'widgets/key_server_restriction_dialog.dart';
import 'widgets/announcements_tab.dart';
import 'services/announcements_service.dart';
import 'kyzen/gate/gate_page.dart';
import 'kyzen/kz_boot.dart';
import 'kyzen/gate/pass_service.dart';
import 'kyzen/kz_surface.dart';
import 'kyzen/kz_theme.dart';
import 'kyzen/kz_top_bar.dart';

void main() async {
  setupDebugPrint();
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      AppTheme.getSystemOverlayStyle(isDark: true),
    );
  }
  await NotificationService.initialize();
  await ForegroundDownloadService.initialize();
  await KzPass.instance.init();
  await WindowsDeepLinkRegistration.registerMicrosoftAuthScheme();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool isDark = true;
  String? colorScheme;
  Color? customColor;
  String _currentLanguage = 'en';
  bool _useMinecraftFont = false;
  final SearchController _searchController = SearchController();
  final PlayFabClient _client = PlayFabClient();
  final favoriteService = FavoriteService();
  late final AuthService _authService;
  late final SearchService _searchService;
  late final SettingsService _settingsService;

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<DownloadsTabState> _downloadsKey = GlobalKey();
  late final Widget _downloadsTab;
  final PageStorageBucket _bucket = PageStorageBucket();
  String? _loadingKey = 'apiLogin';
  final StoragePermissionHandler _permissionHandler =
      StoragePermissionHandler();
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DeepLinkService _deepLinkService = DeepLinkService();
  bool _hasDeepLink = false;
  bool _needToCheckPostStartupDialogs = false;

  int? _newKeysCount;
  String? _errorMessage;
  bool _needToShowMessages = false;
  bool _hasKeyNetworkRestrictionError = false;

  String _selectedSearchType = 'discovery'; // Track search type
  String _sortOrder = 'relevance'; // Track order type
  String _keyFilter = KeyFilterType.showAll;
  int _drawerSelectedIndex = 0;
  String _currentSearchQuery = '';

  // Discovery state
  HomeDiscoveryData? _discoveryData;
  bool _isLoadingDiscovery = false;
  String? _discoveryError;

  // Pagination state variables
  bool _isLoadingMore = false;
  int _pageSize = 30; // max is 300
  static const int _maxSkip = 10000;
  int _rawTotalCount = 0;
  int _currentSkip = 0;

  late ScrollController _scrollController;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) {
      AnnouncementsService.markAsRead();
    }
  }

  @override
  void initState() {
    super.initState();
    _downloadsTab = DownloadsTab(key: _downloadsKey);
    _scrollController = ScrollController()..addListener(_onScroll);
    _settingsService = SettingsService.instance;
    _settingsService.loadSettings();
    _loadSettings();
    _authService = AuthService(_client);
    _searchService = SearchService(_client, _authService, _settingsService);

    _deepLinkService.initialize(
      onDeepLinkReceived: _handleDeepLink,
      onUnlockReceived: _handleUnlockLink,
    );
    _authenticateAndInitialize();
  }

  // clean up
  @override
  void dispose() {
    try {
      Decryptor.dispose();
      PlayFabClient.dispose();
      _scrollController.removeListener(_onScroll);
      _scrollController.dispose();
      _deepLinkService.dispose();
    } catch (e) {
      debugPrint('Error during disposal: $e');
    }
    super.dispose();
  }

  static const Set<String> _sortingOptions = {
    'relevance',
    'startDate DESC',
    'startDate ASC',
    'Rating/TotalCount desc',
    'Rating/TotalCount asc',
  };

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
      if (!_isPaginatedSearchType ||
          !_hasMoreItems() ||
          _isLoading ||
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

  bool _hasMoreItems() {
    return _currentSkip < _rawTotalCount && _currentSkip < _maxSkip;
  }

  Future<void> _authenticateAndInitialize() async {
    if (mounted) setState(() => _loadingKey = 'apiLogin');
    await KzBoot.tryStep(
      'playfab login',
      _authenticate,
      timeout: const Duration(seconds: 45),
    );

    if (Platform.isWindows) {
      if (mounted) setState(() => _loadingKey = 'processingEntitlement');
      await KzBoot.tryStep('entitlement', _processEntitlement);
    }

    if (mounted) setState(() => _loadingKey = 'checkingKeys');
    await KzBoot.tryStep(
      'keys',
      _initializeKeysAndStartupSearch,
      timeout: const Duration(seconds: 60),
    );

    KzBoot.mark('opening the app');
    if (mounted) {
      setState(() {
        _loadingKey = null;
        _needToCheckPostStartupDialogs = true;
      });
    }

    if (!_hasDeepLink) {
      if (_selectedSearchType == 'discovery') {
        await KzBoot.tryStep(
          'discovery',
          _loadDiscovery,
          timeout: const Duration(seconds: 45),
        );
      } else {
        await KzBoot.tryStep(
          'first search',
          () => _performSearch('', filter: 'default', pageSize: _pageSize),
        );
      }
    }
  }

  Future<void> _processEntitlement() async {
    try {
      await Entitlement.run();
    } catch (e) {
      debugPrint('Entitlement processing error: $e');
    }
  }

  Future<void> _initializeKeysAndStartupSearch() async {
    setState(() {
      _newKeysCount = null;
      _errorMessage = null;
      _hasKeyNetworkRestrictionError = false;
    });

    try {
      final keyUpdateEnabled = await KzBoot.step(
        'read settings',
        _settingsService.getKeyUpdate,
      );

      int count = 0;
      if (keyUpdateEnabled) {
        count = await KzBoot.step(
          'download keys',
          () => KeysService.instance.initialize(download: true),
        );
      } else {
        count = await KzBoot.step('load keys', KeysService.instance.loadKeys);
      }

      if (count > 0 && keyUpdateEnabled) {
        setState(() {
          _newKeysCount = count;
          _needToShowMessages = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading keys: $e');
      if (KeysService.isNetworkOrRestrictedError(e)) {
        setState(() {
          _hasKeyNetworkRestrictionError = true;
        });
      } else {
        setState(() {
          _errorMessage = 'Error loading keys: $e';
          debugPrint(_errorMessage);
          _needToShowMessages = true;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await Future.wait([
        _settingsService.getDarkMode(),
        _settingsService.getColorScheme(),
        _settingsService.getCustomColor(),
        _settingsService.getLanguage(),
        _settingsService.getPageSize(),
        _settingsService.getFont(),
        _settingsService.getKeyFilter(),
      ]);

      if (mounted) {
        final dark = settings[0] as bool;
        setState(() {
          isDark = dark;
          colorScheme = settings[1] as String?;
          customColor = settings[2] as Color?; // Set custom color
          _currentLanguage = settings[3] as String; // Set language
          _pageSize = settings[4] as int; // Set page size
          _useMinecraftFont = settings[5] as bool;
          _keyFilter = settings[6] as String;
        });
        if (Platform.isAndroid) {
          SystemChrome.setSystemUIOverlayStyle(
            AppTheme.getSystemOverlayStyle(isDark: dark),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _showPendingMessages(BuildContext context) {
    if (!_needToShowMessages) return;

    _needToShowMessages = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_newKeysCount != null) {
        CustomToast.showToast(
          context: context,
          message: context.l10n.addedNewKeys(_newKeysCount!),
        );
        setState(() => _newKeysCount = null);
      }

      if (_errorMessage != null) {
        CustomToast.showToast(
          context: context,
          message: _errorMessage!,
          isSuccess: false,
        );
        setState(() => _errorMessage = null);
      }
    });
  }

  Future<void> _checkAndRequestPermissions(BuildContext context) async {
    await _permissionHandler.requestStoragePermission();
    if (!context.mounted) return;

    final status = await _permissionHandler.requestNotificationPermission();
    if (!context.mounted) return;

    if (status.isPermanentlyDenied) {
      await NotificationPermissionDialog.show(context);
    }
  }

  Future<void> _authenticate() async {
    try {
      await PlayFabClient.instance.initEnvironment();
      await _authService.authenticate();
    } catch (e) {
      _showMessage('Authentication error: $e');
    }
  }

  void _showMessage(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onLanguageChanged(String languageCode) {
    setState(() {
      _currentLanguage = languageCode;
    });
  }

  void _handlePageSizeChange(int newSize) {
    setState(() {
      _pageSize = newSize;
    });
  }

  Future<void> _performSearch(
    String query, {
    String? filter,
    int? pageSize,
  }) async {
    final searchFilter = filter ?? _selectedSearchType;

    final keyFilter = await _settingsService.getKeyFilter();
    _keyFilter = keyFilter;
    if (keyFilter == KeyFilterType.onlyNotAvailable &&
        (searchFilter == 'skin' || searchFilter == 'persona')) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _searchResults.clear();
        _rawTotalCount = 0;
        _isLoadingMore = false;
        _currentSearchQuery = query;
        _selectedSearchType = searchFilter;
        _currentSkip = 0;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults.clear();
      _rawTotalCount = 0;
      _isLoadingMore = false;
      _currentSearchQuery = query;
      _selectedSearchType = searchFilter;
      _currentSkip = 0;
    });

    final effectivePageSize = pageSize ?? _pageSize;

    try {
      final response = await _searchService.performSearch(
        query,
        filter: searchFilter,
        orderBy: _sortOrder,
        top: effectivePageSize,
      );

      if (!mounted ||
          _currentSearchQuery != query ||
          _selectedSearchType != searchFilter) {
        return;
      }

      var items = response['items'] as List<dynamic>;
      final totalCount = response['count'] as int;
      var skip = effectivePageSize;

      // if initial batch returned 0 items due to client-side filtering,
      // continue fetching subsequent batches while items is empty and more items exist
      while (items.isEmpty &&
          skip < totalCount &&
          skip < _maxSkip &&
          _isPaginatedSearchType) {
        final nextResponse = await _searchService.performSearch(
          query,
          filter: searchFilter,
          orderBy: _sortOrder,
          skip: skip,
          top: effectivePageSize,
        );

        if (!mounted ||
            _currentSearchQuery != query ||
            _selectedSearchType != searchFilter) {
          return;
        }

        final nextItems = nextResponse['items'] as List<dynamic>;
        items.addAll(nextItems);
        skip += effectivePageSize;
      }

      setState(() {
        _searchResults = items;
        _rawTotalCount = totalCount;
        _currentSkip = skip;
        _isLoading = false;
      });

      _checkAndAutoLoadMore();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  bool get _isPaginatedSearchType => !{
    'creator',
    'update',
    'new_dlc',
    'favorite',
    'discovery',
  }.contains(_selectedSearchType);

  Future<void> _loadDiscovery({bool forceRefresh = false}) async {
    if (_isLoadingDiscovery && !forceRefresh) return;

    setState(() {
      _isLoadingDiscovery = true;
      _discoveryError = null;
    });

    try {
      final data = await _searchService.getHomeDiscovery(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _discoveryData = data;
        _isLoadingDiscovery = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _discoveryError = e.toString();
        _isLoadingDiscovery = false;
      });
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_isPaginatedSearchType || !_hasMoreItems()) {
      return;
    }

    setState(() => _isLoadingMore = true);

    final currentQuery = _currentSearchQuery;
    final currentFilter = _selectedSearchType;
    final currentOrder = _sortOrder;
    final currentSkip = _currentSkip;

    try {
      final response = await _searchService.performSearch(
        currentQuery,
        filter: currentFilter,
        orderBy: currentOrder,
        skip: currentSkip,
        top: _pageSize,
      );

      if (!mounted ||
          _currentSearchQuery != currentQuery ||
          _selectedSearchType != currentFilter ||
          _sortOrder != currentOrder) {
        return;
      }

      final items = response['items'] as List<dynamic>;

      setState(() {
        _searchResults.addAll(items);
        _currentSkip += _pageSize; // Increment by page size
        _isLoadingMore = false;
      });

      _checkAndAutoLoadMore();
    } catch (e) {
      if (!mounted) return;
      debugPrint('Load more error: $e');
      _showMessage('Failed to load more items: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  void _handleDeepLink(String uuid) {
    _hasDeepLink = true;

    // Switch to home tab if not already there
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }

    setState(() {
      _searchController.text = uuid;
    });

    _performSearch(uuid);
  }

  /// Back from the gate: redeem the one-shot code the browser handed over.
  Future<void> _handleUnlockLink(String code) async {
    final String? error = await KzPass.instance.claim(code);
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx == null || !mounted) return;

    CustomToast.showToast(
      context: ctx,
      message: error ?? 'Downloads unlocked for 24 hours.',
      isSuccess: error == null,
    );
    if (error != null) return;

    // cold start through the unlock link: bring the pack the user came for
    final String? pending = KzPass.instance.takePendingDlcId();
    if (pending != null && _navigatorKey.currentState?.canPop() != true) {
      _handleDeepLink(pending);
    }
  }

  Future<void> _checkPostStartupDialogs(BuildContext context) async {
    await FreeDroidWarnDialog.checkAndShow(context);
    if (!context.mounted) return;
    if (Platform.isAndroid) {
      await _checkAndRequestPermissions(context);
    }
    if (!context.mounted) return;
    await UpdateDialog.checkAndShow(context);
    if (!context.mounted) return;
    if (_hasKeyNetworkRestrictionError) {
      _hasKeyNetworkRestrictionError = false;
      await KeyServerRestrictionDialog.show(
        context,
        onRetrySuccess: (count) {
          if (mounted) {
            CustomToast.showToast(
              context: context,
              message: count > 0
                  ? context.l10n.addedNewKeys(count)
                  : context.l10n.keysAreUpToDate,
            );
          }
        },
      );
    }
  }

  MaterialApp _buildMaterialApp({required Widget home}) {
    final ThemeData theme = AppTheme.getTheme(
      isDark: true,
      colorScheme: colorScheme ?? 'kyzen',
      customColor: customColor,
      minecraftFont: _useMinecraftFont,
    );

    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      navigatorKey: _navigatorKey,
      builder: (context, child) {
        // the violet floor is painted once, behind every route
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: KzTheme.overlayStyle,
          child: KzBackdrop(child: child ?? const SizedBox.shrink()),
        );
      },
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('it'), // Italian
        Locale('ru'), // Russian
        Locale('uk'), // Ukrainian
        Locale('fa'), // Persian
        Locale('ar'), // Arabic
        Locale('zh'), // Chinese simplified
        Locale('th'), // Thai
        Locale('id'), // Indonesian
        Locale('fr'), // French
        Locale('es'), // Spanish
        Locale('lt'), // Lithuanian
        Locale('fil'), // Filipino
        Locale('fi'), // Finnish
        Locale('bn'), // Bengali
        Locale('cs'), // Czech
        Locale('hi'), // Hindi
        Locale('ms'), // Malay
        Locale('pt'), // Portuguese
      ],
      locale: Locale(_currentLanguage),
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading screen
    if (_loadingKey != null) {
      return _buildMaterialApp(home: LoadingScreen(loadingKey: _loadingKey!));
    }

    // Main app
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => DownloadService(
            onError: _showMessage,
            onGateRequired: _openGateFor,
          ),
        ),
        ChangeNotifierProvider(create: (context) => EmoteService()),
        ChangeNotifierProvider(create: (context) => SkinService()),
      ],
      child: _buildMaterialApp(
        home: Builder(
          builder: (innerContext) {
            if (_needToShowMessages) {
              _showPendingMessages(innerContext);
            }
            if (_needToCheckPostStartupDialogs) {
              _needToCheckPostStartupDialogs = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _checkPostStartupDialogs(innerContext);
                }
              });
            }
            final isLandscape =
                MediaQuery.of(innerContext).orientation ==
                Orientation.landscape;
            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: Colors.transparent,
              extendBody: true,
              body: SafeArea(
                bottom: false,
                child: PageStorage(
                  bucket: _bucket,
                  child: _getBody(innerContext, isLandscape: isLandscape),
                ),
              ),
              bottomNavigationBar: isLandscape
                  ? null
                  : BottomNavBar(
                      currentIndex: _selectedIndex,
                      onTap: _onItemTapped,
                    ),
              drawer: isLandscape
                  ? _buildDrawer(innerContext, isLandscape: isLandscape)
                  : null,
            );
          },
        ),
      ),
    );
  }

  void _handleThemeChange(bool isDarkMode) {
    setState(() {
      isDark = isDarkMode;
    });
    if (Platform.isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(
        AppTheme.getSystemOverlayStyle(isDark: isDarkMode),
      );
    }
  }

  void _handleFontChange(bool useMinecraftFont) {
    setState(() {
      _useMinecraftFont = useMinecraftFont;
    });
  }

  void _handleColorSchemeChange(String? newColorScheme) {
    setState(() {
      colorScheme = newColorScheme;
    });
  }

  void _handleCustomColorChange(Color? newCustomColor) {
    setState(() {
      customColor = newCustomColor;
    });
  }

  Widget _getBody(BuildContext context, {required bool isLandscape}) {
    // In landscape, only show home in the body (downloads and settings are in the drawer)
    if (isLandscape) {
      return _buildHomeTab(context, isLandscape: isLandscape);
    }

    // In portrait, include all tabs
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeTab(context, isLandscape: isLandscape),
        _downloadsTab,
        const AnnouncementsTab(),
        SettingsTab(
          isDarkMode: isDark,
          colorScheme: colorScheme,
          customColor: customColor,
          onThemeChanged: _handleThemeChange,
          onColorSchemeChanged: _handleColorSchemeChange,
          onCustomColorChanged: _handleCustomColorChange,
          onLanguageChanged: _onLanguageChanged,
          onPageSizeChanged: _handlePageSizeChange,
          onFontChanged: _handleFontChange,
          onKeyFilterChanged: (filter) => setState(() => _keyFilter = filter),
          searchService: _searchService,
          keysService: KeysService.instance,
          onDrawerTabChange: null, // No drawer in portrait mode
          isLandscape: isLandscape,
          onDownloadPathChanged: () {
            _downloadsKey.currentState?.refreshFiles();
          },
        ),
      ],
    );
  }

  /// A download asked for the pass: open the gate over whatever is on screen.
  void _openGateFor(SearchResult item) {
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    KzGatePage.open(ctx, dlcId: item.dlcId, packTitle: item.title);
  }

  Widget _buildHomeTab(BuildContext context, {required bool isLandscape}) {
    return Column(
      children: [
        KzTopBar(
          onMenu: isLandscape
              ? () => _scaffoldKey.currentState?.openDrawer()
              : null,
        ),
        CustomSearchBar(
          controller: _searchController,
          currentSearchType: _selectedSearchType,
          currentSortOrder: _sortOrder,
          // the menu lives in the top bar now
          showDrawerButton: false,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onSearch: (query) {
            if (_selectedSearchType == 'discovery') {
              if (query.trim().isNotEmpty) {
                setState(() {
                  _selectedSearchType = 'default';
                });
                _performSearch(query, filter: 'default');
              } else {
                _loadDiscovery(forceRefresh: true);
              }
            } else {
              _performSearch(query, filter: _selectedSearchType);
            }
          },
          onSearchTypeChanged: (type) {
            setState(() {
              if (_sortingOptions.contains(type)) {
                _sortOrder = type;
                if (_selectedSearchType != 'discovery') {
                  _performSearch('');
                }
              } else {
                _selectedSearchType = type;
                if (type == 'discovery') {
                  _loadDiscovery();
                } else {
                  _performSearch('', filter: type);
                }
              }
            });
          },
        ),
        Expanded(child: _buildSearchResults(context)),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, {required bool isLandscape}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double drawerWidth = min(600, screenWidth * 0.5);
    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IndexedStack(
                  index: _drawerSelectedIndex,
                  children: [
                    _downloadsTab,
                    const AnnouncementsTab(),
                    SettingsTab(
                      isDarkMode: isDark,
                      colorScheme: colorScheme,
                      customColor: customColor,
                      onThemeChanged: _handleThemeChange,
                      onColorSchemeChanged: _handleColorSchemeChange,
                      onCustomColorChanged: _handleCustomColorChange,
                      onLanguageChanged: _onLanguageChanged,
                      onPageSizeChanged: _handlePageSizeChange,
                      onFontChanged: _handleFontChange,
                      onKeyFilterChanged: (filter) =>
                          setState(() => _keyFilter = filter),
                      searchService: _searchService,
                      keysService: KeysService.instance,
                      onDrawerTabChange: (index) {
                        setState(() {
                          _drawerSelectedIndex = 3;
                        });
                      },
                      isLandscape: isLandscape,
                      onDownloadPathChanged: () {
                        _downloadsKey.currentState?.refreshFiles();
                      },
                    ),
                    AuthPage(
                      keysService: KeysService.instance,
                      searchService: _searchService,
                      onBack: () {
                        setState(() {
                          _drawerSelectedIndex = 2; // Go back to Settings
                        });
                      },
                      pageSize: _pageSize,
                    ), // index 3
                  ],
                ),
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: ValueListenableBuilder<bool>(
                valueListenable: AnnouncementsService.hasUnreadNotifier,
                builder: (context, hasUnread, child) {
                  return BottomNavigationBar(
                    currentIndex: _drawerSelectedIndex.clamp(
                      0,
                      2,
                    ), // Clamp to 0-2 range to prevent out of bounds
                    onTap: (int i) {
                      setState(() {
                        _drawerSelectedIndex = i;
                      });
                      if (i == 1) {
                        AnnouncementsService.markAsRead();
                      }
                    },
                    items: [
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.download),
                        label: context.l10n.downloads,
                      ),
                      BottomNavigationBarItem(
                        icon: Badge(
                          isLabelVisible: hasUnread,
                          child: const Icon(Icons.newspaper_outlined),
                        ),
                        label: 'News',
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.settings),
                        label: context.l10n.settings,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_selectedSearchType == 'discovery') {
      if (_discoveryData == null &&
          !_isLoadingDiscovery &&
          _discoveryError == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedSearchType == 'discovery') {
            _loadDiscovery();
          }
        });
      }
      return HomeDiscoveryView(
        data: _discoveryData,
        isLoading: _isLoadingDiscovery,
        errorMessage: _discoveryError,
        searchService: _searchService,
        pageSize: _pageSize,
        onRefresh: () => _loadDiscovery(forceRefresh: true),
        onCategorySelected: (filter) {
          _searchController.clear();
          setState(() {
            _selectedSearchType = filter;
          });
          _performSearch('', filter: filter);
        },
        onViewAll: (filter, orderBy) {
          _searchController.clear();
          setState(() {
            _selectedSearchType = filter;
          });
          _performSearch('', filter: filter);
        },
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      if (_selectedSearchType == 'favorite') {
        final hasFavorites = favoriteService.getAllFavorites().isNotEmpty;

        if (!hasFavorites) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/empty-wishlist.png'),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.favoriteEmpty,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.favoriteDescription,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
      }

      if (_keyFilter == KeyFilterType.onlyNotAvailable &&
          (_selectedSearchType == 'skin' || _selectedSearchType == 'persona')) {
        return Center(
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
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.changeFilterInSettingsNotice,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              context.l10n.noResultsFound,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isPaginatedSearchType &&
        _hasMoreItems() &&
        !_isLoading &&
        !_isLoadingMore) {
      _checkAndAutoLoadMore();
    }

    final itemCount =
        _searchResults.length +
        (_isPaginatedSearchType && (_isLoadingMore || _hasMoreItems()) ? 1 : 0);

    // Check if we're displaying creators
    if (_searchResults.isNotEmpty && _searchResults.first is CreatorResult) {
      return ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == _searchResults.length) {
            return _buildPaginationIndicator();
          }
          return CreatorResultItem(
            creator: _searchResults[index] as CreatorResult,
            searchService: _searchService,
            pageSize: _pageSize,
          );
        },
      );
    }

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      return ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == _searchResults.length) {
            return _buildPaginationIndicator();
          }
          return SearchResultItem(
            item: _searchResults[index] as SearchResult,
            searchService: _searchService,
            pageSize: _pageSize,
          );
        },
      );
    }

    final crossAxisCount = min(
      (MediaQuery.of(context).size.width / 350).floor(),
      5,
    );

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.2,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == _searchResults.length) {
            return _buildPaginationIndicator();
          }
          return SearchResultGridItem(
            item: _searchResults[index] as SearchResult,
            searchService: _searchService,
            pageSize: _pageSize,
          );
        },
      ),
    );
  }

  Widget _buildPaginationIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: _isLoadingMore
          ? const CircularProgressIndicator()
          : const SizedBox.shrink(),
    );
  }
}
