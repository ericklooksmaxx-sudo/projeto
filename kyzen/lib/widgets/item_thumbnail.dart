import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';

class UnavailableOverlay extends StatelessWidget {
  final double iconSize;
  final double fontSize;

  const UnavailableOverlay({
    super.key,
    this.iconSize = 22,
    this.fontSize = 9.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.42),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_rounded,
            size: iconSize,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            context.l10n.unavailableUppercase,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ItemThumbnail extends StatelessWidget {
  final String? imageUrl;
  final bool isOwned;
  final BoxFit fit;
  final int memCacheWidth;
  final BorderRadius? borderRadius;
  final double unavailableIconSize;
  final double unavailableFontSize;
  final double placeholderIconSize;

  const ItemThumbnail({
    super.key,
    required this.imageUrl,
    this.isOwned = true,
    this.fit = BoxFit.contain,
    this.memCacheWidth =
        560, // Decode at lower resolution, should have some better performance ig
    this.borderRadius,
    this.unavailableIconSize = 22,
    this.unavailableFontSize = 9.5,
    this.placeholderIconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        _buildImage(context),
        if (!isOwned)
          UnavailableOverlay(
            iconSize: unavailableIconSize,
            fontSize: unavailableFontSize,
          ),
      ],
    );

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return content;
  }

  Widget _buildImage(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        memCacheWidth: memCacheWidth,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (context, url, error) => _buildPlaceholder(context),
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported, size: placeholderIconSize),
    );
  }
}
