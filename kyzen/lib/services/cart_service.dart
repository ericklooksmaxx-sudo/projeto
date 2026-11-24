import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:material_ui/material_ui.dart' show debugPrint;

class CartService {
  static final CartService _instance = CartService._internal();

  factory CartService() {
    return _instance;
  }

  CartService._internal();

  static const String _fileName = 'cart.json';
  Set<String> _cartItems = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadCart();
    _isInitialized = true;
  }

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _loadCart() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        _cartItems = jsonList.cast<String>().toSet();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
      _cartItems = {};
    }
  }

  Future<void> _saveCart() async {
    try {
      final file = await _getFile();
      final jsonString = json.encode(_cartItems.toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  bool isInCart(String dlcId) {
    return _cartItems.contains(dlcId);
  }

  Future<void> addToCart(String dlcId) async {
    if (_cartItems.add(dlcId)) {
      await _saveCart();
    }
  }

  Future<void> removeFromCart(String dlcId) async {
    if (_cartItems.remove(dlcId)) {
      await _saveCart();
    }
  }

  Future<bool> toggleCart(String dlcId) async {
    if (isInCart(dlcId)) {
      await removeFromCart(dlcId);
      return false;
    } else {
      await addToCart(dlcId);
      return true;
    }
  }

  List<String> getAllCartItems() {
    return List.unmodifiable(_cartItems);
  }

  int getCartCount() {
    return _cartItems.length;
  }

  Future<void> clearCart() async {
    _cartItems.clear();
    await _saveCart();
  }
}
