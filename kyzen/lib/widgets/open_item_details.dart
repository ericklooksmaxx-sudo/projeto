import 'dart:math';
import 'package:kyzen/services/search_service.dart';
import 'package:material_ui/material_ui.dart';

import '../kyzen/kz_motion.dart';
import '../kyzen/kz_tokens.dart';
import '../models/search_result.dart';
import 'item_details_page.dart';

void openItemDetails(
  BuildContext context,
  SearchResult item,
  SearchService searchService,
  int pageSize,
) {
  final mediaQuery = MediaQuery.of(context);
  final isPortrait = mediaQuery.orientation == Orientation.portrait;

  if (isPortrait) {
    Navigator.of(context).push(
      KzPageRoute<void>(
        builder: (context) => ItemDetailsPage(
          item: item,
          isOwned: item.isOwned,
          searchService: searchService,
          pageSize: pageSize,
        ),
      ),
    );
    return;
  }

  final Size screenSize = mediaQuery.size;
  final double maxDialogWidth = min(900, screenSize.width * 0.85);
  final double maxDialogHeight = screenSize.height * 0.92;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Item Details',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: KzMotion.page,
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        KzPageTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        ),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxDialogWidth,
            maxHeight: maxDialogHeight,
          ),
          child: Material(
            elevation: 0,
            color: KzColors.floatSolid,
            borderRadius: BorderRadius.circular(KzRadius.sheet),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ItemDetailsPage(
                  item: item,
                  isOwned: item.isOwned,
                  searchService: searchService,
                  pageSize: pageSize,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
