import 'package:material_ui/material_ui.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import '../services/settings_service.dart';

class ChangelogScreen extends StatelessWidget {
  final Function(bool)? onDevModeChanged;
  const ChangelogScreen({super.key, required this.onDevModeChanged});

  @override
  Widget build(BuildContext context) {
    final changelog = ChangelogData.getChangelog();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.changelog)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.appUpdates,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.appUpdatesDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final version = changelog[index];
              return _buildVersionCard(context, version, index);
            }, childCount: changelog.length),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
              child: Column(
                children: [
                  // Bee GIF footer
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ClipRRect(
                      child: Image.asset('assets/bee.gif', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Always buzzing with improvements',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _CreditsSection(onDevModeChanged: onDevModeChanged),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(
    BuildContext context,
    ChangelogVersion version,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            version.version,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (version.isBeta) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'BETA',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (version.releaseDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          version.releaseDate!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerRight,
              children: [
                const Divider(),
                if (index == 0)
                  Positioned(
                    right: 0,
                    bottom: 8.7,
                    child: Image.asset(
                      'assets/steve_sleep.gif',
                      width: 42,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            ...version.changes.map(
              (change) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 12),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        change,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChangelogVersion {
  final String version;
  final String? releaseDate;
  final List<String> changes;
  final bool isBeta;

  ChangelogVersion({
    required this.version,
    this.releaseDate,
    required this.changes,
    this.isBeta = false,
  });
}

// Changelogs are not gonna be localized/translated
class ChangelogData {
  static List<ChangelogVersion> getChangelog() {
    return [
      ChangelogVersion(
        version: 'v1.6.1',
        releaseDate: 'October 24, 2026',
        changes: [
          'fixed possible slowdown when opening a skin packs page on low-end devices',
          'fixed possible full grey screen on 3D preview for low-end devices',
          'auto disable 3D preview if not supported by the device',
          'added custom skin option for persona 3D preview',
          'added 3D adaptive resolution option (recommended for mid-tier/low devices)',
          'added setting to disable 3D preview',
        ],
      ),
      ChangelogVersion(
        version: 'v1.6.0',
        releaseDate: 'October 18, 2026',
        changes: [
          'Added 3D emote player/preview',
          'Added 3D preview for skin packs and persona',
          'Added emote filter',
          'Added singular skin pack download',
          'New loading screen ui',
          'Re-organized settings tab ui',
          'Auto disable platform lock for dlcs like the Mario mashup',
          'Bypass the dialog on mc that says "pls buy the dlc" by changing manifest uuids',
          'Fix zip error on some linux distro',
        ],
      ),
      ChangelogVersion(
        version: 'v1.5.4',
        releaseDate: 'September 10, 2026',
        changes: [
          'Added "Sorting" by relevance, it should improve the search system',
          'Added discovery page, this page displays various types of dlc and a spotlight.',
          'Small UI adjustments',
        ],
      ),
      ChangelogVersion(
        version: 'v1.5.2',
        releaseDate: 'August 27, 2026',
        changes: [
          'Fixed "optimized" dlcs being completely broken',
          'Added FAQ and HowTo section for dlcs that have them (in detail page)',
          'Added notification support for Windows',
          'Fix pagination search when using filters like "show only available items"',
          'Some small UI fixes',
        ],
      ),
      ChangelogVersion(
        version: 'v1.5.1',
        releaseDate: 'August 13, 2026',
        changes: [
          'Added version picker for dlc download (eg. default (old mc version) or optimized for 1.26)',
        ],
      ),
      ChangelogVersion(
        version: 'v1.5',
        releaseDate: 'July 30, 2026',
        changes: ['Added auto-app updater', 'Added announcements tab'],
      ),
      ChangelogVersion(
        version: 'v1.4.2',
        releaseDate: 'June 18, 2026',
        changes: [
          'Added faq button for items that are not available',
          'Added import to mc when clicking the completed download button',
          'UI adjustment creator section',
          'Added custom package selector to choose in which app to import the dlcs (for Android (useful for cloned mc))',
          'Changed download tab UI',
          'Display pack icon if a dlc has it (for download tab)',
          'Added warning for persona items',
          'Changed UI bottom navigation bar (for Android)',
          'Added support for Windows ARM64 (devices with ARM CPU, eg. Snapdragon)',
        ],
      ),
      ChangelogVersion(
        version: 'v1.4.1',
        releaseDate: 'April 5, 2026',
        changes: ['Added social links', 'Added token cache for API login'],
      ),
      ChangelogVersion(
        version: 'v1.4',
        releaseDate: 'March 7, 2026',
        changes: [
          'Added "Open DLCs" button on the auth page to view ur owned items',
          'Added custom download path setting (note that also images, keys etc... are gonna be saved on the custom path)',
          'Added changelog page on the settings tab',
          'Search system adjustments',
          'Added search bar for creators',
          'Adjusted API search for the filters "New dlc" and "New update", this should fix the empty search for these filters',
          'Added Minecraft font setting',
          'small optimization for the extraction process of a dlc',
          'Added page size setting to control how many items to load at once,'
              ' lower value ideal for weak connection (more frequent requests)'
              ' higher value ideal for fast connection (fewer requests)'
              ' note: all results are available regardless of page size since new items are gonna load when u reach the bottom of the list',
          'Added dlc language option, note that not every dlc has a translation available, this solely depends on the marketplace.',
          'Added on item details page tag for pack version, creation date and last modified date',
          'Added minecoins balance on the account login page',
          'Added "add to cart" button to item details page and cart button on the Authentication page to purchase the items (note: if an item has the purchasing disabled it\'s gonna be removed from the cart, only items that can\'t be bought cause of insufficient funds are gonna remain on the cart)',
          'Added save button on the debug terminal to save logs on the download folder',
          'Adjusted settings tab ui',
          'Display download size inside the download button',
          'Fixed an issue specifically affecting only Windows where some dlc files may contain weird Unicode chars like the dlc "Biomes add-on by Block Factory" resulting in failed processing of the pack. (Linux and Android are not affected by this issue)',
        ],
      ),
      ChangelogVersion(
        version: 'v1.3',
        releaseDate: 'November 26, 2025',
        changes: [
          'Added the possibility to open a DLC on the Minecraft/chunk.gg website on Kyzen (for Android)',
          'Changed UI drop down look',
          'Added unfiltered filter, this filter lets you see more "raw" data from the marketplace such as server items',
          'Fixed background download for some users (for Android)',
          'Microsoft auth page is now displayed inside the drawer view for desktop/landscape',
          'Added a favorites system - add a DLC to favorites by clicking the "Add to favorites" button, find your favorite items with the Favorites filter',
          'Persona images are now fully displayed and not cropped',
          'Added vibrant visual filter and added tag on description',
          'Added Mcdecryptor page for windows, u can open this page on the settings tab. It automatically handles both UWP and GDK path and it can decrypt ur bought content just like the regular McDec does.',
          'Added sorting filters: "Newest", "Oldest", "Most rated" and "Least rated"',
          'Transition animations are changed (for Android)',
          'Add-ons folder are now renamed (e.g., "Gravestone RP", "Gravestone BP")',
          'Added search bar for the custom db page',
          'Added pagination search - when you reach the bottom of the list, new items will load',
          'Updated FAQ page',
          'Fixed some search errors when searching with [ ], ( ), :',
        ],
      ),
      ChangelogVersion(
        version: 'v1.2',
        releaseDate: 'September 23, 2025',
        changes: [
          'Fixed file overwrite issue on Android 11 and above that occurred in specific scenarios',
          'Added the ability to download panorama images',
          'Added hidden offer filter (this filter lets you see removed DLCs)',
          'Added notification system',
          'Added support for background download (Android)',
          'Added Minecoin prices on DLC pages',
          'Added buttons to copy the DLC UUID, open the DLC in-game and creator button',
          'Added a setting to save images as PNG and store them in the gallery',
          'Added grid view for large screens (e.g. tablets/desktops)',
          'Added new filters: "New Update" and "New DLC"',
          'Implemented URL link search handling',
          'Display MB on the progress bar',
          'Added compression settings for DLC files',
          'Added custom color scheme',
          'Added support for desktop platforms (Windows/Linux)',
          'Added language support for: Italian, Russian, Ukrainian, Persian, Arabic, Chinese (Simplified), Thai, Indonesian, French, Spanish, Lithuanian, Filipino, Finnish, Bengali, Czech, Hindi, Malay, Portuguese',
        ],
      ),
      ChangelogVersion(
        version: 'v1.1',
        releaseDate: 'July 24, 2025',
        changes: [
          'Added the account login section in the settings tab to retrieve the keys of your account (This feature is useful if you own a DLC that Kyzen doesn\'t have yet)',
          'Hash check on downloaded DLCs for corruption detection',
          'Updated keys URL',
          'Other minor adjustments',
        ],
      ),
      ChangelogVersion(
        version: 'v1.0',
        releaseDate: 'June 25, 2025',
        changes: [
          'Completely reworked the UI',
          'Smaller APK size compared to v0.3',
          'Faster startup time and reduced RAM usage',
          'Small performance improvements',
        ],
      ),
      ChangelogVersion(
        version: 'v0.3',
        releaseDate: 'April 15, 2025',
        changes: [
          'Added filter to show only available or unavailable DLCs in settings',
          'Added FAQ section',
          'Automatically load items when switching filters',
        ],
      ),
      ChangelogVersion(
        version: 'v0.2',
        releaseDate: 'April 7, 2025',
        changes: [
          'Fixed file permission issues on Android 10',
          'Added creators filter for better content discovery',
          'Added light mode option',
          'Added possibility to load custom keys db',
          'Added terminal for displaying error messages',
          'Automatically load new items on app startup',
        ],
      ),
      ChangelogVersion(
        version: 'v0.1',
        releaseDate: 'March 30, 2025',
        changes: [
          'Initial release of Kyzen',
          'Search and download marketplace content',
          'Basic DLC management functionality',
        ],
      ),
    ];
  }
}

class _CreditsSection extends StatefulWidget {
  final Function(bool)? onDevModeChanged;
  const _CreditsSection({required this.onDevModeChanged});

  @override
  State<_CreditsSection> createState() => _CreditsSectionState();
}

class _CreditsSectionState extends State<_CreditsSection>
    with SingleTickerProviderStateMixin {
  int _tapCount = 0;
  static const int _tapsRequired = 30;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.82,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAvatarTap() async {
    setState(() => _tapCount++);

    _controller.forward().then((_) => _controller.reverse());

    if (_tapCount == _tapsRequired) {
      final alreadyEnabled = await SettingsService.instance.getDevMode();
      setState(() => _tapCount = 0);
      if (!alreadyEnabled) {
        await SettingsService.instance.setDevMode(true);
        widget.onDevModeChanged?.call(true);
      }
      if (!mounted) return;
      final color = Theme.of(context).colorScheme.primary;
      final message = alreadyEnabled
          ? 'Dev menu already enabled'
          : 'Dev menu enabled';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: color,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _handleAvatarTap,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/me.jpg',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _BreathingText(text: 'Wadudi'),
                    const SizedBox(width: 2),
                    Image.asset(
                      'assets/hearth.gif',
                      filterQuality: FilterQuality.none,
                    ),
                  ],
                ),
                Text(
                  'Main Developer',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _BreathingText extends StatefulWidget {
  final String text;

  const _BreathingText({required this.text});

  @override
  State<_BreathingText> createState() => _BreathingTextState();
}

class _BreathingTextState extends State<_BreathingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _breath = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final color = Color.lerp(
          primary.withValues(alpha: 0.6),
          secondary,
          _breath.value,
        )!;

        return Text(
          widget.text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            shadows: [
              Shadow(
                color: primary.withValues(alpha: 0.4 * _breath.value),
                blurRadius: 12 * _breath.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
