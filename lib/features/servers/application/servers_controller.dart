import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanx_sealed/wanx_sealed.dart'
    show PremiumLink, SealedException, decryptLink, isEncryptedLink;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/platform/vpn_channel.dart';
import '../../../core/sealed/check_endpoints.dart';
import '../../../core/sealed/link_key.dart';
import '../../../core/sealed/sealed_keys.dart';
import '../../../core/singbox/server_address_resolver.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/application/settings_controller.dart';
import '../../vpn/application/vpn_controller.dart';
import '../data/latency_tester.dart';
import '../data/server_repository.dart';
import '../data/share_link_parser.dart';
import '../data/subscription_fetcher.dart';
import '../domain/server.dart';
import '../domain/subscription.dart';
import '../domain/subscription_url.dart';

final serverRepositoryProvider = Provider<ServerRepository>(
  (ref) => ServerRepository(SharedPreferencesAsync()),
);

final shareLinkParserProvider = Provider<ShareLinkParser>(
  (ref) => ShareLinkParser(),
);

final sealedKeysProvider = Provider<SealedKeys>((ref) => SealedKeys());

final checkEndpointsProvider = Provider<CheckEndpoints>(
  (ref) => CheckEndpoints(SharedPreferencesAsync()),
);

final subscriptionFetcherProvider = Provider<SubscriptionFetcher>(
  (ref) => SubscriptionFetcher(
    ref.read(shareLinkParserProvider),
    sealedKeys: ref.read(sealedKeysProvider),
    checkEndpoints: () => ref.read(checkEndpointsProvider).current(),
    extraHeaders: () async {
      final settings = await ref.read(settingsProvider.future);
      if (!settings.sendHwid) return const {};
      try {
        return (await ref.read(deviceIdentityProvider.future)).headers;
      } on Object {
        // Never block a subscription update on device info.
        return const {};
      }
    },
  ),
);

final latencyTesterProvider = Provider<LatencyTester>((ref) => LatencyTester());

class ServersState {
  const ServersState({
    this.servers = const [],
    this.subscriptions = const [],
    this.selectedId,
  });

  final List<Server> servers;
  final List<Subscription> subscriptions;
  final String? selectedId;

  Server? get selected => byId(selectedId);

