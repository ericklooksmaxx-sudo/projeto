import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'kz_site.dart';

/// The 24 h download pass, exactly as the site runs it.
///
/// The gate itself lives on kyzendlc.xyz: the app asks for a signed request
/// (`/api/gate?a=app-req`), opens the gate page in the browser, and the browser
/// hands a one-shot code back through `kyzen://unlock?c=<code>`, which the app
/// redeems (`/api/gate?a=app-claim`). Nothing about the gate is reimplemented
/// here — the app only carries the device cookie and the code.
class KzPass extends ChangeNotifier {
  KzPass._();

  static final KzPass instance = KzPass._();

  static const String _stateFile = 'kyzen_pass.json';

  bool _unlocked = false;
  int _untilMs = 0;
  bool _checking = false;
  bool _opening = false;
  bool _claiming = false;
  String? _lastError;
  String? _notice;
  Timer? _tick;
  bool _initialised = false;

  /// Pack the user was trying to download when the gate opened, so the
  /// download can be resumed once the pass lands.
  String? _pendingDlcId;

  bool get checking => _checking;
  bool get opening => _opening;
  bool get claiming => _claiming;
  bool get busy => _opening || _claiming;
  String? get lastError => _lastError;
  String? get notice => _notice;
  String? get pendingDlcId => _pendingDlcId;
  int get untilMs => _untilMs;

  /// True while the pass is valid. Local clock only — the server is the one
  /// that decides, and [refresh] is what asks it.
  bool get active =>
      _unlocked && _untilMs > DateTime.now().millisecondsSinceEpoch;

  Duration get remaining {
    final int ms = _untilMs - DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: ms > 0 ? ms : 0);
  }

  /// "7h 20m" / "43 min" — the wording the site's pass chip uses.
  String get remainingLabel {
    final Duration r = remaining;
    if (r.inMinutes <= 0) return '0 min';
    if (r.inHours > 0) return '${r.inHours}h ${r.inMinutes % 60}m';
    return '${r.inMinutes} min';
  }

  // ── lifecycle ─────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    await KzSite.loadJar();
    await _loadState();
    _startTicker();
    unawaited(refresh());
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_unlocked && !active) {
        _unlocked = false;
        _persist();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // ── server state ──────────────────────────────────────────────────────

  /// Asks the site whether this device holds a pass right now.
  Future<bool> refresh({bool quiet = true}) async {
    if (_checking) return active;
    _checking = true;
    notifyListeners();
    try {
      final Map<String, dynamic> me = await KzSite.getJson('/api/me');
      _unlocked = me['unlocked'] == true;
      _untilMs = _asInt(me['until']);
      final dynamic notice = me['notice'];
      _notice = notice is Map && notice['text'] is String
          ? notice['text'] as String
          : null;
      _lastError = null;
      await _persist();
    } on KzSiteError catch (e) {
      if (!quiet) _lastError = e.message;
    } catch (e) {
      if (!quiet) {
        _lastError = 'No connection. Check your internet and try again.';
      }
      debugPrint('KzPass.refresh: $e');
    } finally {
      _checking = false;
      notifyListeners();
    }
    return active;
  }

  /// Starts the gate: asks the site for a signed request, then opens the gate
  /// page in the browser. [dlcId] is remembered so the download can resume.
  Future<String?> openGate({String? dlcId}) async {
    if (_opening) return null;
    _opening = true;
    _lastError = null;
    if (dlcId != null && dlcId.isNotEmpty) _pendingDlcId = dlcId;
    notifyListeners();

    String? error;
    try {
      final bool safeId =
          dlcId != null && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(dlcId);
      final String path =
          '/api/gate?a=app-req${safeId ? '&uuid=${KzSite.enc(dlcId)}' : ''}';
      final res = await KzSite.raw(path);
      final String? location = res.headers['location'];

      if (res.statusCode >= 300 &&
          res.statusCode < 400 &&
          location != null &&
          location.startsWith('/gate?app=')) {
        final Uri url = Uri.parse('${KzSite.base}$location');
        final bool opened = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) error = 'No browser found to open the pass.';
      } else {
        final String body = await res.stream.bytesToString();
        error = _errorFrom(body) ??
            'Could not start the pass. Try again in a moment.';
      }
    } catch (e) {
      debugPrint('KzPass.openGate: $e');
      error = 'No connection. Check your internet and try again.';
    } finally {
      _opening = false;
      _lastError = error;
      notifyListeners();
    }
    return error;
  }

  /// Redeems the code the browser handed back through `kyzen://unlock?c=...`.
  /// Returns null on success, or the message to show.
  Future<String?> claim(String code) async {
    if (code.isEmpty || !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(code)) {
      _lastError = 'Invalid unlock link.';
      notifyListeners();
      return _lastError;
    }
    if (_claiming) return null;
    _claiming = true;
    _lastError = null;
    notifyListeners();

    String? error;
    try {
      final Map<String, dynamic> j = await KzSite.getJson(
        '/api/gate?a=app-claim&c=${KzSite.enc(code)}',
      );
      if (j['ok'] == true) {
        _unlocked = true;
        final String redirect = j['redirect']?.toString() ?? '/';
        final String? id = _idFromRedirect(redirect);
        if (id != null) _pendingDlcId = id;
        await _persist();
        // the cookie is what actually unlocks: read the real window back
        await refresh();
      } else {
        error = j['error']?.toString() ?? 'Could not unlock. Try again.';
      }
    } on KzSiteError catch (e) {
      error = e.message;
    } catch (e) {
      debugPrint('KzPass.claim: $e');
      error = 'No connection. Open the unlock link again.';
    } finally {
      _claiming = false;
      _lastError = error;
      notifyListeners();
    }
    return error;
  }

  /// Hands the pending pack to the caller once, after an unlock.
  String? takePendingDlcId() {
    final String? id = _pendingDlcId;
    _pendingDlcId = null;
    return id;
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Forgets the pass and the device cookie (Settings → reset).
  Future<void> reset() async {
    _unlocked = false;
    _untilMs = 0;
    _pendingDlcId = null;
    await KzSite.clearJar();
    await _persist();
    notifyListeners();
  }

  // ── disk ──────────────────────────────────────────────────────────────

  Future<void> _loadState() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File f = File('${dir.path}/$_stateFile');
      if (!await f.exists()) return;
      final dynamic data = json.decode(await f.readAsString());
      if (data is Map) {
        _unlocked = data['unlocked'] == true;
        _untilMs = _asInt(data['until']);
      }
    } catch (e) {
      debugPrint('KzPass: could not read the saved pass: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File f = File('${dir.path}/$_stateFile');
      await f.writeAsString(
        json.encode(<String, dynamic>{
          'unlocked': _unlocked,
          'until': _untilMs,
        }),
        flush: true,
      );
    } catch (e) {
      debugPrint('KzPass: could not write the saved pass: $e');
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String? _errorFrom(String body) {
    try {
      final dynamic j = json.decode(body);
      if (j is Map && j['error'] is String) return j['error'] as String;
    } catch (_) {}
    return null;
  }

  /// `/?id=<uuid>&dl=1` -> the uuid.
  static String? _idFromRedirect(String redirect) {
    try {
      final Uri u = Uri.parse(redirect.startsWith('/')
          ? '${KzSite.base}$redirect'
          : redirect);
      if (u.queryParameters['dl'] != '1') return null;
      final String? id = u.queryParameters['id'];
      if (id == null) return null;
      return RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id) ? id : null;
    } catch (_) {
      return null;
    }
  }
}
