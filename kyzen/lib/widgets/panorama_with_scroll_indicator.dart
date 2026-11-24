import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:kyzen/l10n/context_extensions.dart';

class PanoramaWithScrollIndicator extends StatefulWidget {
  final String imageUrl;
  final double maxWidth;
  final VoidCallback? onLongPress;
  final bool isDesktop;

  const PanoramaWithScrollIndicator({
    super.key,
    required this.imageUrl,
    required this.maxWidth,
    this.onLongPress,
    required this.isDesktop,
  });

  @override
  State<PanoramaWithScrollIndicator> createState() =>
      _PanoramaWithScrollIndicatorState();
}

class _PanoramaWithScrollIndicatorState
    extends State<PanoramaWithScrollIndicator> {
  static const double _height = 175.0;

  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollMetrics);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollMetrics());
  }

  @override
  void didUpdateWidget(PanoramaWithScrollIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.maxWidth != widget.maxWidth) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _updateScrollMetrics(),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollMetrics);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollMetrics() {
    if (!mounted) return;

    final bool hasClients = _scrollController.hasClients;
    final double maxScroll = hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final double offset = hasClients ? _scrollController.offset : 0.0;

    final bool canScroll = hasClients && maxScroll > 0;
    final bool canScrollLeft = canScroll && offset > 0.5;
    final bool canScrollRight = canScroll && offset < maxScroll - 0.5;
    final double progress = canScroll
        ? (offset / maxScroll).clamp(0.0, 1.0)
        : 0.0;

    if (_canScrollLeft != canScrollLeft ||
        _canScrollRight != canScrollRight ||
        (_scrollProgress - progress).abs() > 0.001) {
      setState(() {
        _canScrollLeft = canScrollLeft;
        _canScrollRight = canScrollRight;
        _scrollProgress = progress;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final double target = (_scrollController.offset + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Widget _buildNavButton({
    required bool isLeft,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Positioned(
      left: isLeft ? 8 : null,
      right: isLeft ? null : 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: tooltip,
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            NotificationListener<Notification>(
              onNotification: (notification) {
                if (notification is ScrollNotification ||
                    notification is ScrollMetricsNotification) {
                  _updateScrollMetrics();
                }
                return false;
              },
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: GestureDetector(
                  onLongPress: widget.onLongPress,
                  onSecondaryTap: widget.onLongPress,
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    height: _height,
                    fit: BoxFit.fitHeight,
                    imageBuilder: (context, imageProvider) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _updateScrollMetrics();
                      });
                      return Image(
                        image: imageProvider,
                        height: _height,
                        fit: BoxFit.fitHeight,
                      );
                    },
                    placeholder: (context, url) => SizedBox(
                      width: widget.maxWidth,
                      height: _height,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorBuilder: (context, url, error) => Container(
                      width: widget.maxWidth,
                      height: _height,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 50),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.isDesktop) ...[
              _buildNavButton(
                isLeft: true,
                tooltip: context.l10n.scrollLeft,
                icon: Icons.chevron_left,
                onPressed: _canScrollLeft
                    ? () => _scrollBy(-widget.maxWidth * 0.6)
                    : null,
              ),
              _buildNavButton(
                isLeft: false,
                tooltip: context.l10n.scrollRight,
                icon: Icons.chevron_right,
                onPressed: _canScrollRight
                    ? () => _scrollBy(widget.maxWidth * 0.6)
                    : null,
              ),
            ],
          ],
        ),
        // Scroll progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: LinearProgressIndicator(
            value: _scrollProgress.clamp(0.0, 1.0),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
