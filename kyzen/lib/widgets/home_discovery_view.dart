import 'dart:async';
import 'package:kyzen/models/home_discovery_data.dart';
import 'package:kyzen/models/search_result.dart';
import 'package:kyzen/services/search_service.dart';
import 'package:kyzen/widgets/discovery_card.dart';
import 'package:kyzen/widgets/open_item_details.dart';
import 'package:kyzen/widgets/search_result_grid_item.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import '../kyzen/kz_motion.dart';
import '../kyzen/kz_text.dart';
import '../kyzen/kz_tokens.dart';

class HomeDiscoveryView extends StatefulWidget {
  final HomeDiscoveryData? data;
  final bool isLoading;
  final String? errorMessage;
  final SearchService searchService;
  final int pageSize;
  final VoidCallback onRefresh;
  final ValueChanged<String> onCategorySelected;
  final void Function(String filter, String? orderBy) onViewAll;

  const HomeDiscoveryView({
    super.key,
    required this.data,
    required this.isLoading,
    required this.errorMessage,
    required this.searchService,
    required this.pageSize,
    required this.onRefresh,
    required this.onCategorySelected,
    required this.onViewAll,
  });

  @override
  State<HomeDiscoveryView> createState() => _HomeDiscoveryViewState();
}

class _HomeDiscoveryViewState extends State<HomeDiscoveryView> {
  final PageController _heroPageController = PageController();
  final ValueNotifier<int> _activeHeroIndex = ValueNotifier<int>(0);
  Timer? _heroAutoRotateTimer;

  @override
  void initState() {
    super.initState();
    _startHeroAutoRotate();
  }

