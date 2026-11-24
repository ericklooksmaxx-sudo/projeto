import 'package:material_ui/material_ui.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:kyzen/l10n/context_extensions.dart';

import '../kyzen/kz_components.dart';
import '../kyzen/kz_motion.dart';
import '../kyzen/kz_surface.dart';
import '../kyzen/kz_tokens.dart';
import '../models/search_result.dart';
import '../services/search_service.dart';
import 'item_thumbnail.dart';
import 'open_item_details.dart';

/// List row, built like the site's `.card-row`: glass thumbnail on the left,
/// title and creator on the right, the whole row shrinking a touch on press.
class SearchResultItem extends StatelessWidget {
  final SearchResult item;
  final SearchService searchService;
  final VoidCallback? onRemove;
  final bool showRemoveButton;
  final int pageSize;

  const SearchResultItem({
    super.key,
    required this.item,
    required this.searchService,
    this.onRemove,
    this.showRemoveButton = false,
    required this.pageSize,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPersona = item.packType == 'Persona';

    return Directionality(
      textDirection: TextDirection.ltr, // Force LTR
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: KzPressable(
          scale: KzMotion.pressScaleCard,
          onTap: () => openItemDetails(context, item, searchService, pageSize),
          child: KzPanel(
            radius: KzRadius.rCard,
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: isPersona ? 3 : 5,
                  child: ClipRRect(
                    borderRadius: KzRadius.rChip,
                    child: AspectRatio(
                      aspectRatio: isPersona ? 1 / 1 : 16 / 9,
                      child: ItemThumbnail(
                        imageUrl: item.imageUrl,
                        isOwned: showRemoveButton || item.isOwned,
                        borderRadius: KzRadius.rChip,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  flex: 5,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double imageHeight = isPersona
                          ? constraints.maxWidth * (3.0 / 5.0)
                          : constraints.maxWidth * (9.0 / 16.0);

                      return SizedBox(
                        height: imageHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: AutoSizeText(
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
                                  ),
                                  if (showRemoveButton && onRemove != null) ...[
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 24,
                                      height: 22,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        iconSize: 18,
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        color: KzColors.bad,
                                        onPressed: onRemove,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            AutoSizeText(
                              context.l10n.byCreator(item.creator),
                              style: KzType.meta,
                              maxLines: 1,
                              minFontSize: 8,
                              maxFontSize: 13,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                KzBadge(label: item.packType),
                                if (showRemoveButton && item.price != null) ...[
                                  const SizedBox(width: 6),
                                  Image.asset(
                                    'assets/minecoin.png',
                                    width: 13,
                                    height: 13,
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
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
