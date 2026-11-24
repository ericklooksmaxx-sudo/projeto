import 'package:kyzen/services/search_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:kyzen/l10n/context_extensions.dart';

import '../kyzen/kz_components.dart';
import '../kyzen/kz_motion.dart';
import '../kyzen/kz_surface.dart';
import '../kyzen/kz_tokens.dart';
import '../models/search_result.dart';
import 'item_thumbnail.dart';
import 'open_item_details.dart';

/// Grid card, built like the site's `.card`: 16:9 glass thumbnail with the type
/// badge over it, title and creator underneath.
class SearchResultGridItem extends StatelessWidget {
  final SearchResult item;
  final SearchService searchService;
  final VoidCallback? onRemove;
  final bool showRemoveButton;
  final int pageSize;

  const SearchResultGridItem({
    super.key,
    required this.item,
    required this.searchService,
    this.onRemove,
    this.showRemoveButton = false,
    required this.pageSize,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: KzPressable(
        scale: KzMotion.pressScaleCard,
        onTap: () => openItemDetails(context, item, searchService, pageSize),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: KzRadius.rCard,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ItemThumbnail(
                          imageUrl: item.imageUrl,
                          isOwned: showRemoveButton || item.isOwned,
                          fit: BoxFit.cover,
                          borderRadius: KzRadius.rCard,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: const KzEdgePainter(
                            radius: KzRadius.rCard,
                            ring: Color(0x13FFFFFF),
                            topEdge: Color(0x3DFFFFFF),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: KzBadge(label: item.packType),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoSizeText(
                          item.title,
                          style: KzType.label.copyWith(
                            fontSize: 15,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          minFontSize: 10,
                          maxFontSize: 15,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        AutoSizeText(
                          context.l10n.byCreator(item.creator),
                          style: KzType.meta,
                          maxLines: 1,
                          minFontSize: 8,
                          maxFontSize: 13,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showRemoveButton && item.price != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Image.asset(
                                'assets/minecoin.png',
                                width: 14,
                                height: 14,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: AutoSizeText(
                                  '${item.price}',
                                  style: KzType.tiny.copyWith(
                                    color: KzColors.p200,
                                  ),
                                  maxLines: 1,
                                  minFontSize: 8,
                                  maxFontSize: 12,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (showRemoveButton && onRemove != null)
              Positioned(
                top: 8,
                right: 8,
                child: KzPressable(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: KzColors.bad.withValues(alpha: 0.9),
                      borderRadius: KzRadius.rPill,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