  @override
  void didUpdateWidget(covariant HomeDiscoveryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _startHeroAutoRotate();
    }
  }

  @override
  void dispose() {
    _heroAutoRotateTimer?.cancel();
    _heroPageController.dispose();
    _activeHeroIndex.dispose();
    super.dispose();
  }

  void _startHeroAutoRotate() {
    _heroAutoRotateTimer?.cancel();
    final spotlightCount = widget.data?.spotlight.length ?? 0;
    if (spotlightCount <= 1) return;

    _heroAutoRotateTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_heroPageController.hasClients) return;
      final next = (_activeHeroIndex.value + 1) % spotlightCount;
      _heroPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _resetHeroTimer() {
    _startHeroAutoRotate();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && (widget.data == null || widget.data!.isEmpty)) {
      return _buildLoadingState(context);
    }

    if (widget.errorMessage != null &&
        (widget.data == null || widget.data!.isEmpty)) {
      return _buildErrorState(context);
    }

    final data = widget.data;
    if (data == null || data.isEmpty) {
      return _buildErrorState(context);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 720;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20.0 : 12.0,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Spotlight Hero Banner
              if (data.spotlight.isNotEmpty) ...[
                _buildSpotlightHero(context, data.spotlight, isDesktop),
                const SizedBox(height: 18),
              ],

              // Category Navigation Bar
              _buildCategoryNavBar(context, isDesktop),
              const SizedBox(height: 18),

              // Sections Feed
              ..._buildSections(context, data, isDesktop),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotlightHero(
    BuildContext context,
    List<SearchResult> items,
    bool isDesktop,
  ) {
    final heroHeight = isDesktop ? 260.0 : 165.0;

    return RepaintBoundary(
      child: SizedBox(
        height: heroHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              PageView.builder(
                controller: _heroPageController,
                itemCount: items.length,
                onPageChanged: (index) {
                  _activeHeroIndex.value = index;
                  _resetHeroTimer();
                },
                itemBuilder: (context, index) {
                  final item = items[index];
                  return isDesktop
                      ? _buildDesktopHeroCard(context, item)
                      : _buildMobileHeroCard(context, item);
                },
              ),
              // Navigation dots
              if (items.length > 1)
                Positioned(
                  bottom: 12,
                  right: 16,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _activeHeroIndex,
                    builder: (context, activeIndex, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(items.length, (i) {
                          final isActive = i == activeIndex;
                          return GestureDetector(
                            onTap: () {
                              _heroPageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                              );
                              _resetHeroTimer();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              width: isActive ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeroCard(BuildContext context, SearchResult item) {
    final theme = Theme.of(context);
    final bgImage = item.imagePanorama ?? item.imageUrl;
    final previewImage = item.imageUrl ?? item.imagePanorama;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        if (bgImage != null)
          CachedNetworkImage(
            imageUrl: bgImage,
            alignment: const Alignment(0.0, -0.3),
            fit: BoxFit.cover,
            errorBuilder: (context, url, error) =>
                Container(color: const Color(0xFF090B0E)),
          )
        else
          Container(color: const Color(0xFF090B0E)),

        // Horizontal dark gradient overlay
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xF006080A), Color(0x8006080A), Color(0x0006080A)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Hero Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Info Column
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            if (getPackTypeAsset(item.packType) != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Image.asset(
                                  getPackTypeAsset(item.packType)!,
                                  width: 20,
                                  height: 20,
                                  color: theme.colorScheme.primary,
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Creator & Rating
                        Row(
                          children: [
                            Text(
                              context.l10n.byCreator(item.creator),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (item.avgStars != null &&
                                item.avgStars! > 0) ...[
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFFFC42B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                item.avgStars!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Color(0xFFFFC42B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (item.totalStars != null)
                                Text(
                                  ' ${context.l10n.reviewsCount(item.totalStars!)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          item.description
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim(),
                          style: const TextStyle(
                            color: Color(0xFFA8ADBE),
                            fontSize: 13,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),

                        // Action button
                        ElevatedButton.icon(
                          onPressed: () => openItemDetails(
                            context,
                            item,
                            widget.searchService,
                            widget.pageSize,
                          ),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          label: Text(context.l10n.viewPack),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right Preview Frame (16:9)
              if (previewImage != null)
                InkWell(
                  onTap: () => openItemDetails(
                    context,
                    item,
                    widget.searchService,
                    widget.pageSize,
                  ),
                  child: Container(
                    width: 260,
                    height: 146,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: previewImage,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeroCard(BuildContext context, SearchResult item) {
    final bgImage = item.imagePanorama ?? item.imageUrl;
    final iconImage = item.packIconUrl ?? item.imageUrl;

    return InkWell(
      onTap: () =>
          openItemDetails(context, item, widget.searchService, widget.pageSize),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (bgImage != null)
            CachedNetworkImage(
              imageUrl: bgImage,
              alignment: const Alignment(0.0, -0.3),
              fit: BoxFit.cover,
              errorBuilder: (context, url, error) =>
                  Container(color: const Color(0xFF090B0E)),
            )
          else
            Container(color: const Color(0xFF090B0E)),

          // Vertical dark gradient overlay
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x0006080A),
                  Color(0x6606080A),
                  Color(0xEA06080A),
                ],
                stops: [0.2, 0.55, 1.0],
              ),
            ),
          ),

          // Bottom aligned content
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (iconImage != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF0F1218),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: iconImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (getPackTypeAsset(item.packType) != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 5.0),
                                child: Image.asset(
                                  getPackTypeAsset(item.packType)!,
                                  width: 15,
                                  height: 15,
                                  color: Theme.of(context).colorScheme.primary,
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                context.l10n.byCreator(item.creator),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.avgStars != null &&
                                item.avgStars! > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFFFC42B),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                item.avgStars!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Color(0xFFFFC42B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryNavBar(BuildContext context, bool isDesktop) {
    const categories = [
      ('addon', 'assets/addon.png', 'Add-Ons'),
      ('world', 'assets/world.png', 'Worlds'),
      ('texture', 'assets/texture.png', 'Texture Packs'),
      ('skin', 'assets/skin.png', 'Skin Packs'),
      ('mashup', 'assets/mashup.png', 'Mash-ups'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final canFitInRow = constraints.maxWidth >= 680;

        if (canFitInRow) {
          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: categories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _buildCategoryChip(
                    context,
                    filter: cat.$1,
                    assetPath: cat.$2,
                    title: cat.$3,
                    isDesktop: true,
                  ),
                );
              }).toList(),
            ),
          );
        }

        // On mobile or narrow screens, scroll horizontally
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categories.map((cat) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildCategoryChip(
                  context,
                  filter: cat.$1,
                  assetPath: cat.$2,
                  title: cat.$3,
                  isDesktop: isDesktop,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(
    BuildContext context, {
    required String filter,
    required String assetPath,
    required String title,
    required bool isDesktop,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final borderRadius = BorderRadius.circular(isDesktop ? 10 : 20);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        splashColor: primary.withValues(alpha: 0.16),
        highlightColor: primary.withValues(alpha: 0.08),
        hoverColor: primary.withValues(alpha: 0.12),
        onTap: () => widget.onCategorySelected(filter),
        child: Ink(
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: borderRadius,
            border: Border.all(
              color: primary.withValues(alpha: 0.22),
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 14 : 12,
              vertical: isDesktop ? 8 : 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  assetPath,
                  width: 18,
                  height: 18,
                  color: primary,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: AutoSizeText(
                    title,
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    minFontSize: 9,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    HomeDiscoveryData data,
    bool isDesktop,
  ) {
    final sections = [
      _SectionSpec(
        title: context.l10n.newReleases,
        filter: 'default',
        orderBy: 'startDate DESC',
        items: data.newReleases,
      ),
      _SectionSpec(
        title: context.l10n.addons,
        filter: 'addon',
        orderBy: 'startDate DESC',
        items: data.addons,
      ),
      _SectionSpec(
        title: context.l10n.scaryDlc,
        filter: 'scary',
        orderBy: 'startDate DESC',
        items: data.scaryDlc,
      ),
      _SectionSpec(
        title: context.l10n.worlds,
        filter: 'world',
        orderBy: 'startDate DESC',
        items: data.worlds,
      ),
      _SectionSpec(
        title: context.l10n.sounds,
        filter: 'sounds',
        orderBy: 'startDate DESC',
        items: data.sounds,
      ),
      _SectionSpec(
        title: context.l10n.texturePacks,
        filter: 'texture',
        orderBy: 'startDate DESC',
        items: data.textures,
      ),
      _SectionSpec(
        title: context.l10n.mashups,
        filter: 'mashup',
        orderBy: 'startDate DESC',
        items: data.mashups,
      ),
    ];

    final widgets = <Widget>[];

    for (final sec in sections) {
      if (sec.items.isEmpty) continue;

      widgets.add(
        KzReveal(
          delay: KzReveal.stagger(widgets.length, step: 70),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Header: Anton in brushed steel, like the site
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: KzSectionTitle(
                    sec.title,
                    size: isDesktop ? 24 : 20,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: SizedBox(
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: KzColors.line2),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Section Items
            isDesktop
                ? _buildDesktopSectionGrid(
                    context,
                    items: sec.items,
                    onMore: () => widget.onViewAll(sec.filter, sec.orderBy),
                  )
                : _buildMobileSectionCarousel(
                    context,
                    items: sec.items,
                    onMore: () => widget.onViewAll(sec.filter, sec.orderBy),
                  ),
            const SizedBox(height: 22),
          ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildMobileSectionCarousel(
    BuildContext context, {
    required List<SearchResult> items,
    required VoidCallback onMore,
  }) {
    const cardWidth = 195.0;
    const cardHeight = (cardWidth * 9 / 16) + 52.0;

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _buildMoreCard(
              context,
              width: cardWidth,
              height: cardHeight,
              onTap: onMore,
            );
          }
          return DiscoveryCard(
            item: items[index],
            searchService: widget.searchService,
            pageSize: widget.pageSize,
            width: cardWidth,
          );
        },
      ),
    );
  }

  Widget _buildDesktopSectionGrid(
    BuildContext context, {
    required List<SearchResult> items,
    required VoidCallback onMore,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = (screenWidth / 350).floor().clamp(2, 5);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _buildMoreCard(context, onTap: onMore);
        }
        return SearchResultGridItem(
          item: items[index],
          searchService: widget.searchService,
          pageSize: widget.pageSize,
        );
      },
    );
  }

  Widget _buildMoreCard(
    BuildContext context, {
    double? width,
    double? height,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    Widget card = Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: primary.withValues(alpha: 0.16),
        hoverColor: primary.withValues(alpha: 0.08),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 22,
                  color: primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.more,
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: card);
    }

    return card;
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.errorMessage ?? context.l10n.failedToLoadDiscoverContent,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionSpec {
  final String title;
  final String filter;
  final String? orderBy;
  final List<SearchResult> items;

  _SectionSpec({
    required this.title,
    required this.filter,
    this.orderBy,
    required this.items,
  });
}
