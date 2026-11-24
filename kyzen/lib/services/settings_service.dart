import 'dart:io';
import 'dart:convert';
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'key_filter.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();
  factory SettingsService() => instance;

  static const String _fileName = 'settings_app.json';
  Map<String, dynamic>? _settings;
  Future<Map<String, dynamic>>? _loadingFuture;

  // this is used to notify the ui if the path change (eg. revoked uri, folder deleted)
  // passes the old custom path that was cleared
  ValueChanged<String>? onDownloadPathAutoReset;

  // Default settings
  static const Map<String, dynamic> _defaultSettings = {
    'isDarkMode': true,
    'colorScheme': null,
    'keyFilter': KeyFilterType.showAll,
    'KeyUpdate': true,
    'ShowSkins': true,
    'Languages': 'en',
    'OnlyNewKeys': false,
    'PNG': false,
    'ImageToGallery': false,
    'NormalCompression': true,
    'LoadSkinPersona': false,
    'LoadOnlyNewKeys': false,
    'apiLanguage': 'en',
    'pageSize': 30,
    'mcFont': false,
    'customDownloadPath': null,
    'minecraftPackageName': 'com.mojang.minecraftpe',
    'updateIgnoredUntil': null,
    'freeDroidWarnShown': false,
    '3dpreview': true,
    'adaptiveResolution': false,
    '3dUnsupportedWarnShown': false,
  };

  Future<Map<String, dynamic>> _loadFromDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');

      if (!await file.exists()) {
        await _saveSettings(_defaultSettings);
        return Map<String, dynamic>.from(_defaultSettings);
      }

      final jsonString = await file.readAsString();
      final settings = json.decode(jsonString) as Map<String, dynamic>;

      // Merge with defaults to ensure all required keys exist
      final mergedSettings = Map<String, dynamic>.from(_defaultSettings);
      mergedSettings.addAll(settings);
      return mergedSettings;
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return Map<String, dynamic>.from(_defaultSettings);
    }
  }

  Future<Map<String, dynamic>> _ensureLoaded() async {
    if (_settings != null) {
      return _settings!;
    }

    if (_loadingFuture != null) {
      _settings = await _loadingFuture!;
      return _settings!;
    }

    _loadingFuture = _loadFromDisk();
    try {
      _settings = await _loadingFuture!;
    } finally {
      _loadingFuture = null;
    }
    return _settings!;
  }

  Future<Map<String, dynamic>> loadSettings() async {
    return await _ensureLoaded();
  }

  /// Save settings to local storage
  Future<void> _saveSettings(Map<String, dynamic> settings) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      final jsonString = json.encode(settings);
      await file.writeAsString(jsonString);
      _settings = Map<String, dynamic>.from(settings);
    } catch (e) {
      debugPrint('Error saving settings: $e');
      throw Exception('Failed to save settings');
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final currentSettings = await _ensureLoaded();
    currentSettings[key] = value;
    await _saveSettings(currentSettings);
  }

  Future<T> getSetting<T>(String key, T defaultValue) async {
    final settings = await _ensureLoaded();
    return settings[key] as T? ?? defaultValue;
  }

  Future<void> setDarkMode(bool isDark) async {
    await updateSetting('isDarkMode', isDark);
  }

  Future<bool> getDarkMode() async {
    return await getSetting('isDarkMode', true);
  }

  Future<void> setCompression(bool normalCompression) async {
    await updateSetting('NormalCompression', normalCompression);
  }

  Future<bool> getCompression() async {
    return await getSetting('NormalCompression', true);
  }

  Future<void> setKeyUpdate(bool value) async {
    await updateSetting('KeyUpdate', value);
  }

  Future<bool> getKeyUpdate() async {
    return await getSetting('KeyUpdate', true);
  }

  Future<void> setKeyExport(bool value) async {
    await updateSetting('OnlyNewKeys', value);
  }

  Future<bool> getKeyExport() async {
    return await getSetting('OnlyNewKeys', false);
  }

  Future<void> setPng(bool value) async {
    await updateSetting('PNG', value);
  }

  Future<bool> getPng() async {
    return await getSetting('PNG', false);
  }

  Future<void> setGallery(bool value) async {
    await updateSetting('ImageToGallery', value);
  }

  Future<bool> getGallery() async {
    return await getSetting('ImageToGallery', false);
  }

  Future<void> setSkinsFilter(bool value) async {
    await updateSetting('ShowSkins', value);
  }

  Future<bool> getSkinsFilter() async {
    return await getSetting('ShowSkins', true);
  }

  Future<void> setColorScheme(String? colorScheme) async {
    await updateSetting('colorScheme', colorScheme);
  }

  Future<String?> getColorScheme() async {
    return await getSetting<String?>('colorScheme', null);
  }

  Future<void> setCustomColor(Color color) async {
    await updateSetting('customColor', color.toARGB32());
  }

  Future<Color?> getCustomColor() async {
    final colorValue = await getSetting<int?>('customColor', null);
    return colorValue != null ? Color(colorValue) : null;
  }

  Future<void> setKeyFilter(String filter) async {
    await updateSetting('keyFilter', filter);
  }

  Future<String> getKeyFilter() async {
    return await getSetting('keyFilter', KeyFilterType.showAll);
  }

  Future<void> setLanguage(String lang) async {
    await updateSetting('Languages', lang);
  }

  Future<String> getLanguage() async {
    return await getSetting('Languages', 'en');
  }

  Future<void> setApiLanguage(String lang) async {
    await updateSetting('apiLanguage', lang);
  }

  Future<String> getApiLanguage() async {
    return await getSetting('apiLanguage', 'en');
  }

  Future<void> setLoadSkinPersona(bool value) async {
    await updateSetting('LoadSkinPersona', value);
  }

  Future<bool> getLoadSkinPersona() async {
    return await getSetting('LoadSkinPersona', false);
  }

  Future<void> setLoadOnlyNewKeys(bool value) async {
    await updateSetting('LoadOnlyNewKeys', value);
  }

  Future<bool> getLoadOnlyNewKeys() async {
    return await getSetting('LoadOnlyNewKeys', false);
  }

  Future<void> setPageSize(int pageSize) async {
    await updateSetting('pageSize', pageSize);
  }

  Future<int> getPageSize() async {
    return await getSetting('pageSize', 30);
  }

  Future<void> updateFont(bool useMcFont) async {
    await updateSetting('mcFont', useMcFont);
  }

  Future<bool> getFont() async {
    return await getSetting('mcFont', false);
  }

  Future<String?> getFontFamily() async {
    final useMcFont = await getFont();
    return useMcFont ? 'MinecraftFont' : null;
  }

  Future<String> getDownloadPath() async {
    final customPath = await getSetting<String?>('customDownloadPath', null);
    if (customPath != null && customPath.isNotEmpty) {
      // we check if uri exists on the native side since on dart it can't be checked if it exists
      if (customPath.startsWith('content://')) {
        try {
          const storageChannel = MethodChannel('xyz.kyzendlc.app/storage');
          final bool accessible = await storageChannel.invokeMethod(
            'checkUriPermission',
            {'uri': customPath},
          );
          if (accessible) return customPath;
        } catch (_) {}
        await updateSetting('customDownloadPath', null);
        onDownloadPathAutoReset?.call(customPath);
      } else {
        final directory = Directory(customPath);
        if (await directory.exists()) {
          return customPath;
        }
        // fall back to default
        await updateSetting('customDownloadPath', null);
        onDownloadPathAutoReset?.call(customPath);
      }
    }

    // default path
    final downloadDir = await getDownloadDirectory();
    final defaultPath = '${downloadDir.path}/Kyzen';
    final directory = Directory(defaultPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return defaultPath;
  }

  Future<String?> getCustomDownloadPath() async {
    return await getSetting<String?>('customDownloadPath', null);
  }

  Future<void> setCustomDownloadPath(String? path) async {
    if (path == null || path.isEmpty) {
      await updateSetting('customDownloadPath', null);
      return;
    }

    // For content URIs (Android SAF)
    if (path.startsWith('content://')) {
      await updateSetting('customDownloadPath', path);
      return;
    }

    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    await updateSetting('customDownloadPath', path);
  }

  Future<void> setDevMode(bool enabled) async {
    await updateSetting('devModeEnabled', enabled);
  }

  Future<bool> getDevMode() async {
    return await getSetting('devModeEnabled', false);
  }

  Future<String> getMinecraftPackageName() async {
    return await getSetting<String>(
      'minecraftPackageName',
      'com.mojang.minecraftpe',
    );
  }

  Future<void> setMinecraftPackageName(String packageName) async {
    await updateSetting('minecraftPackageName', packageName);
  }

  Future<void> ignoreUpdateForDays([int days = 1]) async {
    final expiry = DateTime.now()
        .add(Duration(days: days))
        .millisecondsSinceEpoch;
    await updateSetting('updateIgnoredUntil', expiry);
  }

  Future<bool> isUpdateIgnored() async {
    final expiry = await getSetting<int?>('updateIgnoredUntil', null);
    if (expiry == null) return false;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  Future<void> clearUpdateIgnored() async {
    await updateSetting('updateIgnoredUntil', null);
  }

  Future<void> setLastReadAnnouncementHash(String hash) async {
    await updateSetting('lastReadAnnouncementHash', hash);
  }

  Future<String?> getLastReadAnnouncementHash() async {
    return await getSetting<String?>('lastReadAnnouncementHash', null);
  }

  Future<bool> getFreeDroidWarnShown() async {
    return await getSetting<bool>('freeDroidWarnShown', false);
  }

  Future<void> setFreeDroidWarnShown([bool shown = true]) async {
    await updateSetting('freeDroidWarnShown', shown);
  }

  Future<void> set3DPreview(bool value) async {
    await updateSetting('3dpreview', value);
  }

  Future<bool> get3DPreview() async {
    return await getSetting('3dpreview', true);
  }

  bool get3DPreviewSync() {
    return _settings?['3dpreview'] as bool? ??
        (_defaultSettings['3dpreview'] as bool);
  }

  Future<void> setAdaptiveResolution(bool value) async {
    await updateSetting('adaptiveResolution', value);
  }

  Future<bool> getAdaptiveResolution() async {
    return await getSetting('adaptiveResolution', false);
  }

  bool getAdaptiveResolutionSync() {
    return _settings?['adaptiveResolution'] as bool? ??
        (_defaultSettings['adaptiveResolution'] as bool);
  }

  Future<bool> get3DUnsupportedWarnShown() async {
    return await getSetting<bool>('3dUnsupportedWarnShown', false);
  }

  Future<void> set3DUnsupportedWarnShown([bool shown = true]) async {
    await updateSetting('3dUnsupportedWarnShown', shown);
  }

  bool get3DUnsupportedWarnShownSync() {
    return _settings?['3dUnsupportedWarnShown'] as bool? ??
        (_defaultSettings['3dUnsupportedWarnShown'] as bool);
  }

  /// Reset all settings to default
  Future<void> resetToDefaults() async {
    await _saveSettings(_defaultSettings);
  }
}
