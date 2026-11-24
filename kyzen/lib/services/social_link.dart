import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_client.dart';

import 'app_version.dart';

class SocialLink {
  final String title;
  final String url;
  final String? icon;

  const SocialLink({required this.title, required this.url, this.icon});
}

class SocialLinksService {
  static const List<SocialLink> fallback = [
    SocialLink(
      title: 'Telegram',
      url: 'https://t.me/+gmyoKQUeX30wNTU0',
      icon: 'telegram',
    ),
    SocialLink(
      title: 'Discord',
      url: 'https://discord.gg/XHgyapNEx8',
      icon: 'discord',
    ),
  ];

  static const _endpoint = String.fromEnvironment('SOCIAL_LINKS_URL');
  static bool _missingUrlWarned = false;

  static List<SocialLink>? _cachedLinks;
  static Future<(List<SocialLink>, bool)>? _pendingFetch;

  static List<SocialLink>? get cachedLinks => _cachedLinks;

  static Future<(List<SocialLink>, bool)> fetch({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedLinks != null) {
      return (_cachedLinks!, false);
    }

    if (_pendingFetch != null) {
      return _pendingFetch!;
    }

    _pendingFetch = _doFetch();
    try {
      return await _pendingFetch!;
    } finally {
      _pendingFetch = null;
    }
  }

  static Future<(List<SocialLink>, bool)> _doFetch() async {
    if (_endpoint.isEmpty) {
      if (!_missingUrlWarned) {
        _missingUrlWarned = true;
        debugPrint(
          '[SocialLinksService] SOCIAL_LINKS_URL is not set. '
          'Build with --dart-define-from-file=.env.json. '
          'Using fallback links.',
        );
      }
      _cachedLinks = fallback;
      return (fallback, false);
    }

    try {
      final response = await AppHttpClient.instance
          .get(
            Uri.parse(_endpoint),
            headers: {'User-Agent': AppVersion.userAgent},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final links = data.entries
            .map(
              (e) => SocialLink(
                title: _capitalize(e.key),
                url: e.value as String,
                icon: e.key.toLowerCase(),
              ),
            )
            .toList();
        _cachedLinks = links;
        return (links, false);
      } else {
        debugPrint(
          '[SocialLinksService] Failed to fetch links: HTTP ${response.statusCode}',
        );
        _cachedLinks ??= fallback;
        return (_cachedLinks!, true);
      }
    } catch (e) {
      debugPrint('[SocialLinksService] Error fetching links: $e');
      _cachedLinks ??= fallback;
      return (_cachedLinks!, true);
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