  Server? byId(String? id) {
    for (final s in servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  ServersState copyWith({
    List<Server>? servers,
    List<Subscription>? subscriptions,
    String? Function()? selectedId,
  }) => ServersState(
    servers: servers ?? this.servers,
    subscriptions: subscriptions ?? this.subscriptions,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
  );
}

/// Import failures the UI words itself; [other] carries a technical
/// reason (parser/fetch) in [ImportException.message].
enum ImportFailure { duplicateSubscription, duplicateGroup, other }

/// What the user is told when the WanX service turns a premium link down.
String premiumRefusal(AppLocalizations l10n, String code) => switch (code) {
  'device_removed' => l10n.premiumDeviceRemoved,
  'revoked' => l10n.premiumRevoked,
  'unknown_link' => l10n.premiumUnknown,
  'device_limit' => l10n.premiumDeviceLimit,
  'plan_inactive' => l10n.premiumPlanInactive,
  _ => l10n.premiumCheckOverdue,
};

class ImportException implements Exception {
  ImportException(
    this.message, {
    this.kind = ImportFailure.other,
    this.name,
    this.refused = false,
    this.code,
  });

  final String message;
  final ImportFailure kind;

  /// See [SubscriptionException.refused] and [SubscriptionException.code].
  final bool refused;
  final String? code;

  /// The group name for [ImportFailure.duplicateGroup].
  final String? name;

  @override
  String toString() => message;
}

/// Outcome of refreshing every subscription.
class RefreshResult {
  const RefreshResult(this.updated, this.failures);

  /// Subscription name → number of servers now in it.
  final Map<String, int> updated;

  /// Subscription name → why it failed (its old servers are kept).
  final Map<String, String> failures;
}

final serversProvider = AsyncNotifierProvider<ServersController, ServersState>(
  ServersController.new,
);

class ServersController extends AsyncNotifier<ServersState> {
  ServerRepository get _repo => ref.read(serverRepositoryProvider);
  ServersState get _current => state.value ?? const ServersState();

  @override
  Future<ServersState> build() async {
    final subscriptions = await _repo.loadSubscriptions();
    final servers = await _repo.loadAll();
    final selectedId = await _repo.loadSelectedId();
    _syncSecure(subscriptions);
    return ServersState(
      servers: servers,
      subscriptions: subscriptions,
      selectedId: servers.any((s) => s.id == selectedId)
          ? selectedId
          : servers.firstOrNull?.id,
    );
  }

  /// Imports share links or a base64 list as manual servers. Returns how
  /// many were added; throws [ImportException] with the reason if none.
  Future<int> importFromText(String text) async {
    final result = ref.read(shareLinkParserProvider).parseMany(text);
    if (result.servers.isEmpty) throw ImportException(result.failureSummary);
    await _commit(
      _current.copyWith(
        servers: [..._current.servers, ...result.servers],
        selectedId: () => _current.selectedId ?? result.servers.first.id,
      ),
    );
    return result.servers.length;
  }

  /// Recognises what [text] is, like Happ: a single http(s) or encrypted
  /// `wanx://` URL is a subscription; anything else is parsed as share
  /// links (plain or base64).
  Future<int> importAuto(String text) {
    final t = text.trim();
    if (isEncryptedLink(t) ||
        RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(t)) {
      return addSubscription(t);
    }
    return importFromText(t);
  }

  /// Downloads a subscription and adds its servers as a new group. An
  /// encrypted `wanx://` link becomes a premium subscription: its servers
  /// come from the provider inside it, and its token is checked with WanX
  /// now if reachable, else through the tunnel once connected.
  Future<int> addSubscription(String url, {String? name}) async {
    final premium = await _openLink(url);
    final parsed = _validUrl(premium?.subscriptionUrl ?? url);
    final storedUrl = parsed.originalUrl.toString();
    if (_current.subscriptions.any(
      (s) => premium != null ? s.token == premium.token : s.url == storedUrl,
    )) {
      throw ImportException(
        'This subscription is already added',
        kind: ImportFailure.duplicateSubscription,
      );
    }
    final named = name?.trim().isNotEmpty ?? false;
    final baseName = named ? name!.trim() : parsed.originalUrl.host;
    var groupName = baseName;
    // Several subscriptions from one provider: "name", "name 2", …
    for (var n = 2; !named && _hasGroup(groupName); n++) {
      groupName = '$baseName $n';
    }
    if (_hasGroup(groupName)) {
      throw ImportException(
        'A group named "$groupName" already exists',
        kind: ImportFailure.duplicateGroup,
        name: groupName,
      );
    }
    final sub = Subscription(
      id: const Uuid().v4(),
      name: groupName,
      url: storedUrl,
      updatedAt: DateTime.now(),
      sealed: premium != null,
      token: premium?.token,
    );
    var (fetchedSub, servers, copy) = await _fetch(sub);
    // A premium list is named by the link's `#` label (the tariff), else by
    // the provider, unless the user named it. Plain lists ignore the label.
    final premiumName = parsed.label ?? copy?.payload.name ?? '';
    if (premium != null &&
        !named &&
        premiumName.isNotEmpty &&
        !_hasGroup(premiumName)) {
      fetchedSub = fetchedSub.copyWith(name: premiumName);
      servers = [for (final s in servers) s.copyWith(group: premiumName)];
    }
    await _commit(
      _current.copyWith(
        servers: [..._current.servers, ...servers],
        subscriptions: [..._current.subscriptions, fetchedSub],
        selectedId: () => _current.selectedId ?? servers.first.id,
      ),
    );
    return servers.length;
  }

  bool _hasGroup(String name) =>
      _current.subscriptions.any((s) => s.name == name);

  /// Re-downloads every subscription. Manual servers are untouched; a
  /// subscription that fails keeps its previous servers.
  /// [onlyId] limits the refresh to one subscription.
  Future<RefreshResult> refreshSubscriptions({String? onlyId}) async {
    final updated = <String, int>{};
    final failures = <String, String>{};
    final fetched = <String, List<Server>>{};
    final refreshedSubs = <String, Subscription>{};
    final refused = <String>{};
    final blocked = <String, String?>{};
    await Future.wait(
      _current.subscriptions
          .where((sub) => onlyId == null || sub.id == onlyId)
          .map((sub) async {
            try {
              final (fresh, servers, _) = await _fetch(sub);
              fetched[sub.id] = servers;
              refreshedSubs[sub.id] = fresh;
            } on ImportException catch (e) {
              failures[sub.name] = e.message;
              // Only an explicit no from the service ends a premium link;
              // when it can't be reached the last check stays valid.
              if (sub.sealed && e.refused) refused.add(sub.id);
              blocked[sub.id] = e.code;
            }
          }),
    );

    final current = _current;
    final servers = <Server>[];
    String? selectedId = current.selectedId;
    final selectedKey = current.selected?.matchKey;
    for (final s in current.servers) {
      if (s.subscriptionId == null || !fetched.containsKey(s.subscriptionId)) {
        servers.add(s);
      }
    }
    final now = DateTime.now();
    final subscriptions = [
      for (final sub in current.subscriptions)
        if (refreshedSubs[sub.id] case final fresh?)
          fresh.copyWith(updatedAt: now)
        else if (refused.contains(sub.id))
          sub.copyWith(expiresAt: now, blocked: () => blocked[sub.id])
        else
          sub,
    ];
    // A link refused before it ever passed loses its servers; one refused
    // later keeps them locked and expired, with the reason.
    final neverPassed = {
      for (final sub in current.subscriptions)
        if (refused.contains(sub.id) && sub.pending) sub.id,
    };
    servers.removeWhere((s) => neverPassed.contains(s.subscriptionId));
    for (var i = 0; i < servers.length; i++) {
      if (refused.contains(servers[i].subscriptionId)) {
        servers[i] = servers[i].copyWith(managedUntil: now);
      }
    }
    for (final sub in current.subscriptions) {
      final fresh = fetched[sub.id];
      if (fresh == null) continue;
      final old = {
        for (final s in current.servers.where(
          (s) => s.subscriptionId == sub.id,
        ))
          s.matchKey: s,
      };
      for (final s in fresh) {
        // remove(): duplicate keys in one list must not share an id.
        final previous = old.remove(s.matchKey);
        // Keep the local id (selection) and circumvention overrides, except
        // the Xray-style fragmentation when the subscription sets it.
        final merged = previous == null
            ? s
            : s.copyWith(
                id: previous.id,
                obfuscation: s.obfuscation.xrayFragment
                    ? previous.obfuscation.withXrayFragmentOf(s.obfuscation)
                    : previous.obfuscation,
              );
        servers.add(merged);
      }
      updated[sub.name] = fresh.length;
    }
    if (!servers.any((s) => s.id == selectedId)) {
      selectedId =
          servers.where((s) => s.matchKey == selectedKey).firstOrNull?.id ??
          servers.firstOrNull?.id;
    }
    await _commit(
      ServersState(
        servers: servers,
        subscriptions: subscriptions,
        selectedId: selectedId,
      ),
    );
    return RefreshResult(updated, failures);
  }

  /// Renames a plain subscription and, when [url] changed, downloads the
  /// new list in place of the old one. Throws [ImportException] and keeps
  /// everything as it was when the name is taken or the download fails.
  /// Premium links can't be edited: their URL is never shown.
  Future<void> editSubscription(
    String subscriptionId, {
    required String name,
    required String url,
  }) async {
    final sub = _current.subscriptions
        .where((s) => s.id == subscriptionId)
        .firstOrNull;
    if (sub == null || sub.sealed) return;
    final newName = name.trim();
    if (newName.isEmpty) throw ImportException('Name is empty');
    if (newName != sub.name && _hasGroup(newName)) {
      throw ImportException(
        'A group named "$newName" already exists',
        kind: ImportFailure.duplicateGroup,
        name: newName,
      );
    }
    if (isEncryptedLink(url.trim())) {
      throw ImportException('A wanx:// link is added as a new subscription');
    }
    final storedUrl = _validUrl(url.trim()).originalUrl.toString();
    final urlChanged = storedUrl != sub.url;
    if (urlChanged &&
        _current.subscriptions.any(
          (s) => s.id != sub.id && s.url == storedUrl,
        )) {
      throw ImportException(
        'This subscription is already added',
        kind: ImportFailure.duplicateSubscription,
      );
    }
    var edited = sub.copyWith(name: newName, url: storedUrl);
    List<Server>? fresh;
    if (urlChanged) {
      final (fetched, servers, _) = await _fetch(edited);
      edited = fetched.copyWith(updatedAt: DateTime.now());
      fresh = servers;
    }
    final current = _current;
    final old = [
      for (final s in current.servers)
        if (s.subscriptionId == sub.id) s,
    ];
    final List<Server> replaced;
    if (fresh == null) {
      replaced = [for (final s in old) s.copyWith(group: newName)];
    } else {
      // Servers that are still there keep their id, so the selection holds.
      final byKey = {for (final s in old) s.matchKey: s};
      replaced = [
        for (final s in fresh)
          s.copyWith(id: byKey.remove(s.matchKey)?.id, group: newName),
      ];
    }
    final servers = [
      for (final s in current.servers)
        if (s.subscriptionId != sub.id) s,
      ...replaced,
    ];
    await _commit(
      ServersState(
        servers: servers,
        subscriptions: [
          for (final s in current.subscriptions) s.id == sub.id ? edited : s,
        ],
        selectedId: servers.any((s) => s.id == current.selectedId)
            ? current.selectedId
            : replaced.firstOrNull?.id ?? servers.firstOrNull?.id,
      ),
    );
  }

  Future<void> removeSubscription(String subscriptionId) async {
    final servers = _current.servers
        .where((s) => s.subscriptionId != subscriptionId)
        .toList();
    await _commit(
      ServersState(
        servers: servers,
        subscriptions: _current.subscriptions
            .where((s) => s.id != subscriptionId)
            .toList(),
        selectedId: servers.any((s) => s.id == _current.selectedId)
            ? _current.selectedId
            : servers.firstOrNull?.id,
      ),
    );
  }

  Future<void> select(String id) async {
    await _commit(_current.copyWith(selectedId: () => id));
  }

  /// Saves an edited profile. Only storage changes: an active tunnel keeps
  /// running, and the new config applies on the next connect.
  Future<void> saveServer(Server server) async {
    await _commit(
      _current.copyWith(
        servers: [
          for (final s in _current.servers) s.id == server.id ? server : s,
        ],
      ),
    );
  }

  /// Adds a manually entered server and selects it if none is selected.
  Future<void> addServer(Server server) async {
    await _commit(
      _current.copyWith(
        servers: [..._current.servers, server],
        selectedId: () => _current.selectedId ?? server.id,
      ),
    );
  }

  Future<void> remove(String id) async {
    final servers = _current.servers.where((s) => s.id != id).toList();
    await _commit(
      _current.copyWith(
        servers: servers,
        selectedId: () => _current.selectedId == id
            ? servers.firstOrNull?.id
            : _current.selectedId,
      ),
    );
  }

  /// Puts back a server removed by [remove] (snackbar undo).
  Future<void> restore(Server server, int index) async {
    final servers = [..._current.servers]
      ..insert(index.clamp(0, _current.servers.length), server);
    await _commit(
      _current.copyWith(
        servers: servers,
        selectedId: () => _current.selectedId ?? server.id,
      ),
    );
  }

  /// Runs a handshake test and stores the result. Returns the latency, or
  /// throws [LatencyTestException] (the server is then marked as failed).
  ///
  /// Uses sing-box's urltest through the server's real outbound (all
  /// protocols, unaffected by an active tunnel). Falls back to the Dart
  /// handshake test only if the platform reports the test as unsupported.
  /// Returns null when the server did not answer in time.
  Future<int?> testLatency(String id) async {
    final server = _current.byId(id);
    if (server == null) throw LatencyTestException('Server no longer exists');
    final Map<String, dynamic> outbound;
    try {
      // System DNS (through the tunnel when it is up), never a public one.
      outbound = await ref
          .read(serverAddressResolverProvider)
          .pin(server.toOutbound());
    } on ServerResolveException catch (e) {
      await _setLatency(id, Server.latencyFailed);
      throw LatencyTestException(e.message);
    }
    int? ms;
    try {
      ms = await ref
          .read(vpnChannelProvider)
          .testServerLatency(jsonEncode(outbound));
    } on LatencyTestUnavailable catch (e) {
      // Not the server's fault: keep the previous result.
      throw LatencyTestException(e.message);
    } on LatencyTestUnsupported {
      try {
        ms = await ref.read(latencyTesterProvider).test(server);
      } on LatencyTestException {
        if (!server.protocol.isUdpBased) {
          await _setLatency(id, Server.latencyFailed);
        }
        rethrow;
      }
    }
    await _setLatency(id, ms ?? Server.latencyFailed);
    return ms;
  }

  Future<void> _setLatency(String id, int ms) async {
    final server = _current.byId(id);
    if (server != null) await saveServer(server.copyWith(latencyMs: () => ms));
  }

  /// What an encrypted `wanx://` link holds; null for any other link. Only
  /// the decrypted provider URL is stored, and it is never shown.
  static Future<PremiumLink?> _openLink(String url) async {
    if (!isEncryptedLink(url)) return null;
    if (!LinkKey.available) {
      throw ImportException('This build cannot open wanx:// links');
    }
    try {
      return await decryptLink(
        url,
        privateKey: LinkKey.privateKey,
        publicKey: LinkKey.publicKey,
      );
    } on SealedException catch (e) {
      throw ImportException(e.message);
    }
  }

  SubscriptionUrl _validUrl(String url) {
    try {
      return SubscriptionFetcher.parseExtended(url);
    } on SubscriptionException catch (e) {
      throw ImportException(e.message);
    }
  }

  /// [sub] updated with what the fetch learned (sealed copy, expiry), its
  /// servers, and the sealed copy if it was one.
  Future<(Subscription, List<Server>, SealedCopy?)> _fetch(
    Subscription sub,
  ) async {
    try {
      final result = await ref.read(subscriptionFetcherProvider).fetch(sub);
      final sealed = result.sealed;
      if (sealed == null) {
        return (
          result.lapsed != sub.premiumLapsed
              ? sub.copyWith(premiumLapsed: result.lapsed)
              : sub,
          result.servers,
          null,
        );
      }
      return (
        sub.copyWith(
          sealed: true,
          envelope: sealed.envelope,
          expiresAt: sealed.payload.expiresAt,
          checkedAt: DateTime.now(),
          blocked: () => null,
          premiumLapsed: false,
        ),
        result.servers,
        sealed,
      );
    } on SubscriptionException catch (e) {
      final code = e.code;
      throw ImportException(
        code == null ? e.message : premiumRefusal(appL10n(ref), code),
        refused: e.refused,
        code: code,
      );
    }
  }

  /// Just the WanX check for a link not yet checked, without downloading
  /// its servers again: fast enough for the guard's few seconds. Passing
  /// lifts the lock's end to the check's; a refusal (or a lapsed plan, which
  /// takes no new devices) drops the link's servers with the reason.
  Future<void> confirmPending(String subscriptionId) async {
    final sub = _current.subscriptions
        .where((s) => s.id == subscriptionId)
        .firstOrNull;
    if (sub == null || !sub.pending) return;
    final SealedCopy copy;
    try {
      copy = await ref.read(subscriptionFetcherProvider).check(sub);
    } on SubscriptionException catch (e) {
      if (!e.refused && e.status != 402) return; // Unreachable: try again.
      final current = _current;
      await _commit(
        ServersState(
          servers: [
            for (final s in current.servers)
              if (s.subscriptionId != sub.id) s,
          ],
          subscriptions: [
            for (final s in current.subscriptions)
              s.id == sub.id
                  ? s.copyWith(
                      expiresAt: DateTime.now(),
                      blocked: () => e.code ?? 'plan_inactive',
                    )
                  : s,
          ],
          selectedId: current.selectedId,
        ),
      );
      return;
    }
    final current = _current;
    await _commit(
      ServersState(
        servers: [
          for (final s in current.servers)
            s.subscriptionId == sub.id
                ? s.copyWith(managedUntil: copy.payload.expiresAt)
                : s,
        ],
        subscriptions: [
          for (final s in current.subscriptions)
            s.id == sub.id
                ? s.copyWith(
                    envelope: copy.envelope,
                    expiresAt: copy.payload.expiresAt,
                    checkedAt: DateTime.now(),
                    blocked: () => null,
                    premiumLapsed: false,
                  )
                : s,
        ],
        selectedId: current.selectedId,
      ),
    );
  }

  /// Premium links due for their daily check (or close to expiry),
  /// regardless of "Update on launch". Also run once the VPN is up, so the
  /// check goes through the tunnel when the service is blocked.
  Future<RefreshResult?> refreshExpiringSealed({
    Duration margin = const Duration(hours: 6),
    Duration every = const Duration(hours: 24),
  }) async {
    final now = DateTime.now();
    final soon = now.add(margin);
    final stale = _current.subscriptions.where(
      (s) =>
          s.sealed &&
          (s.expiresAt == null ||
              s.expiresAt!.isBefore(soon) ||
              s.checkedAt == null ||
              now.difference(s.checkedAt!) >= every),
    );
    if (stale.isEmpty) return null;
    final updated = <String, int>{};
    final failures = <String, String>{};
    for (final sub in stale.toList()) {
      final r = await refreshSubscriptions(onlyId: sub.id);
      updated.addAll(r.updated);
      failures.addAll(r.failures);
    }
    return RefreshResult(updated, failures);
  }

  void _syncSecure(List<Subscription> subscriptions) {
    // Best effort: never fail a state change over the window flag.
    ref
        .read(sealedKeysProvider)
        .setSecure(subscriptions.any((s) => s.sealed))
        .catchError((_) {});
  }

  Future<void> _commit(ServersState next) async {
    state = AsyncData(next);
    _syncSecure(next.subscriptions);
    await _repo.saveAll(next.servers);
    await _repo.saveSubscriptions(next.subscriptions);
    await _repo.saveSelectedId(next.selectedId);
  }
}
