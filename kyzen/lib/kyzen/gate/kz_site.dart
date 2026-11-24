import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../services/app_version.dart';
import '../../services/http_client.dart';

/// The Kyzen site, as the app talks to it.
///
/// The 24 h pass lives in cookies the site sets (`kz_device` ties the pass to
/// this device, `lv_unlock` is the pass itself), so every call shares one jar
/// and the jar is written to disk — the pass has to survive a restart.
class KzSite {
  KzSite._();

  static const String host = 'kyzendlc.xyz';
  static const String base = 'https://$host';

  /// Scheme the gate page uses to hand the pass back:
  /// `intent://unlock?c=<code>#Intent;scheme=kyzen;package=xyz.kyzendlc.app;end`
  static const String unlockScheme = 'kyzen';

  static const Duration _timeout = Duration(seconds: 25);
  static const String _jarFile = 'kyzen_cookies.json';

  static final Map<String, String> _jar = <String, String>{};
  static bool _jarLoaded = false;
  static Future<void>? _jarLoading;

  static String get userAgent {
    final String platform = Platform.operatingSystem;
    final String release = Platform.operatingSystemVersion.replaceAll(
      RegExp(r'[^A-Za-z0-9 ._()\-/:]'),
      '',
    );
    return 'KyzenApp/${AppVersion.string} ($platform; $release)';
  }

  // ── cookie jar ────────────────────────────────────────────────────────

  static Future<void> loadJar() {
    if (_jarLoaded) return Future<void>.value();
    return _jarLoading ??= _loadJar();
  }

  static Future<void> _loadJar() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File f = File('${dir.path}/$_jarFile');
      if (await f.exists()) {
        final dynamic data = json.decode(await f.readAsString());
        if (data is Map) {
          data.forEach((dynamic k, dynamic v) {
            if (k is String && v is String) _jar[k] = v;
          });
        }
      }
    } catch (e) {
      debugPrint('KzSite: could not read the cookie jar: $e');
    } finally {
      _jarLoaded = true;
      _jarLoading = null;
    }
  }

  static Future<void> _saveJar() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File f = File('${dir.path}/$_jarFile');
      await f.writeAsString(json.encode(_jar), flush: true);
    } catch (e) {
      debugPrint('KzSite: could not write the cookie jar: $e');
    }
  }

  /// Drops every cookie (used when the pass is reset by hand).
  static Future<void> clearJar() async {
    _jar.clear();
    await _saveJar();
  }

  static String? get cookieHeader {
    if (_jar.isEmpty) return null;
    return _jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// Reads every Set-Cookie of a response into the jar. `dart:io` folds repeated
  /// headers into one comma-joined string, so the split has to respect the
  /// commas inside an Expires date.
  static void keepCookies(http.BaseResponse res) {
    final String? raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;

    bool changed = false;
    for (final String piece in _splitSetCookie(raw)) {
      final String pair = piece.split(';').first.trim();
      final int eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final String name = pair.substring(0, eq).trim();
      final String value = pair.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      if (value.isEmpty || value == 'deleted') {
        changed = _jar.remove(name) != null || changed;
      } else if (_jar[name] != value) {
        _jar[name] = value;
        changed = true;
      }
    }
    if (changed) unawaited(_saveJar());
  }

  static List<String> _splitSetCookie(String raw) {
    final List<String> out = <String>[];
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final String c = raw[i];
      if (c == ',') {
        // a comma starts a new cookie only when what follows looks like `name=`
        final String rest = raw.substring(i + 1);
        final RegExpMatch? m = RegExp(
          r'^\s*[A-Za-z0-9!#$%&*+\-.^_`|~]+=',
        ).firstMatch(rest);
        if (m != null) {
          out.add(buf.toString());
          buf.clear();
          continue;
        }
      }
      buf.write(c);
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  // ── requests ──────────────────────────────────────────────────────────

  static Map<String, String> _headers({bool jsonAccept = true}) {
    final Map<String, String> h = <String, String>{
      'User-Agent': userAgent,
      'Accept-Language': Platform.localeName.replaceAll('_', '-'),
      if (jsonAccept) 'Accept': 'application/json',
      'Cache-Control': 'no-store',
    };
    final String? c = cookieHeader;
    if (c != null) h['Cookie'] = c;
    return h;
  }

  /// GET that does not follow redirects, so the caller can read `Location`.
  static Future<http.StreamedResponse> raw(String path) async {
    await loadJar();
    final http.Request req = http.Request('GET', Uri.parse(_url(path)))
      ..followRedirects = false
      ..headers.addAll(_headers());
    final http.StreamedResponse res = await AppHttpClient.instance
        .send(req)
        .timeout(_timeout);
    keepCookies(res);
    return res;
  }

  /// GET that returns decoded JSON. Throws [KzSiteError] on a non-200.
  static Future<Map<String, dynamic>> getJson(String path) async {
    await loadJar();
    final http.Response res = await AppHttpClient.instance
        .get(Uri.parse(_url(path)), headers: _headers())
        .timeout(_timeout);
    keepCookies(res);

    Map<String, dynamic> body = <String, dynamic>{};
    try {
      final dynamic decoded = json.decode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // the site answers JSON even on errors; a broken body is an error too
    }

    if (res.statusCode >= 400) {
      throw KzSiteError(
        res.statusCode,
        body['error']?.toString() ?? 'HTTP ${res.statusCode}',
        body,
      );
    }
    return body;
  }

  static String _url(String pathOrUrl) =>
      pathOrUrl.startsWith('http') ? pathOrUrl : '$base$pathOrUrl';

  static String enc(String s) => Uri.encodeQueryComponent(s);
}

/// An error the site reported, with its JSON body kept for the UI.
class KzSiteError implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic> body;

  const KzSiteError(this.status, this.message, [this.body = const {}]);

  @override
  String toString() => 'KzSiteError($status): $message';
}
