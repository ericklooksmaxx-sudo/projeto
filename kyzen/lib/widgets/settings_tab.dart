import 'dart:convert';
import 'dart:io';

import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/minecraft_endpoint_service.dart';
import '../dev_menu/dev_menu_page.dart';
import '../services/app_version.dart';
import '../services/key_filter.dart';
import '../services/key_service.dart';
import '../services/search_service.dart';
import '../services/settings_service.dart';
import '../services/social_link.dart';
import 'auth_page.dart';
import 'changelog_page.dart';
import 'debug_terminal.dart';
import 'faq_page.dart';
import 'settings/appearance_settings_page.dart';
import 'settings/downloads_settings_page.dart';
import 'settings/keys_settings_page.dart';
import '../kyzen/gate/gate_page.dart';
import '../kyzen/gate/pass_service.dart';
import '../kyzen/kz_components.dart';
import '../kyzen/kz_tokens.dart';
import 'theme.dart';
import 'update_dialog.dart';

class SettingsTab extends StatefulWidget {
  final bool isDarkMode;
  final String? colorScheme;
  final Color? customColor;
  final Function(bool) onThemeChanged;
  final Function(String?) onColorSchemeChanged;
  final Function(Color?) onCustomColorChanged;
  final Function(String) onLanguageChanged;
  final Function(int) onPageSizeChanged;
  final Function(bool)? onFontChanged;
  final Function(String)? onKeyFilterChanged;
  final SearchService searchService;
  final KeysService keysService;
  final Function(int)? onDrawerTabChange;
  final bool isLandscape;
  final VoidCallback onDownloadPathChanged;
  final Function(bool)? onDevModeChanged;

  const SettingsTab({
    super.key,
    required this.isDarkMode,
    this.colorScheme,
    this.customColor,
    required this.onThemeChanged,
    required this.onColorSchemeChanged,
    required this.onCustomColorChanged,
    required this.onLanguageChanged,
    required this.onPageSizeChanged,
    this.onFontChanged,
    this.onKeyFilterChanged,
    required this.searchService,
    required this.keysService,
    this.onDrawerTabChange,
    required this.isLandscape,
    required this.onDownloadPathChanged,
    this.onDevModeChanged,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final SettingsService _settingsService = SettingsService.instance;

  String? _accountUsername;
  String? _accountAvatarUrl;
  bool _isAccountAuthenticated = false;

  // Previews for category subtitles
  late bool _isDarkMode;
  String? _selectedColorScheme;
  String _selectedLanguage = 'en';
  String _selectedKeyFilter = KeyFilterType.showAll;
  int _pageSize = 30;

  List<SocialLink> _socialLinks =
      SocialLinksService.cachedLinks ?? SocialLinksService.fallback;
  bool _isSocialLinksLoading = SocialLinksService.cachedLinks == null;
  bool _isDevMode = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _selectedColorScheme = widget.colorScheme;
    _loadAccountProfile();
    _loadPreviews();
    _fetchSocialLinks();
    _loadDevMode();
  }

  @override
  void didUpdateWidget(SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDarkMode != widget.isDarkMode ||
        _selectedColorScheme != widget.colorScheme) {
      setState(() {
        _isDarkMode = widget.isDarkMode;
        _selectedColorScheme = widget.colorScheme;
      });
    }
  }

  Future<void> _loadDevMode() async {
    final dev = await _settingsService.getDevMode();
    if (mounted) setState(() => _isDevMode = dev);
  }

