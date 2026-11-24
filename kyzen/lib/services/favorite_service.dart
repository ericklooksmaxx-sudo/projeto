import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:material_ui/material_ui.dart' show debugPrint;

class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();

  factory FavoriteService() {
    return _instance;
  }

  FavoriteService._internal();

  static const String _fileName = 'favorites.json';
  Set<String> _favorites = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadFavorites();
    _isInitialized = true;
  }

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _loadFavorites() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        _favorites = jsonList.cast<String>().toSet();
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _favorites = {};
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final file = await _getFile();
      final jsonString = json.encode(_favorites.toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  bool isFavorite(String dlcId) {
    return _favorites.contains(dlcId);
  }

  Future<void> addFavorite(String dlcId) async {
    if (_favorites.add(dlcId)) {
      await _saveFavorites();
    }
  }

  Future<void> removeFavorite(String dlcId) async {
    if (_favorites.remove(dlcId)) {
      await _saveFavorites();
    }
  }

  Future<bool> toggleFavorite(String dlcId) async {
    if (isFavorite(dlcId)) {
      await removeFavorite(dlcId);
      return false;
    } else {
      await addFavorite(dlcId);
      return true;
    }
  }

  List<String> getAllFavorites() {
    return List.unmodifiable(_favorites);
  }

  Future<void> clearAll() async {
    _favorites.clear();
    await _saveFavorites();
  }
}
