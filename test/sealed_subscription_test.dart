import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanx/core/sealed/link_key.dart';
import 'package:wanx/core/sealed/sealed_keys.dart';
import 'package:wanx/features/servers/application/servers_controller.dart';
import 'package:wanx/features/servers/data/server_repository.dart';
import 'package:wanx/features/servers/data/share_link_parser.dart';
import 'package:wanx/features/servers/data/subscription_fetcher.dart';
import 'package:wanx/features/servers/domain/server.dart';
import 'package:wanx/features/servers/domain/subscription.dart';
import 'package:wanx_sealed/wanx_sealed.dart' as sealed;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  // The release link key is not in the source.
  LinkKey.testKeys = sealed.generateDeviceKey();

  final seed = List.generate(32, (i) => i * 3 % 256);
  late _SoftKeys keys;
  late Map<String, String> trusted;

  setUp(() async {
    keys = _SoftKeys();
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    final pub = (await pair.extractPublicKey()).bytes;
    trusted = {await sealed.signingKeyId(pub): base64.encode(pub)};
  });

  Future<String> envelopeFor(
    Uint8List devicePub, {
    Duration ttl = const Duration(days: 7),
  }) async {
    final now = DateTime.now().toUtc();
    final signed = await sealed.signPayload(
      sealed.SealedPayload(
        subscriptionId: 's1',
        name: 'Acme Premium',
        provider: 'Acme',
        device: await sealed.deviceFingerprint(devicePub),
        issuedAt: now,
        expiresAt: now.add(ttl),
        body: '',
      ),
      seed,
    );
    final env = await sealed.seal(devicePub, utf8.encode(signed.encode()));
    return env.encode();
  }

  /// A local stand-in for both the WanX check endpoint (`POST /s/<token>`,
  /// answering [check]) and the provider (`GET /provider`).
  Future<(HttpServer, List<String>)> serve({
    Future<(int, String)> Function(Uint8List devicePub)? check,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <String>[];
    server.listen((req) async {
      seen.add(
        '${req.method} ${req.uri.path} '
        '${req.headers.value(HttpHeaders.hostHeader)}',
      );
      final res = req.response;
      if (req.method == 'POST') {
        final body = jsonDecode(
          await utf8.decoder.bind(req).join(),
        ) as Map<String, dynamic>;
        final answer = check ?? (pub) async => (200, await envelopeFor(pub));
        final (status, text) = await answer(
          base64.decode(body['key'] as String),
        );
        res.statusCode = status;
        res.write(text);
      } else {
        res.write('trojan://p@vpn.example.com:443#Frankfurt');
      }
      await res.close();
    });
    return (server, seen);
  }

  SubscriptionFetcher fetcher(List<String> endpoints) => SubscriptionFetcher(
    ShareLinkParser(),
    sealedKeys: keys,
    trustedKeys: trusted,
    checkEndpoints: () async => endpoints,
  );

  ProviderContainer container(
    _MemoryRepository repo,
    SubscriptionFetcher fetcher,
  ) {
    final c = ProviderContainer(
      overrides: [
        serverRepositoryProvider.overrideWithValue(repo),
        subscriptionFetcherProvider.overrideWithValue(fetcher),
        sealedKeysProvider.overrideWithValue(keys),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<String> wanxLink(String providerUrl) => sealed.encryptLink(
    sealed.PremiumLink(subscriptionUrl: providerUrl, token: 'tok'),
    LinkKey.publicKey,
  );

  // The test binding fakes HttpClient; these tests need the real one.
  Future<T> real<T>(Future<T> Function() body) =>
      HttpOverrides.runWithHttpOverrides(body, _RealHttp());

  test(
    'a wanx:// link is checked, then downloaded from the provider',
    () async {
      final (server, seen) = await serve();
      final port = server.port;
      final repo = _MemoryRepository();
      final c = container(repo, fetcher(['http://127.0.0.1:$port']));
      await c.read(serversProvider.future);
      final link = await wanxLink('http://127.0.0.1:$port/provider#Gold');
      await real(() => c.read(serversProvider.notifier).addSubscription(link));

      final state = c.read(serversProvider).value!;
      final sub = state.subscriptions.single;
      expect(sub.token, 'tok');
      expect(sub.pending, isFalse);
      expect(sub.name, 'Gold');
      expect(state.servers.single.isManaged, isTrue);
      expect(state.servers.single.group, 'Gold');
      expect(keys.secure, isTrue);
      expect(seen, [
        'POST /s/tok 127.0.0.1:$port',
        'GET /provider 127.0.0.1:$port',
      ]);

      // A restart keeps the same servers and ids (selection holds).
      final again = container(repo, fetcher(['http://127.0.0.1:$port']));
      final reopened = await again.read(serversProvider.future);
      expect(reopened.servers.single.id, state.servers.single.id);
      expect(reopened.selectedId, state.servers.single.id);
    },
  );

  test(
    'with our service unreachable, the import is pending, not refused',
    () async {
      final (server, seen) = await serve();
      // Nothing listens on port 9: the check endpoint is "blocked".
      final c = container(_MemoryRepository(), fetcher(['http://127.0.0.1:9']));
      await c.read(serversProvider.future);
      final link = await wanxLink('http://127.0.0.1:${server.port}/provider');
      await real(() => c.read(serversProvider.notifier).addSubscription(link));
      final state = c.read(serversProvider).value!;
      expect(state.subscriptions.single.pending, isTrue);
      expect(state.servers.single.isManaged, isTrue);
      expect(state.servers.single.isExpired, isFalse);
      expect(seen.single, startsWith('GET /provider'));
    },
  );

  for (final (what, status, code) in [
    ('over the limit', 403, 'device_limit'),
    ('of a lapsed plan', 402, 'plan_inactive'),
  ]) {
    test('importing a link $what is refused', () async {
      final (server, _) = await serve(
        check: (_) async => (status, '{"error":"no","code":"$code"}'),
      );
      final c = container(
        _MemoryRepository(),
        fetcher(['http://127.0.0.1:${server.port}']),
      );
      await c.read(serversProvider.future);
      final link = await wanxLink('http://127.0.0.1:${server.port}/provider');
      await expectLater(
        real(() => c.read(serversProvider.notifier).addSubscription(link)),
        throwsA(isA<ImportException>().having((e) => e.code, 'code', code)),
      );
      expect(c.read(serversProvider).value!.subscriptions, isEmpty);
    });
  }

  test('the check can go through a fronted endpoint', () async {
    final (server, seen) = await serve();
    final port = server.port;
    final result = await real(
      () =>
          fetcher([
            // The first endpoint is blocked; the second is fronted.
            'http://127.0.0.1:9',
            'http://check.blocked.invalid'
                '#?endpoint=127.0.0.1:$port&header_host=check.internal',
          ]).fetch(
            Subscription(
              id: 'sub',
              name: 'x',
              url: 'http://127.0.0.1:$port/provider',
              sealed: true,
              token: 'tok',
            ),
          ),
    );
    expect(result.sealed, isNotNull);
    expect(seen.first, 'POST /s/tok check.internal');
  });

  test('another device, an edit or an unknown signer are refused', () async {
    final other = _SoftKeys();
    await expectLater(
      fetcher(const []).openSealed(await envelopeFor(other.pub)),
      throwsA(isA<SubscriptionException>()),
    );
    final untrusted = SubscriptionFetcher(ShareLinkParser(), sealedKeys: keys);
    await expectLater(
      untrusted.openSealed(await envelopeFor(keys.pub)),
      throwsA(isA<SubscriptionException>()),
    );
  });

  Subscription checked({required String url, DateTime? checkedAt}) =>
      Subscription(
        id: 'sub',
        name: 'Acme',
        url: url,
        sealed: true,
        token: 'tok',
        checkedAt:
            checkedAt ?? DateTime.now().subtract(const Duration(days: 2)),
        expiresAt: DateTime.now().add(const Duration(days: 5)),
      );

  for (final (what, reachable, cutOff) in [
    ('a refusal ends a checked link at once', true, true),
    ('an unreachable service keeps the last check valid', false, false),
  ]) {
    test(what, () async {
      final (server, _) = await serve(
        check: (_) async => (403, '{"error":"no","code":"device_removed"}'),
      );
      final repo = _MemoryRepository()
        ..subscriptions = [
          checked(url: 'http://127.0.0.1:${server.port}/provider'),
        ]
        ..saved = [_server(DateTime.now().add(const Duration(days: 5)))];
      final c = container(
        repo,
        fetcher([
          reachable ? 'http://127.0.0.1:${server.port}' : 'http://127.0.0.1:9',
        ]),
      );
      await c.read(serversProvider.future);
      await real(() => c.read(serversProvider.notifier).refreshSubscriptions());
      final state = c.read(serversProvider).value!;
      expect(state.servers.single.isExpired, cutOff);
      expect(
        state.subscriptions.single.blocked,
        cutOff ? 'device_removed' : null,
      );
    });
  }

  test('a link refused before it ever passed loses its servers', () async {
    final (server, _) = await serve(
      check: (_) async => (403, '{"error":"no","code":"device_limit"}'),
    );
    final repo = _MemoryRepository()
      ..subscriptions = [
        Subscription(
          id: 'sub',
          name: 'Acme',
          url: 'http://127.0.0.1:${server.port}/provider',
          sealed: true,
          token: 'tok',
        ),
      ]
      ..saved = [_server(SubscriptionFetcher.noExpiry)];
    final c = container(repo, fetcher(['http://127.0.0.1:${server.port}']));
    await c.read(serversProvider.future);
    await real(() => c.read(serversProvider.notifier).refreshSubscriptions());
    final state = c.read(serversProvider).value!;
    expect(state.servers, isEmpty);
    expect(state.subscriptions.single.blocked, 'device_limit');
  });

  test(
    'a lapsed provider plan keeps the link encrypted, without fronting',
    () async {
      final (server, seen) = await serve(
        check: (_) async => (402, '{"error":"no","code":"plan_inactive"}'),
      );
      final port = server.port;
      final result = await real(
        () => fetcher(['http://127.0.0.1:$port']).fetch(
          checked(
            // The front would be unreachable: it must not be used any more.
            url:
                'http://127.0.0.1:$port/provider'
                '#G?resolve-address=10.255.255.1&host=front.invalid',
          ),
        ),
      );
      expect(result.lapsed, isTrue);
      expect(result.servers.single.isManaged, isTrue);
      expect(result.servers.single.managedUntil, SubscriptionFetcher.noExpiry);
      expect(seen, [
        'POST /s/tok 127.0.0.1:$port',
        'GET /provider 127.0.0.1:$port',
      ]);
    },
  );

  test('with our service blocked, a refresh still reaches the provider '
      'through its front', () async {
    final (server, seen) = await serve();
    final port = server.port;
    final result = await real(
      () => fetcher(['http://127.0.0.1:9']).fetch(
        checked(
          url:
              'http://drive.blocked.invalid/provider'
              '#Gold?resolve-address=127.0.0.1:$port&host=drive.blocked.invalid',
        ),
      ),
    );
    expect(result.sealed, isNull);
    expect(result.servers.single.isExpired, isFalse);
    // Dialled the front; the blocked name went only into Host.
    expect(seen, ['GET /provider drive.blocked.invalid']);
  });

  test('a provider download keeps Host only on same-host redirects', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final port = server.port;
    final seen = <String>[];
    server.listen((req) async {
      seen.add('${req.uri.path} ${req.headers.value(HttpHeaders.hostHeader)}');
      final res = req.response;
      switch (req.uri.path) {
        case '/a':
          res.redirect(Uri.parse('/b'), status: HttpStatus.found);
        case '/b':
          res.redirect(
            Uri.parse('http://localhost:$port/c'),
            status: HttpStatus.temporaryRedirect,
          );
        default:
          res.write('trojan://p@vpn.example.com:443#F');
          await res.close();
      }
    });
    await real(
      () => fetcher(['http://127.0.0.1:9']).fetch(
        checked(
          url:
              'http://api.blocked.invalid/a'
              '#Gold?endpoint=127.0.0.1:$port&header_host=panel.internal',
          checkedAt: DateTime.now(),
        ),
      ),
    );
    expect(seen, [
      '/a panel.internal',
      // A relative redirect stays behind the endpoint and keeps Host...
      '/b panel.internal',
      // ...one to another host gets that host's own name.
      '/c localhost:$port',
    ]);
  });

  for (final (what, status, passes) in [
    (
      'the guard confirms a pending link with one check, no download',
      200,
      true,
    ),
    ('the guard drops a pending link the service refuses', 403, false),
  ]) {
    test(what, () async {
      final (server, seen) = await serve(
        check: status == 200
            ? null
            : (_) async => (status, '{"error":"no","code":"device_limit"}'),
      );
      final port = server.port;
      final repo = _MemoryRepository()
        ..subscriptions = [
          Subscription(
            id: 'sub',
            name: 'Acme',
            url: 'http://127.0.0.1:$port/provider',
            sealed: true,
            token: 'tok',
          ),
        ]
        ..saved = [_server(SubscriptionFetcher.noExpiry)];
      final c = container(repo, fetcher(['http://127.0.0.1:$port']));
      await c.read(serversProvider.future);
      await real(() => c.read(serversProvider.notifier).confirmPending('sub'));
      final state = c.read(serversProvider).value!;
      expect(seen, ['POST /s/tok 127.0.0.1:$port']);
      if (passes) {
        expect(state.subscriptions.single.pending, isFalse);
        expect(
          state.servers.single.managedUntil!.isBefore(
            DateTime.now().add(const Duration(days: 8)),
          ),
          isTrue,
        );
      } else {
        expect(state.servers, isEmpty);
        expect(state.subscriptions.single.blocked, 'device_limit');
      }
    });
  }

  test('an expired premium server stays locked until refreshed', () async {
    final repo = _MemoryRepository()
      ..saved = [_server(DateTime.now().subtract(const Duration(minutes: 1)))];
    final state = await container(
      repo,
      fetcher(const []),
    ).read(serversProvider.future);
    expect(state.servers.single.isManaged, isTrue);
    expect(state.servers.single.isExpired, isTrue);
  });
}

Server _server(DateTime managedUntil) => ShareLinkParser()
    .parseMany('trojan://p@vpn.example.com:443#F', subscriptionId: 'sub')
    .servers
    .single
    .copyWith(managedUntil: managedUntil);

class _RealHttp extends HttpOverrides {}

/// Software stand-in for the Secure Enclave / Keystore key.
class _SoftKeys extends SealedKeys {
  _SoftKeys() : this._(sealed.generateDeviceKey());
  _SoftKeys._((Uint8List, Uint8List) key) : priv = key.$1, pub = key.$2;

  final Uint8List priv;
  final Uint8List pub;
  bool secure = false;

  @override
  Future<Uint8List> publicKey() async => pub;

  @override
  Future<Uint8List> open(sealed.SealedEnvelope envelope) =>
      sealed.open(envelope, privateKey: priv, publicKey: pub);

  @override
  Future<void> setSecure(bool secure) async => this.secure = secure;
}

/// In memory, through JSON like the real repository.
class _MemoryRepository implements ServerRepository {
  List<Server> saved = [];
  List<Subscription> subscriptions = [];
  String? selected;

  @override
  Future<List<Server>> loadAll() async => saved;
  @override
  Future<void> saveAll(List<Server> s) async =>
      saved = [for (final x in s) Server.fromJson(x.toJson())];
  @override
  Future<List<Subscription>> loadSubscriptions() async => subscriptions;
  @override
  Future<void> saveSubscriptions(List<Subscription> s) async =>
      subscriptions = s;
  @override
  Future<String?> loadSelectedId() async => selected;
  @override
  Future<void> saveSelectedId(String? id) async => selected = id;
}
