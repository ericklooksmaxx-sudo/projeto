import 'package:material_ui/material_ui.dart';
import 'package:kyzen/l10n/context_extensions.dart';

class CustomSearchBar extends StatefulWidget {
  final SearchController controller;
  final Function(String) onSearch;
  final ValueChanged<String>? onSearchTypeChanged;
  final String currentSearchType;
  final bool showDrawerButton;
  final VoidCallback? onOpenDrawer;
  final String currentSortOrder;

  const CustomSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    this.onSearchTypeChanged,
    this.currentSearchType = 'default',
    this.showDrawerButton = false,
    this.onOpenDrawer,
    this.currentSortOrder = 'relevance',
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  bool _isMenuOpen = false;

  Widget getSearchIcon() {
    const double iconSize = 27.0;

    switch (widget.currentSearchType) {
      case 'addon':
        return const ImageIcon(AssetImage('assets/addon.png'), size: iconSize);
      case 'skin':
        return const ImageIcon(AssetImage('assets/skin.png'), size: iconSize);
      case 'mashup':
        return const ImageIcon(AssetImage('assets/mashup.png'), size: iconSize);
      case 'persona':
        return const ImageIcon(
          AssetImage('assets/persona.png'),
          size: iconSize,
        );
      case 'texture':
        return const ImageIcon(
          AssetImage('assets/texture.png'),
          size: iconSize,
        );
      case 'world':
        return const ImageIcon(AssetImage('assets/world.png'), size: iconSize);
      case 'creator':
        return const ImageIcon(
          AssetImage('assets/creator.png'),
          size: iconSize,
        );
      case 'hidden':
        return const ImageIcon(AssetImage('assets/hidden.png'), size: iconSize);
      case 'update':
        return const ImageIcon(
          AssetImage('assets/new_update.png'),
          size: iconSize,
        );
      case 'new_dlc':
        return const ImageIcon(
          AssetImage('assets/new_dlc.png'),
          size: iconSize,
        );
      case 'unfiltered':
        return const Icon(Icons.filter_alt_off_rounded, size: iconSize);
      case 'vibrant':
        return const ImageIcon(
          AssetImage('assets/vibrant.png'),
          size: iconSize,
        );
      case 'favorite':
        return const ImageIcon(AssetImage('assets/heart.png'), size: iconSize);
      case 'discovery':
        return const Icon(Icons.explore_rounded, size: iconSize);
      case 'scary':
        return const ImageIcon(AssetImage('assets/scary.png'), size: iconSize);
      case 'sounds':
        return const ImageIcon(
          AssetImage('assets/sound_note.png'),
          size: iconSize,
        );
      case 'emote':
        return const ImageIcon(AssetImage('assets/emote.png'), size: iconSize);
      case 'default':
      default:
        return const Icon(Icons.search, size: iconSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boxColor = Theme.of(context).colorScheme.surfaceContainerHigh;

    return Directionality(
      textDirection: TextDirection.ltr, // Force LTR
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          children: [
            if (widget.showDrawerButton)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  height: 56,
                  width: 56,
                  child: Material(
                    color: boxColor,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: context.l10n.menu,
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: widget.onOpenDrawer,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: SearchBar(
                controller: widget.controller,
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: 16.0),
                ),
                onSubmitted: (value) {
                  widget.onSearch(value);
                },
                hintText: context.l10n.hintText,
              ),
            ),
            if (widget.onSearchTypeChanged != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildFilterButton(context, boxColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, Color boxColor) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 8),
        borderRadius: BorderRadius.circular(28),
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(maxWidth: 210),
        onOpened: () {
          setState(() {
            _isMenuOpen = true;
          });
        },
        onCanceled: () {
          setState(() {
            _isMenuOpen = false;
          });
        },
        onSelected: (value) {
          setState(() {
            _isMenuOpen = false;
          });
          widget.onSearchTypeChanged?.call(value);
        },
        itemBuilder: (context) => [
          _buildCategoryItem(context, 'default', null, context.l10n.default1),
          _buildCategoryItem(
            context,
            'discovery',
            Icons.explore_rounded,
            context.l10n.discovery,
          ),
          _ExpandableCategory(
            title: context.l10n.sorting,
            icon: Icons.sort_rounded,
            currentSortOrder: widget.currentSortOrder,
            items: [
              ('relevance', ('assets/relevance.png'), context.l10n.relevance),
              (
                'startDate DESC',
                ('assets/time.png', Icons.arrow_downward_rounded),
                context.l10n.newest,
              ),
              (
                'startDate ASC',
                ('assets/time.png', Icons.arrow_upward_rounded),
                context.l10n.oldest,
              ),
              (
                'Rating/TotalCount desc',
                ('assets/star.png', Icons.arrow_downward_rounded),
                context.l10n.mostRated,
              ),
              (
                'Rating/TotalCount asc',
                ('assets/star.png', Icons.arrow_upward_rounded),
                context.l10n.leastRated,
              ),
            ],
          ),
          _ExpandableCategory(
            title: context.l10n.type,
            icon: Icons.category_rounded,
            items: [
              ('addon', 'assets/addon.png', context.l10n.addons),
              ('texture', 'assets/texture.png', context.l10n.textures),
              ('world', 'assets/world.png', context.l10n.worlds),
              ('mashup', 'assets/mashup.png', context.l10n.mashups),
              ('skin', 'assets/skin.png', context.l10n.skins),
              ('persona', 'assets/persona.png', context.l10n.persona),
            ],
          ),
          _ExpandableCategory(
            title: context.l10n.newFilter,
            icon: Icons.new_releases_rounded,
            items: [
              ('update', 'assets/new_update.png', context.l10n.newUpdate),
              ('new_dlc', 'assets/new_dlc.png', context.l10n.newDlc),
            ],
          ),
          _ExpandableCategory(
            title: context.l10n.other,
            icon: Icons.more_horiz_rounded,
            items: [
              ('vibrant', 'assets/vibrant.png', context.l10n.vibrantVisuals),
              ('hidden', 'assets/hidden.png', context.l10n.hidden),
              ('emote', 'assets/emote.png', context.l10n.emotes),
              ('creator', 'assets/creator.png', context.l10n.creators),
              ('favorite', 'assets/heart.png', context.l10n.favorites),
              (
                'unfiltered',
                Icons.filter_alt_off_rounded,
                context.l10n.unfiltered,
              ),
            ],
          ),
        ],
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              getSearchIcon(),
              Icon(
                _isMenuOpen
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 24,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildCategoryItem(
    BuildContext context,
    String value,
    dynamic assetOrIcon,
    String title,
  ) {
    Widget iconWidget;
    if (assetOrIcon == null) {
      iconWidget = const Icon(Icons.search, size: 22);
    } else if (assetOrIcon is IconData) {
      iconWidget = Icon(assetOrIcon, size: 22);
    } else if (assetOrIcon is String) {
      iconWidget = ImageIcon(AssetImage(assetOrIcon), size: 22);
    } else {
      iconWidget = const Icon(Icons.search, size: 22);
    }

    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [iconWidget, const SizedBox(width: 12), Text(title)],
      ),
    );
  }
}

class _ExpandableCategory extends PopupMenuEntry<String> {
  final String title;
  final IconData icon;
  final List<(String, dynamic, String)>
  items; // (value, assetPath or IconData, label)
  final String? currentSortOrder;

  const _ExpandableCategory({
    required this.title,
    required this.icon,
    required this.items,
    this.currentSortOrder,
  });

  @override
  double get height => 40;

  @override
  bool represents(String? value) => false;

  @override
  State<_ExpandableCategory> createState() => _ExpandableCategoryState();
}

class _ExpandableCategoryState extends State<_ExpandableCategory> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelLarge!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: textStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          ...widget.items.map((item) {
            return _CategorySubItem(
              value: item.$1,
              assetPath: item.$2,
              label: item.$3,
              isSelected: widget.currentSortOrder == item.$1,
            );
          }),
      ],
    );
  }
}

