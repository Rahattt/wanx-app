import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/server.dart';
import '../domain/subscription.dart';

/// Persists server profiles, subscriptions and the current selection locally.
class ServerRepository {
  ServerRepository(this._prefs);

  static const _serversKey = 'servers.v1';
  static const _selectedKey = 'servers.selected';
  static const _subscriptionsKey = 'subscriptions.v1';

  final SharedPreferencesAsync _prefs;

  Future<List<Server>> loadAll() async =>
      _decodeList(await _prefs.getString(_serversKey), Server.fromJson);

  /// Sealed servers are left out: they live only in memory, re-opened from
  /// their subscription's envelope at each start.
  Future<void> saveAll(List<Server> servers) => _prefs.setString(
    _serversKey,
    jsonEncode([for (final s in servers) s.toJson()]),
  );

  Future<List<Subscription>> loadSubscriptions() async => _decodeList(
    await _prefs.getString(_subscriptionsKey),
    Subscription.fromJson,
  );

  Future<void> saveSubscriptions(List<Subscription> subs) => _prefs.setString(
    _subscriptionsKey,
    jsonEncode(subs.map((s) => s.toJson()).toList()),
  );

  Future<String?> loadSelectedId() => _prefs.getString(_selectedKey);

  Future<void> saveSelectedId(String? id) => id == null
      ? _prefs.remove(_selectedKey)
      : _prefs.setString(_selectedKey, id);

  static List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
