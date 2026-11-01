import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanx_sealed/wanx_sealed.dart';

import 'publisher_keys.dart';

/// Where the app checks premium links (`POST <endpoint>/s/<token>`).
///
/// Starts from [builtIn] and follows a list signed by the publisher key,
/// fetched once a day from any of [sources] — our site, Cloud Run behind
/// Google, GitHub Pages — so endpoints can move without an app update or
/// new links. The newest signed list wins; a forged one is ignored.
class CheckEndpoints {
  CheckEndpoints(this._prefs);

  final SharedPreferencesAsync _prefs;

  /// Our server, then our Cloud Run bridge (`bridge/`) behind google.com or
  /// gmail.com for where the server is blocked. The bridge's cloud.run name
  /// stays the same when it moves to another Google account.
  static const builtIn = [
    'https://wanx.dev',
    'https://wanxdev.cloud.run#?endpoint=www.google.com',
    'https://wanxdev.cloud.run#?endpoint=gmail.com',
  ];

  /// Copies of the signed list. Fronting hints work here too.
  static const sources = [
    'https://wanx.dev/endpoints',
    'https://wanxdev.cloud.run/endpoints#?endpoint=www.google.com',
    'https://wanxdev.cloud.run/endpoints#?endpoint=gmail.com',
  ];

  static const _listKey = 'check_endpoints';
  static const _fetchedKey = 'check_endpoints_fetched';
  static const refreshEvery = Duration(hours: 24);

  /// The signed list's endpoints first, then the built-in ones.
  Future<List<String>> current() async {
    final list = await _stored();
    return {...?list?.endpoints, ...builtIn}.toList();
  }

  /// Fetches the list from [sources] if a day has passed, keeping the
  /// newest validly signed copy. [get] downloads a URL (with fronting).
  Future<void> refresh(Future<String> Function(String url) get) async {
    final fetched = DateTime.tryParse(
      await _prefs.getString(_fetchedKey) ?? '',
    );
    if (fetched != null && DateTime.now().difference(fetched) < refreshEvery) {
      return;
    }
    var best = await _stored();
    String? bestText;
    var reached = false;
    for (final source in sources) {
      try {
        final text = await get(source);
        reached = true;
        final list = await verifyEndpoints(text, trustedKeys: _trusted);
        if (best == null || list.issuedAt.isAfter(best.issuedAt)) {
          best = list;
          bestText = text;
        }
      } on Object {
        // Blocked, down or forged: try the next copy.
      }
    }
    if (bestText != null) await _prefs.setString(_listKey, bestText);
    if (reached) {
      await _prefs.setString(_fetchedKey, DateTime.now().toIso8601String());
    }
  }

  Future<EndpointList?> _stored() async {
    final text = await _prefs.getString(_listKey);
    if (text == null) return null;
    try {
      return await verifyEndpoints(text, trustedKeys: _trusted);
    } on SealedException {
      return null;
    }
  }

  static final _trusted = {
    for (final MapEntry(:key, :value) in publisherKeys.entries)
      key: base64.decode(value),
  };
}
