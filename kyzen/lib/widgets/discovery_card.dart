import 'package:kyzen/l10n/context_extensions.dart';
import 'package:kyzen/models/search_result.dart';
import 'package:kyzen/services/search_service.dart';
import 'open_item_details.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'item_thumbnail.dart';
import 'package:material_ui/material_ui.dart';

import '../kyzen/kz_motion.dart';
import '../kyzen/kz_surface.dart';
import '../kyzen/kz_tokens.dart';

String? getPackTypeAsset(String packType) {
  final key = packType.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  switch (key) {
    case 'addon':
      return 'assets/addon.png';
    case 'world':
      return 'assets/world.png';
    case 'texturepack':
    case 'texture':
      return 'assets/texture.png';
    case 'skinpack':
    case 'skin':
      return 'assets/skin.png';
    case 'mashup':
      return 'assets/mashup.png';
    case 'persona':
      return 'assets/persona.png';
    default:
      return null;
  }
}

class DiscoveryCard extends StatelessWidget {
  final SearchResult item;
  final SearchService searchService;
  final int pageSize;
  final double? width;

  const DiscoveryCard({
    super.key,
    required this.item,
    required this.searchService,
    required this.pageSize,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final packAsset = getPackTypeAsset(item.packType);

    Widget card = Directionality(
      textDirection: TextDirection.ltr,
      child: KzPressable(
        scale: KzMotion.pressScaleCard,
        onTap: () => openItemDetails(context, item, searchService, pageSize),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // 16:9 Thumbnail Image, glass edge over it
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: KzRadius.rCard,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ItemThumbnail(
                        imageUrl: item.imageUrl,
                        isOwned: item.isOwned,
                        placeholderIconSize: 32,
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
                ],
              ),

              // Card Details (Title, Creator, Pack Type)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      AutoSizeText(
                        item.title,
                        style: KzType.label.copyWith(
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        minFontSize: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),

                      // Creator and Pack Type Icon/Text
                      Row(
                        children: [
                          Expanded(
                            child: AutoSizeText(
                              context.l10n.byCreator(item.creator),
                              style: KzType.meta.copyWith(fontSize: 12),
                              maxLines: 1,
                              minFontSize: 8,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (packAsset != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Image.asset(
                                packAsset,
                                width: 13,
                                height: 13,
                                color: KzColors.ink3,
                                filterQuality: FilterQuality.none,
                              ),
                            )
                          else if (item.packType.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Text(
                                item.packType,
                                style: KzType.tiny.copyWith(
                                  fontSize: 11,
                                  color: KzColors.ink3,
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
        ),
      ),
    );

    if (width != null) {
      final cardHeight = (width! * 9 / 16) + 48.0;
      return SizedBox(width: width, height: cardHeight, child: card);
    }

    return card;
  }
}
