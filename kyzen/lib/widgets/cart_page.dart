import 'dart:math';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';
import '../services/cart_service.dart';
import '../services/search_service.dart';
import '../api/playfabapi.dart';
import 'search_result_item.dart';
import 'search_result_grid_item.dart';
import '../models/search_result.dart';

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.searchService,
    required this.pageSize,
    this.onCartChanged, // this is used to update the cart count in the AuthPage
    //(eg. user open auth page -> open cart page -> purchase items -> return to auth page with updated cart count)
  });

  final SearchService searchService;
  final int pageSize;
  final ValueChanged<int>? onCartChanged;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartService _cartService = CartService();
  final PlayFabClient _client = PlayFabClient.instance;

  List<SearchResult> _cartResults = [];
  bool _isLoading = false;
  bool _isPurchasing = false;
  String? _statusMessage;
  Color? _statusColor;

  @override
  void initState() {
    super.initState();
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await _cartService.initialize();
      await _loadCartItems();
    } catch (e) {
      setState(() {
        _statusMessage = context.l10n.errorInitializingCart(e.toString());
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCartItems() async {
    try {
      final results = await widget.searchService.searchCartItems();
      setState(() {
        _cartResults = results;
      });
    } catch (e) {
      setState(() {
        _statusMessage = context.l10n.errorLoadingCartItems(e.toString());
        _statusColor = Colors.red;
      });
    }
  }

  int _calculateTotalPrice() {
    int total = 0;
    for (var item in _cartResults) {
      if (item.price is int) {
        total += item.price as int;
      } else if (item.price is double) {
        total += (item.price as double).round();
      }
    }
    return total;
  }

  Future<void> _purchaseAllItems() async {
    if (_cartResults.isEmpty) return;

    final confirmed = await _showConfirmDialog();
    if (confirmed != true) return;

    setState(() {
      _isPurchasing = true;
      _statusMessage = null;
    });

    final List<String> successItems = [];
    final List<String> alreadyOwnedItems = [];
    final List<String> notPurchasableItems = [];
    final List<String> insufficientFundsItems = [];
    final List<String> failedItems = [];

    final itemsToPurchase = List<SearchResult>.from(_cartResults);

    for (int i = 0; i < itemsToPurchase.length; i++) {
      final item = itemsToPurchase[i];

      setState(() {
        _statusMessage =
            '${context.l10n.purchasing} ${i + 1}/${itemsToPurchase.length}: ${item.title}';
        _statusColor = Colors.blue;
      });

      try {
        final result = await _client.purchaseItemById(
          itemId: item.dlcId,
          expectedPrice: item.price?.toString() ?? '0',
        );

        if (result.success) {
          successItems.add(item.title);
          await _removeFromCartAndUpdate(item.dlcId);
        } else if (result.isAlreadyOwned) {
          alreadyOwnedItems.add(item.title);
          await _removeFromCartAndUpdate(item.dlcId);
        } else if (result.isNotPurchasable) {
          notPurchasableItems.add(item.title);
          await _removeFromCartAndUpdate(item.dlcId);
        } else if (result.isInsufficientFunds) {
          insufficientFundsItems.add(item.title);
          // Don't remove from cart if insufficient funds
        } else {
          failedItems.add(item.title);
          debugPrint(
            'Failed to purchase ${item.title}: ${result.errorMessage}',
          );
          await _removeFromCartAndUpdate(item.dlcId);
        }
      } catch (e) {
        failedItems.add(item.title);
        debugPrint('Error purchasing ${item.title}: $e');
      }

      if (i < itemsToPurchase.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    await _loadCartItems();

    setState(() {
      _isPurchasing = false;
      final totalItems = itemsToPurchase.length;

      if (successItems.length == totalItems) {
        _statusMessage = context.l10n.allItemsSuccessfullyPurchased;
        _statusColor = Colors.green;
      } else if (insufficientFundsItems.isNotEmpty) {
        _statusMessage = context.l10n.insufficientFunds(
          insufficientFundsItems.length,
        );
        _statusColor = Colors.orange;
      } else if (failedItems.isNotEmpty) {
        _statusMessage = context.l10n.somePurchasesFailed;
        _statusColor = Colors.red;
      } else if (notPurchasableItems.isNotEmpty) {
        _statusMessage = context.l10n.numItemsAreNotPurchasable(
          notPurchasableItems.length,
        );
        _statusColor = Colors.orange;
      } else {
        _statusMessage = context.l10n.purchaseComplete;
        _statusColor = Colors.green;
      }
    });

    if (mounted) {
      _showResultDialog(
        successItems,
        alreadyOwnedItems,
        notPurchasableItems,
        insufficientFundsItems,
        failedItems,
      );
    }
  }

  Future<bool?> _showConfirmDialog() {
    final totalPrice = _calculateTotalPrice();
    final itemTitles = _cartResults.map((item) => item.title).toList();

    String itemsText;
    if (itemTitles.length == 1) {
      itemsText = '"${itemTitles[0]}"';
    } else if (itemTitles.length == 2) {
      itemsText = '"${itemTitles[0]}" and "${itemTitles[1]}"';
    } else if (itemTitles.length <= 10) {
      final lastItem = itemTitles.last;
      final otherItems = itemTitles.sublist(0, itemTitles.length - 1);
      itemsText =
          '${otherItems.map((t) => '"$t"').join(', ')}, and "$lastItem"';
    } else {
      itemsText = '${itemTitles.length} items';
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmPurchase),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.confirmPurchaseMessage(itemsText),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    context.l10n.totalPrice,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Image.asset('assets/minecoin.png', width: 24, height: 24),
                  const SizedBox(width: 5),
                  Text(
                    totalPrice.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirmPurchase),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(
    List<String> successItems,
    List<String> alreadyOwnedItems,
    List<String> notPurchasableItems,
    List<String> insufficientFundsItems,
    List<String> failedItems,
  ) {
    // Calculate if all items were successful
    final allSuccessful =
        successItems.isNotEmpty &&
        alreadyOwnedItems.isEmpty &&
        notPurchasableItems.isEmpty &&
        insufficientFundsItems.isEmpty &&
        failedItems.isEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              allSuccessful ? Icons.check_circle : Icons.info_outline,
              color: allSuccessful ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(context.l10n.purchaseResults),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (successItems.isNotEmpty) ...[
                _buildResultItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: context.l10n.successfullyPurchased(successItems.length),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: successItems
                        .map(
                          (title) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• $title',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (alreadyOwnedItems.isNotEmpty) ...[
                _buildResultItem(
                  icon: Icons.inventory,
                  color: Colors.blue,
                  text: context.l10n.alreadyOwnded(alreadyOwnedItems.length),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: alreadyOwnedItems
                        .map(
                          (title) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• $title',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (notPurchasableItems.isNotEmpty) ...[
                _buildResultItem(
                  icon: Icons.block,
                  color: Colors.grey,
                  text: context.l10n.numItemsAreNotPurchasable(
                    notPurchasableItems.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: notPurchasableItems
                        .map(
                          (title) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• $title',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (insufficientFundsItems.isNotEmpty) ...[
                _buildResultItem(
                  icon: Icons.wallet,
                  color: Colors.orange,
                  text: context.l10n.insufficientFunds(
                    insufficientFundsItems.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: insufficientFundsItems
                        .map(
                          (title) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• $title',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (failedItems.isNotEmpty) ...[
                _buildResultItem(
                  icon: Icons.error_outline,
                  color: Colors.red,
                  text: context.l10n.numItemsFailed(failedItems.length),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: failedItems
                        .map(
                          (title) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• $title',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromCartAndUpdate(String dlcId) async {
    await _cartService.removeFromCart(dlcId);
    await _loadCartItems();
    widget.onCartChanged?.call(_cartResults.length);
  }

  Future<void> _removeItem(SearchResult item) async {
    await _removeFromCartAndUpdate(item.dlcId);
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(context.l10n.clearCart),
          ],
        ),
        content: Text(context.l10n.clearCartConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.clearAll),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cartService.clearCart();
      await _loadCartItems();
      widget.onCartChanged?.call(_cartResults.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _calculateTotalPrice();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cartTitleNum(_cartResults.length)),
        actions: [
          if (_cartResults.isNotEmpty && !_isPurchasing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearCart,
              tooltip: context.l10n.clearCart,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartResults.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/cart.png'),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.cartisEmpty,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.cartEmptyDescription,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_statusMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: (_statusColor ?? Colors.blue).withValues(alpha: 0.1),
                    child: Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _statusColor ?? Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      Builder(
                        builder: (context) {
                          final isPortrait =
                              MediaQuery.of(context).orientation ==
                              Orientation.portrait;

                          if (isPortrait) {
                            return SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => SearchResultItem(
                                  item: _cartResults[index],
                                  searchService: widget.searchService,
                                  onRemove: () =>
                                      _removeItem(_cartResults[index]),
                                  showRemoveButton: !_isPurchasing,
                                  pageSize: widget.pageSize,
                                ),
                                childCount: _cartResults.length,
                              ),
                            );
                          }

                          final crossAxisCount = min(
                            (MediaQuery.of(context).size.width / 350).floor(),
                            5,
                          );

                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.2,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => SearchResultGridItem(
                                item: _cartResults[index],
                                searchService: widget.searchService,
                                onRemove: () =>
                                    _removeItem(_cartResults[index]),
                                showRemoveButton: !_isPurchasing,
                                pageSize: widget.pageSize,
                              ),
                              childCount: _cartResults.length,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (_cartResults.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          // Total Price Box
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/minecoin.png',
                                  width: 26,
                                  height: 26,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  totalPrice.toString(),
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Purchase Button
                          Expanded(
                            child: FilledButton(
                              onPressed: _isPurchasing
                                  ? null
                                  : _purchaseAllItems,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                              ),
                              child: _isPurchasing
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(context.l10n.purchasing),
                                      ],
                                    )
                                  : Text(
                                      context.l10n.purchaseAllnum(
                                        _cartResults.length,
                                      ),
                                    ),
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
}