class _CategorySubItem extends StatelessWidget {
  final String value;
  final dynamic assetPath;
  final String label;
  final bool isSelected;

  const _CategorySubItem({
    required this.value,
    required this.assetPath,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelLarge!;
    final asset = assetPath;

    return InkWell(
      onTap: () {
        Navigator.pop<String>(context, value);
      },
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 30,
        ), // this is the spacing between the filter items
        padding:
            asset
                is (String, IconData) // some indent to put it at the center
            ? const EdgeInsets.only(
                left: 22,
                right: 4,
              ) // Less left padding for double icons
            : const EdgeInsets.only(left: 34, right: 4), // Normal padding
        child: Row(
          children: [
            if (asset == null)
              Icon(Icons.search, size: 19, color: textStyle.color)
            else if (asset is (String, IconData)) // Mixed tuple: image + icon
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ImageIcon(
                    AssetImage(asset.$1),
                    size: 17,
                    color: textStyle.color,
                  ),
                  const SizedBox(width: 1),
                  Icon(asset.$2, size: 17, color: textStyle.color),
                ],
              )
            else if (asset is IconData)
              Icon(asset, size: 19, color: textStyle.color)
            else if (asset is String)
              ImageIcon(AssetImage(asset), size: 19, color: textStyle.color),
            SizedBox(
              width: asset is (String, IconData) ? 5 : 9,
            ), // Less spacing for double icons
            Expanded(
              child: Text(label, style: textStyle.copyWith(fontSize: 13)),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                size: 12,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