  Future<void> _fetchSocialLinks() async {
    if (SocialLinksService.cachedLinks != null) {
      if (_socialLinks != SocialLinksService.cachedLinks ||
          _isSocialLinksLoading) {
        setState(() {
          _socialLinks = SocialLinksService.cachedLinks!;
          _isSocialLinksLoading = false;
        });
      }
      return;
    }

    final (links, hadError) = await SocialLinksService.fetch();
    if (!mounted) return;
    setState(() {
      _socialLinks = links;
      _isSocialLinksLoading = false;
    });
    if (hadError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.couldNotLoadSocials)));
    }
  }

  IconData _iconForLink(SocialLink link) {
    return switch (link.icon ?? link.title.toLowerCase()) {
      'telegram' => Icons.telegram_rounded,
      'discord' => Icons.discord_rounded,
      'reddit' =>
        Icons
            .reddit_rounded, // just incase even tho im never gonna open a reddit community
      'website' => Icons.public_rounded,
      _ => Icons.link,
    };
  }

  Widget _buildSocialTile({
    required IconData icon,
    required String title,
    required String url,
  }) {
    final uri = Uri.parse(url);
    final displayUrl = uri.host + uri.path;
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        displayUrl,
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
      trailing: Icon(
        Icons.arrow_outward,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () async {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.couldNotOpenLink(e.toString())),
            ),
          );
        }
      },
    );
  }

  Future<void> _loadAccountProfile() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final userDataFile = File('${documentsDir.path}/user_data.json');
      final tokenFile = File('${documentsDir.path}/personal_token.json');

      final hasToken = await tokenFile.exists();
      String? username;
      String? avatarUrl;

      if (await userDataFile.exists()) {
        try {
          final jsonString = await userDataFile.readAsString();
          final userData = json.decode(jsonString) as Map<String, dynamic>;
          username = userData['username'] as String?;
          final xuid = userData['xuid'] as String?;
          avatarUrl = MinecraftEndpoints.profileHeadUrl(xuid);
        } catch (e) {
          debugPrint('Error reading user_data.json: $e');
        }
      }

      final isAuth = hasToken || (username != null && username.isNotEmpty);

      if (mounted) {
        setState(() {
          _isAccountAuthenticated = isAuth;
          _accountUsername = username;
          _accountAvatarUrl = avatarUrl;
        });
      }
    } catch (e) {
      debugPrint('Error loading account profile in settings: $e');
    }
  }

  Future<void> _loadPreviews() async {
    try {
      final lang = await _settingsService.getLanguage();
      final filter = await _settingsService.getKeyFilter();
      final size = await _settingsService.getPageSize();
      if (mounted) {
        if (_selectedLanguage != lang ||
            _selectedKeyFilter != filter ||
            _pageSize != size) {
          setState(() {
            _selectedLanguage = lang;
            _selectedKeyFilter = filter;
            _pageSize = size;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openAccountPage() async {
    if (widget.isLandscape && widget.onDrawerTabChange != null) {
      widget.onDrawerTabChange!(2);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AuthPage(
            keysService: widget.keysService,
            searchService: widget.searchService,
            pageSize: _pageSize,
          ),
        ),
      );
      if (mounted) {
        _loadAccountProfile();
      }
    }
  }

  Widget _buildAccountHeroCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openAccountPage,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: _isAccountAuthenticated
              ? Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _accountAvatarUrl != null
                            ? Image.network(
                                _accountAvatarUrl!,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, _, _) => Image.asset(
                                  'assets/head.png',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.none,
                                ),
                              )
                            : Image.asset(
                                'assets/head.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _accountUsername ?? '?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.authOk,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _openAccountPage,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.l10n.manage),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.account_circle_outlined,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.accountLogin,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.signInWithMicrosoftDescription,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _openAccountPage,
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: Text(context.l10n.open),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The 24 h pass: state, a way into the gate, and a reset for this device.
  Widget _buildPassCard() {
    return AnimatedBuilder(
      animation: KzPass.instance,
      builder: (context, _) {
        final KzPass pass = KzPass.instance;
        final bool on = pass.active;

        return _buildSectionCard(
          title: 'Downloads pass',
          children: [
            ListTile(
              shape: const RoundedRectangleBorder(
                borderRadius: KzRadius.rCtl,
              ),
              leading: Icon(
                on ? Icons.verified_outlined : Icons.lock_outline,
                color: on ? KzColors.ok : KzColors.p300,
              ),
              title: Text(on ? 'Unlocked' : 'Locked'),
              subtitle: Text(
                on
                    ? '${pass.remainingLabel} left on this device.'
                    : 'Downloads need the free 24 h pass from kyzendlc.xyz.',
              ),
              trailing: pass.checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Check again',
                      onPressed: () => pass.refresh(quiet: false),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: KzButton(
                    label: on ? 'Open the pass' : 'Unlock 24 h',
                    icon: Icons.open_in_new,
                    size: KzButtonSize.sm,
                    onPressed: () => KzGatePage.open(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KzButton(
                    label: 'Reset device',
                    kind: KzButtonKind.secondary,
                    size: KzButtonSize.sm,
                    onPressed: () async {
                      await pass.reset();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pass and device cookie cleared on this phone.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionCard({
    required List<Widget> children,
    String? title,
    EdgeInsetsGeometry? padding,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  String _getColorSchemeName() {
    if (_selectedColorScheme == 'custom') {
      return context.l10n.customColor;
    }
    final names = AppTheme.getColorSchemeDisplayNames(context);
    return names[_selectedColorScheme] ?? context.l10n.defaultColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Text(
              context.l10n.settings,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Account Hero Banner
          _buildAccountHeroCard(context),

          const SizedBox(height: 6),

          // Appearance and lang sub-page
          _buildCategoryTile(
            icon: Icons.palette_rounded,
            accentColor: theme.colorScheme.primary,
            title: context.l10n.appearance,
            subtitle:
                '${_isDarkMode ? 'Dark' : 'Light'} • ${_getColorSchemeName()} • ${_selectedLanguage.toUpperCase()}',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AppearanceSettingsPage(
                    isDarkMode: widget.isDarkMode,
                    colorScheme: widget.colorScheme,
                    customColor: widget.customColor,
                    onThemeChanged: widget.onThemeChanged,
                    onColorSchemeChanged: widget.onColorSchemeChanged,
                    onCustomColorChanged: widget.onCustomColorChanged,
                    onLanguageChanged: widget.onLanguageChanged,
                    onFontChanged: widget.onFontChanged,
                  ),
                ),
              );
              _loadPreviews();
            },
          ),

          // Downloads and storage sub-page
          _buildCategoryTile(
            icon: Icons.folder_open_rounded,
            accentColor: theme.colorScheme.secondary,
            title: context.l10n.downloadsAndStorage,
            subtitle: context.l10n.downloadsAndStorageSubtitle,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DownloadsSettingsPage(
                    onDownloadPathChanged: widget.onDownloadPathChanged,
                  ),
                ),
              );
            },
          ),

          // Keys and tools sub-page
          _buildCategoryTile(
            icon: Icons.key_rounded,
            accentColor: theme.colorScheme.tertiary,
            title: context.l10n.keysAndTools,
            subtitle:
                '${context.l10n.filter} ${KeyFilterType.getDisplayText(context, _selectedKeyFilter)}',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => KeysSettingsPage(
                    keysService: widget.keysService,
                    searchService: widget.searchService,
                    onPageSizeChanged: widget.onPageSizeChanged,
                    onKeyFilterChanged: widget.onKeyFilterChanged,
                  ),
                ),
              );
              _loadPreviews();
            },
          ),

          const SizedBox(height: 12),

          // Downloads pass (the gate runs on the site)
          _buildPassCard(),

          // Support and community
          _buildSectionCard(
            title: context.l10n.supportAndCommunity,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.question_answer_rounded),
                title: Text(context.l10n.faq),
                subtitle: Text(context.l10n.frequentlyAskedQuestions),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const FaqView())),
              ),
              if (_isSocialLinksLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else ...[
                ..._socialLinks.expand((link) sync* {
                  yield const Divider();
                  yield _buildSocialTile(
                    icon: _iconForLink(link),
                    title: link.title,
                    url: link.url,
                  );
                }),
              ],
            ],
          ),

          // About
          _buildSectionCard(
            title: context.l10n.aboutAndDiagnostics,
            children: [
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                ),
                title: Text(context.l10n.version),
                subtitle: const Text(AppVersion.display),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChangelogScreen(
                          onDevModeChanged: (enabled) {
                            setState(() => _isDevMode = enabled);
                            widget.onDevModeChanged?.call(enabled);
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: theme.colorScheme.surfaceContainer,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 18),
                      const SizedBox(width: 6),
                      Text(context.l10n.changelog),
                    ],
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  Icons.system_update_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(context.l10n.checkForUpdates),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => UpdateDialog.checkAndShow(context, force: true),
              ),
              const Divider(),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.terminal),
                title: Text(context.l10n.terminal),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugTerminalView()),
                ),
              ),
              if (_isDevMode) ...[
                const Divider(),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Image.asset(
                    'assets/dev_menu.png',
                    width: 24,
                    height: 24,
                  ),
                  title: const Text('Dev Menu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DevMenuPage(searchService: widget.searchService),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              'By KyzenTeam',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '© ${DateTime.now().year} KyzenTeam. May be redistributed freely but not sold.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'This app is completely free. If you paid for it, you were scammed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
