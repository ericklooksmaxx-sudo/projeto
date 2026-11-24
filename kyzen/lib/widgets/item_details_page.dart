import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import '../services/emote_service.dart';
import '../services/skin_service.dart';
import 'emote_player.dart';
import 'persona_player.dart';
import '../3d_skins/skin_pack_preview.dart';
import '../microsoft_auth/auth_tokens.dart';
import '../models/search_result.dart';
import '../services/download_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../services/http_client.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import 'creator_bottom_sheet.dart';
import '../services/search_service.dart';
import '../services/minecraft_launcher.dart';
import '../services/favorite_service.dart';
import '../services/cart_service.dart';
import 'cart_page.dart';
import 'faq_page.dart';
import 'item_faq_section.dart';
import 'item_how_to_section.dart';
import 'panorama_with_scroll_indicator.dart';
import 'import_dialog.dart';
import 'unsupported_3d_dialog.dart';
import '../kyzen/gate/pass_service.dart';

class ItemDetailsPage extends StatefulWidget {
  final SearchResult item;
  final bool isOwned;
  final SearchService searchService;
  final int pageSize;

  const ItemDetailsPage({
    super.key,
    required this.item,
    required this.isOwned,
    required this.searchService,
    required this.pageSize,
  });

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  late PageController _pageController;
  int _currentImageIndex = 0;
  final FavoriteService _favoriteService = FavoriteService();
  final CartService _cartService = CartService();
  bool _isFavorite = false;
  bool _isInCart = false;
  int? _downloadSize;
  bool _loadingSize = false;
  ScaffoldMessengerState? _scaffoldMessenger;
  late EmoteService _emoteService;
  late SkinService _skinService;
  int _detailsTab = 0; // 0=description, 1=howTo, 2=faq
  bool _show3DPreview = SettingsService.instance.get3DPreviewSync();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _load3DPreviewSetting();
    _initializeFavorites();
    _initializeCart();
    _fetchDownloadSize();
    _check3DUnsupported();
  }

  bool get _has3DContent =>
      widget.item.isEmote ||
      widget.item.isPersonaPiece ||
      widget.item.packType == 'SkinPack' ||
      widget.item.skinBinaryUrl != null;

  void _check3DUnsupported() {
    if (!_show3DPreview || !_has3DContent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Unsupported3DDialog.checkAndShow(context);
    });
  }

  Future<void> _load3DPreviewSetting() async {
    final enabled = await SettingsService.instance.get3DPreview();
    if (mounted && _show3DPreview != enabled) {
      setState(() {
        _show3DPreview = enabled;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to ScaffoldMessenger
    _scaffoldMessenger = ScaffoldMessenger.of(context);
    _emoteService = context.read<EmoteService>();
    _skinService = context.read<SkinService>();
  }

  Future<void> _initializeFavorites() async {
    await _favoriteService.initialize();
    setState(() {
      _isFavorite = _favoriteService.isFavorite(widget.item.dlcId);
    });
  }

  Future<void> _initializeCart() async {
    await _cartService.initialize();
    setState(() {
      _isInCart = _cartService.isInCart(widget.item.dlcId);
    });
  }

  Future<void> _fetchDownloadSize() async {
    if (!widget.isOwned) {
      return;
    }

    setState(() {
      _loadingSize = true;
    });

    final downloadService = Provider.of<DownloadService>(
      context,
      listen: false,
    );
    final size = await downloadService.getDownloadSize(widget.item);

    if (mounted) {
      setState(() {
        _downloadSize = size;
        _loadingSize = false;
      });
    }
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final newStatus = await _favoriteService.toggleFavorite(widget.item.dlcId);
    setState(() {
      _isFavorite = newStatus;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? context.l10n.addedToFavorites
                : context.l10n.removedFromFavorites,
          ),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }
  }

  Future<void> _toggleCart(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final newStatus = await _cartService.toggleCart(widget.item.dlcId);
    final hasValidTokens = await TokenCheck().isMcTokenValid();

    if (!mounted) return;

    setState(() {
      _isInCart = newStatus;
    });

    if (context.mounted) {
      final displayDuration = newStatus
          ? const Duration(milliseconds: 1800)
          : const Duration(milliseconds: 1200);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? context.l10n.addedToCart : context.l10n.removedFromCart,
          ),
          duration: displayDuration,
          action: newStatus
              ? SnackBarAction(
                  label: context.l10n.open,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  onPressed: () {
                    if (!context.mounted) return;
                    if (!hasValidTokens) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(context.l10n.authRequired),
                          content: Text(context.l10n.authRequiredDesc),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(context.l10n.ok),
                            ),
                          ],
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CartPage(
                            searchService: widget.searchService,
                            pageSize: widget.pageSize,
                          ),
                        ),
                      );
                    }
                  },
                )
              : null,
        ),
      );
      // close the SnackBarAction, flutter doesnt have an implementation. ???
      Future.delayed(displayDuration, () {
        if (mounted) {
          messenger.hideCurrentSnackBar();
        }
      });
    }
  }

  @override
  void dispose() {
    // snackbar needs to be disposed when page is closed
    // otherwise if the user triggers the SnackBarAction to open the cart page when he leaves the page we get invalid context
    _scaffoldMessenger?.clearSnackBars();
    _pageController.dispose();
    _emoteService.clearEmote(notify: false);
    _skinService.clearSkin(notify: false);
    super.dispose();
  }

  List<String> get _allImages {
    List<String> images = [];

    if (widget.item.imageUrl != null) {
      images.add(widget.item.imageUrl!);
    }

    images.addAll(widget.item.extraImages);

    return images;
  }

  List<String> get _downloadableImages {
    List<String> images = [];

    if (widget.item.imageUrl != null) {
      images.add(widget.item.imageUrl!);
    }

    images.addAll(widget.item.extraImages);

    if (widget.item.imagePanorama != null) {
      images.add(widget.item.imagePanorama!);
    }

    return images;
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = Provider.of<DownloadService>(context);
    final isCurrentDownload =
        downloadService.currentItemId == widget.item.dlcId;
    final isInQueue = downloadService.isInQueue(widget.item.dlcId);
    final queuePosition = downloadService.getQueuePosition(widget.item.dlcId);
    final allImages = _allImages;
    final bool isDesktop =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;

    void copyDlcId() {
      Clipboard.setData(ClipboardData(text: widget.item.dlcId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.uuidCopied),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    void openCreator() async {
      if (widget.item.creatorId == null) {
        return;
      }

      final creatorResult = CreatorResult(
        filterId: widget.item.creatorId!,
        filterName: widget.item.creator,
      );

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => CreatorStatsBottomSheet(
            creator: creatorResult,
            searchService: widget.searchService,
            pageSize: widget.pageSize,
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        forceMaterialTransparency: true,
        title: SelectableText(widget.item.title),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: 20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel section
            Stack(
              children: [
                ListenableBuilder(
                  listenable: Listenable.merge([_emoteService, _skinService]),
                  builder: (context, _) {
                    // emote player
                    if (_show3DPreview &&
                        _emoteService.hasEmote &&
                        _emoteService.emoteData?.animationData != null) {
                      return AspectRatio(
                        aspectRatio: 16 / 9,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return EmotePlayer(
                              animationData:
                                  _emoteService.emoteData!.animationData!,
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                            );
                          },
                        ),
                      );
                    }

                    // persona player
                    if (_show3DPreview &&
                        _skinService.hasSkin &&
                        _skinService.skinData?.primaryPersonaPiece != null) {
                      return AspectRatio(
                        aspectRatio: 16 / 9,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return PersonaPlayer(
                              piece:
                                  _skinService.skinData!.primaryPersonaPiece!,
                              size: Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                            );
                          },
                        ),
                      );
                    }

                    if (allImages.isNotEmpty) {
                      return Stack(
                        children: [
                          // Image carousel
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Builder(
                              builder: (context) {
                                final isLandscape =
                                    MediaQuery.of(context).orientation ==
                                    Orientation.landscape;

                                return ClipRRect(
                                  borderRadius: isLandscape
                                      ? BorderRadius.circular(10.0)
                                      : BorderRadius.zero,
                                  child: PageView.builder(
                                    controller: _pageController,
                                    itemCount: allImages.length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentImageIndex = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return GestureDetector(
                                        onSecondaryTap: () {
                                          _showDownloadDialog(context, index);
                                        },
                                        onLongPress: () {
                                          _showDownloadDialog(context, index);
                                        },
                                        child: CachedNetworkImage(
                                          imageUrl: allImages[index],
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.contain,
                                          placeholder: (context, url) =>
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                          errorBuilder: (context, url, error) =>
                                              Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    size: 50,
                                                  ),
                                                ),
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          // Desktop navigation buttons for the carousel
                          if (isDesktop && allImages.length > 1) ...[
                            Positioned(
                              left: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    tooltip: context.l10n.previousImage,
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                    ),
                                    onPressed: _currentImageIndex > 0
                                        ? () => _pageController.previousPage(
                                            duration: const Duration(
                                              milliseconds: 240,
                                            ),
                                            curve: Curves.easeOut,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    tooltip: context.l10n.nextImage,
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                    ),
                                    onPressed:
                                        _currentImageIndex <
                                            allImages.length - 1
                                        ? () => _pageController.nextPage(
                                            duration: const Duration(
                                              milliseconds: 240,
                                            ),
                                            curve: Curves.easeOut,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          // Image indicator dots
                          if (allImages.length > 1)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  allImages.length,
                                  (index) => Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == index
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }

                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 50),
                      ),
                    );
                  },
                ),

                // Popup menu button (top right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: PopupMenuButton<String>(
                    offset: const Offset(
                      0,
                      4,
                    ), // this add space between the button and the pop up menu
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    position: PopupMenuPosition.under,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'copy_uuid':
                          copyDlcId();
                          break;
                        case 'open_in_minecraft':
                          MinecraftLauncher.openInMinecraft(
                            widget.item.packType,
                            widget.item.dlcId,
                            context,
                          );
                          break;
                        case 'favorite':
                          _toggleFavorite(context);
                          break;
                        case 'cart':
                          _toggleCart(context);
                          break;
                        case 'open_creator':
                          openCreator();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'copy_uuid',
                        child: Row(
                          children: [
                            const Icon(Icons.copy),
                            const SizedBox(width: 6),
                            Text(context.l10n.copyUUID),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'open_in_minecraft',
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_new),
                            const SizedBox(width: 6),
                            Text(context.l10n.openInMinecraft),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'favorite',
                        child: Row(
                          children: [
                            Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_outline,
                              color: _isFavorite ? Colors.red : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isFavorite
                                  ? context.l10n.removeFromFavorites
                                  : context.l10n.addToFavorites,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'cart',
                        child: Row(
                          children: [
                            Icon(
                              _isInCart
                                  ? Icons.shopping_cart
                                  : Icons.shopping_cart_outlined,
                              color: _isInCart ? Colors.green : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isInCart
                                  ? context.l10n.removeFromCart
                                  : context.l10n.addToCart,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'open_creator',
                        child: Row(
                          children: [
                            const Icon(Icons.person),
                            const SizedBox(width: 6),
                            Text(context.l10n.creator),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Play/stop button, for emotes
                if (_show3DPreview && widget.item.isEmote)
                  Positioned(
                    top: 52,
                    right: 8,
                    child: ListenableBuilder(
                      listenable: _emoteService,
                      builder: (context, _) {
                        final isPlaying = _emoteService.hasEmote;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: _emoteService.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () async {
                                    if (isPlaying) {
                                      _emoteService.clearEmote();
                                    } else {
                                      await _emoteService.loadEmote(
                                        widget.item,
                                      );
                                    }
                                  },
                                  child: Tooltip(
                                    message: isPlaying ? 'Stop' : 'Play emote',
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        isPlaying
                                            ? Icons.stop
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 23,
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),

                // View/close 3D button, for persona pieces
                if (_show3DPreview && widget.item.isPersonaPiece)
                  Positioned(
                    top: 52,
                    right: 8,
                    child: ListenableBuilder(
                      listenable: _skinService,
                      builder: (context, _) {
                        final isShowing =
                            _skinService.hasSkin &&
                            _skinService.skinData?.primaryPersonaPiece != null;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: _skinService.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () async {
                                    if (isShowing) {
                                      _skinService.clearSkin();
                                    } else {
                                      await _skinService.loadSkin(widget.item);
                                      if (mounted &&
                                          _skinService.error != null) {
                                        _scaffoldMessenger?.showSnackBar(
                                          SnackBar(
                                            content: Text(_skinService.error!),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Tooltip(
                                    message: isShowing ? 'Close 3D' : 'View 3D',
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        isShowing
                                            ? Icons.close
                                            : Icons.view_in_ar,
                                        color: Colors.white,
                                        size: 23,
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),

            // Rating , price and Download row
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 6, right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left section
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (widget.item.avgStars != null &&
                            widget.item.totalStars != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 24,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                widget.item.avgStars!.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '(${widget.item.totalStars})',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          ),
                        if (widget.item.price != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/minecoin.png',
                                width: 20,
                                height: 20,
                                filterQuality: FilterQuality.none,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                widget.item.price.toString(),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Right section (always pinned right)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.item.videoUrl != null &&
                            widget.item.videoUrl!.isNotEmpty)
                          IconButton(
                            tooltip: context.l10n.trailer,
                            icon: const Icon(Icons.play_circle_rounded),
                            onPressed: () async {
                              final url = widget.item.videoUrl!;
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final uri = Uri.parse(url);
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        this.context.l10n.trailerError(
                                          e.toString(),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            iconSize: 29,
                          ),

                        if (widget.isOwned)
                          _buildDownloadStatus(
                            context,
                            downloadService,
                            isCurrentDownload,
                            isInQueue,
                            queuePosition,
                          )
                        else
                          // gesture detector, otherwise the button appearance is different when propagating the onpressed
                          GestureDetector(
                            onTap: () {
                              if (widget.item.packType == 'Server content') {
                                _showServerContentDialog(context);
                              } else if (widget.item.packType == 'DLC') {
                                _showNotADlcDialog(context);
                              } else {
                                _showNotOwnedDialog(context);
                              }
                            },
                            child: OutlinedButton(
                              onPressed: null,
                              child: Icon(
                                Icons.question_mark_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Download progress or queue status
            if ((isCurrentDownload || isInQueue) && widget.isOwned)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCurrentDownload)
                      LinearProgressIndicator(
                        value: downloadService.progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      isCurrentDownload
                          ? downloadService.status
                          : context.l10n.queuePosition(queuePosition),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

            // Content tab selector
            if (widget.item.faqEntries != null ||
                widget.item.howToEntries != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                child: _buildContentTabSelector(),
              ),

            // Description section
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              padding: const EdgeInsets.all(9.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_detailsTab == 0)
                    SelectableText(
                      widget.item.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  else if (_detailsTab == 1 && widget.item.howToEntries != null)
                    ItemHowToSection(
                      title: widget.item.howToTitle,
                      entries: widget.item.howToEntries!,
                    )
                  else if (_detailsTab == 2 && widget.item.faqEntries != null)
                    ItemFaqSection(entries: widget.item.faqEntries!),
                  // Tags row
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        // Vibrant Visuals tag
                        if (widget.item.hasVibrantVisuals)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.5,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  context.l10n.vibrantVisualEnhanced,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        // Version tag
                        if (widget.item.version != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.5,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tag,
                                  size: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'v${widget.item.version}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        // Creation Date tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.5,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatDate(widget.item.creationDate),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.tertiary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        // Last Modified Date tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.5,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.update,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatDate(widget.item.lastModifiedDate),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3D Skin preview section
            if (_show3DPreview &&
                (widget.item.packType == 'SkinPack' ||
                    widget.item.skinBinaryUrl != null))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                child: SkinPackPreview(
                  item: widget.item,
                  skinService: _skinService,
                ),
              ),

            // Persona warning section
            if (widget.item.packType == 'Persona')
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                padding: const EdgeInsets.all(9.0),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.1),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.personaWarning,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Changelog section
            if (widget.item.changelog != null)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                padding: const EdgeInsets.all(9.0),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.update,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.changelog,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    SelectableText(widget.item.changelog!),
                  ],
                ),
              ),

            // Panorama section - displayed after the description
            if (widget.item.imagePanorama != null) ...[
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final panoramaIndex = _downloadableImages.indexOf(
                        widget.item.imagePanorama!,
                      );
                      return PanoramaWithScrollIndicator(
                        imageUrl: widget.item.imagePanorama!,
                        maxWidth: constraints.maxWidth,
                        onLongPress: () {
                          _showDownloadDialog(context, panoramaIndex);
                        },
                        isDesktop: isDesktop,
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContentTabSelector() {
    final primary = Theme.of(context).colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.042),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.14), width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.5),
        child: Row(
          children: [
            _buildTabButton(0, Icons.description_outlined, 'Description'),
            if (widget.item.howToEntries != null)
              _buildTabButton(1, Icons.menu_book_outlined, 'How To'),
            if (widget.item.faqEntries != null)
              _buildTabButton(2, Icons.quiz_outlined, 'FAQ'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int value, IconData icon, String label) {
    final isSelected = _detailsTab == value;
    final primary = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10.5),
          border: isSelected
              ? Border.all(color: primary.withValues(alpha: 0.3), width: 1.2)
              : Border.all(color: Colors.transparent, width: 1.2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _detailsTab = value),
            borderRadius: BorderRadius.circular(10.5),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 7.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? primary
                        : primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? primary
                            : primary.withValues(alpha: 0.8),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  Widget _buildDownloadStatus(
    BuildContext context,
    DownloadService downloadService,
    bool isCurrentDownload,
    bool isInQueue,
    int queuePosition,
  ) {
    if (widget.item.packType == 'Server content') {
      return GestureDetector(
        onTap: () {
          _showServerContentDialog(context);
        },
        child: OutlinedButton(
          onPressed: null,
          child: Icon(
            Icons.question_mark_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (downloadService.isDownloaded(widget.item.dlcId)) {
      if (widget.item.packType == 'Persona') {
        return const OutlinedButton(
          onPressed: null,
          child: Icon(Icons.check_circle_outline_rounded),
        );
      }

      final filePaths = downloadService.getDownloadedFilePaths(
        widget.item.dlcId,
      );
      return ElevatedButton(
        onPressed: filePaths.isNotEmpty
            ? () => showImportDialog(context, filePaths)
            : null,
        child: const Icon(Icons.check_circle_outline_rounded),
      );
    } else if (downloadService.isFailed(widget.item.dlcId)) {
      return ElevatedButton(
        onPressed: () => downloadService.retryDownload(
          widget.item,
          strings: _createDownloadStrings(context),
        ),
        child: const Icon(Icons.refresh),
      );
    } else if (isCurrentDownload) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
        ),
        child: Text(
          '${(downloadService.progress * 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    } else if (isInQueue) {
      return OutlinedButton(
        onPressed: null,
        child: Text(
          context.l10n.queuePosition2(queuePosition),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    } else {
      String sizeText = '';

      if (_downloadSize != null && _downloadSize! > 0) {
        if (_downloadSize! >= 1024 * 1024 * 1024) {
          // GB
          sizeText =
              '${(_downloadSize! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
        } else if (_downloadSize! >= 1024 * 1024) {
          // MB (1 MB or more)
          sizeText =
              '${(_downloadSize! / (1024 * 1024)).toStringAsFixed(0)} MB';
        } else {
          // Less than 1 MB, show as KB
          sizeText = '${(_downloadSize! / 1024).toStringAsFixed(0)} KB';
        }
      }

      // without the 24 h pass the button opens the gate instead of the queue;
      // DownloadService is what decides, this only says so up front
      return AnimatedBuilder(
        animation: KzPass.instance,
        builder: (context, _) {
          final bool locked = !KzPass.instance.active;

          return ElevatedButton(
            onPressed: () {
              final variants = widget.item.downloadVariants;
              if (!locked && variants.length > 1) {
                _showVariantPickerDialog(context, downloadService);
              } else {
                downloadService.downloadItem(
                  widget.item,
                  strings: _createDownloadStrings(context),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(locked ? Icons.lock_open : Icons.download, size: 20),
                if (locked) ...[
                  const SizedBox(width: 6),
                  const Text('Unlock 24 h'),
                ] else if (_loadingSize) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ] else if (sizeText.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(sizeText),
                ],
              ],
            ),
          );
        },
      );
    }
  }

  void _showVariantPickerDialog(
    BuildContext context,
    DownloadService downloadService,
  ) {
    final variants = widget.item.downloadVariants;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: variants.map((variant) {
            return ListTile(
              leading: Icon(
                variant.isDefault
                    ? Icons.inventory_2_outlined
                    : Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(variant.label),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                Navigator.of(dialogContext).pop();
                downloadService.downloadItem(
                  widget.item,
                  strings: _createDownloadStrings(context),
                  urlOverride: variant.urls,
                  variantLabel: variant.isDefault ? null : variant.label,
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _showServerContentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.faqServerContent),
        content: Text(context.l10n.faqServerContentDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showNotADlcDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.faqNotAdlc),
        content: Text(context.l10n.faqNotAdlcDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showNotOwnedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _faqEntry(
              context,
              question: context.l10n.faqQuestionDownload,
              answer: context.l10n.faqAnswerDownload,
            ),
            const SizedBox(height: 12),
            _faqEntry(
              context,
              question: context.l10n.faqQuestionKey,
              answer: context.l10n.faqAnswerKey,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FaqView()));
            },
            child: Text(context.l10n.faqMoreHelp),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  Widget _faqEntry(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          answer,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  void _showDownloadDialog(BuildContext context, int imageIndex) {
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.downloadImage),
          content: Text(context.l10n.downloadImageQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadSingleImage(messenger, imageIndex);
              },
              child: Text(context.l10n.download),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadSingleImage(
    ScaffoldMessengerState messenger,
    int imageIndex,
  ) async {
    try {
      final settingsService = SettingsService.instance;
      final saveAsPng = await settingsService.getPng();
      final saveToGallery = await settingsService.getGallery();

      String outputFolder;
      String? itemFolderName;

      final isGallerySupported = Platform.isAndroid || Platform.isWindows;
      final shouldSaveToGallery = saveToGallery && isGallerySupported;

      if (shouldSaveToGallery) {
        outputFolder = ''; // Gallery doesn't need a custom folder structure
        itemFolderName = null;
      } else {
        outputFolder = await settingsService.getDownloadPath();
        final sanitizedTitle = _sanitizeFolderName(widget.item.title);
        itemFolderName = sanitizedTitle;

        // Only create directory for regular file paths, not content URIs
        if (!outputFolder.startsWith('content://')) {
          final itemFolder = '$outputFolder/$sanitizedTitle';
          final directory = Directory(itemFolder);
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        }
      }

      final imageUrl = _downloadableImages[imageIndex];
      final response = await AppHttpClient.instance.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        final uri = Uri.parse(imageUrl);
        String originalExtension = path.extension(uri.path).toLowerCase();
        Uint8List imageBytes = response.bodyBytes;

        String finalExtension = originalExtension;

        // Convert to PNG if needed
        if (saveAsPng && originalExtension != '.png') {
          final decodedImage = await decodeImageFromList(imageBytes);
          final recorder = PictureRecorder();
          final canvas = Canvas(recorder);
          final paint = Paint();
          canvas.drawImage(decodedImage, Offset.zero, paint);
          final picture = recorder.endRecording();
          final img = await picture.toImage(
            decodedImage.width,
            decodedImage.height,
          );
          final byteData = await img.toByteData(format: ImageByteFormat.png);
          imageBytes = byteData!.buffer.asUint8List();
          finalExtension = '.png';
        }

        String baseFilename;
        if (widget.item.imagePanorama != null &&
            imageUrl == widget.item.imagePanorama!) {
          baseFilename = 'panorama';
        } else {
          baseFilename = 'image_${imageIndex + 1}';
        }

        if (shouldSaveToGallery) {
          // Gal automatically detect the type of the file so the extension is not passed
          await Gal.putImageBytes(imageBytes, name: baseFilename);

          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(context.l10n.imageSavedToGallery(baseFilename)),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else if (outputFolder.startsWith('content://')) {
          // Save to content URI
          const platform = MethodChannel('xyz.kyzendlc.app/storage');

          final filename = itemFolderName != null
              ? '$itemFolderName/$baseFilename$finalExtension'
              : '$baseFilename$finalExtension';

          final fileUri = await platform.invokeMethod<String>(
            'writeFileBytes',
            {'uri': outputFolder, 'fileName': filename, 'bytes': imageBytes},
          );

          if (fileUri != null && mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(context.l10n.imageSaved(filename)),
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            throw Exception('Failed to write file to storage');
          }
        } else {
          String filename = '$baseFilename$finalExtension';
          final filePath = '$outputFolder/$itemFolderName/$filename';
          final file = File(filePath);
          await file.writeAsBytes(imageBytes);

          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(context.l10n.imageSaved(filePath)),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (!mounted) return;
        throw Exception(
          'Failed to download image: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorDownloadingImage(e.toString())),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _sanitizeFolderName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }
}

DownloadStrings _createDownloadStrings(BuildContext context) =>
    DownloadStrings.of(context);
