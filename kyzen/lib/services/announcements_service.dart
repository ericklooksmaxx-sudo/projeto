import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/announcement.dart';
import 'app_version.dart';
import 'http_client.dart';
import 'settings_service.dart';

class AnnouncementsService {
  static const _endpoint = String.fromEnvironment('ANNOUNCEMENTS_URL');
  static bool _missingUrlWarned = false;

  static final ValueNotifier<bool> hasUnreadNotifier = ValueNotifier<bool>(
    false,
  );

  static String _lastRawContent = '';
  static List<Announcement>? _cachedAnnouncements;
  static Future<List<Announcement>>? _inFlightFetch;

  // ig it should be fine this approach to check if the announcements changed
  static String computeHash(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    return md5.convert(utf8.encode(input.trim())).toString();
  }

  static Future<void> checkUnreadStatus(
    String rawContent, {
    bool isTabActive = false,
  }) async {
    _lastRawContent = rawContent;
    final currentHash = computeHash(rawContent);
    if (currentHash.isEmpty) {
      hasUnreadNotifier.value = false;
      return;
    }

    if (isTabActive) {
      await markAsRead(rawContent);
      return;
    }

    final lastReadHash = await SettingsService.instance
        .getLastReadAnnouncementHash();
    hasUnreadNotifier.value = (lastReadHash != currentHash);
  }

  static Future<void> markAsRead([String? rawContent]) async {
    final target = rawContent ?? _lastRawContent;
    final currentHash = computeHash(target);
    if (currentHash.isNotEmpty) {
      await SettingsService.instance.setLastReadAnnouncementHash(currentHash);
    }
    hasUnreadNotifier.value = false;
  }

  static Future<List<Announcement>> fetchAnnouncements({
    bool forceRefresh = false,
    bool isTabActive = false,
  }) async {
    if (!forceRefresh && _cachedAnnouncements != null) {
      await checkUnreadStatus(_lastRawContent, isTabActive: isTabActive);
      return _cachedAnnouncements!;
    }

    if (!forceRefresh && _inFlightFetch != null) {
      final results = await _inFlightFetch!;
      await checkUnreadStatus(_lastRawContent, isTabActive: isTabActive);
      return results;
    }

    _inFlightFetch = _performHttpFetch(isTabActive: isTabActive);
    try {
      final results = await _inFlightFetch!;
      return results;
    } finally {
      _inFlightFetch = null;
    }
  }

  static Future<List<Announcement>> _performHttpFetch({
    bool isTabActive = false,
  }) async {
    if (_endpoint.isEmpty) {
      if (!_missingUrlWarned) {
        _missingUrlWarned = true;
        debugPrint(
          '[AnnouncementsService] ANNOUNCEMENTS_URL is not set. '
          'Build with --dart-define-from-file=.env.json. '
          'Returning empty list.',
        );
      }
      hasUnreadNotifier.value = false;
      return [];
    }

    try {
      final response = await AppHttpClient.instance
          .get(
            Uri.parse(_endpoint),
            headers: {'User-Agent': AppVersion.userAgent},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          '[AnnouncementsService] Failed to fetch announcements: '
          'HTTP ${response.statusCode}',
        );
        throw Exception('Server returned code ${response.statusCode}');
      }

      final rawBody = response.body;
      final dynamic decoded = jsonDecode(rawBody);

      final List<dynamic>? rawList = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic>
                ? (decoded['announcements'] ??
                      decoded['data'] ??
                      decoded['items'])
                : null);

      final List<Announcement> results = rawList != null
          ? rawList
                .whereType<Map<String, dynamic>>()
                .map(Announcement.fromJson)
                .toList()
          : [];

      _lastRawContent = rawBody;
      _cachedAnnouncements = results;
      await checkUnreadStatus(rawBody, isTabActive: isTabActive);
      return results;
    } catch (e) {
      debugPrint('[AnnouncementsService] Error fetching announcements: $e');
      rethrow;
    }
  }
}
