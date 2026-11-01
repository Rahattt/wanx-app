import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/features/servers/application/servers_controller.dart';
import 'package:wanx/features/servers/data/server_repository.dart';
import 'package:wanx/features/servers/data/share_link_parser.dart';
import 'package:wanx/features/servers/data/subscription_fetcher.dart';
import 'package:wanx/features/servers/domain/server.dart';
import 'package:wanx/features/servers/domain/server_config.dart';
import 'package:wanx/features/servers/domain/subscription.dart';

void main() {
  const sub = Subscription(
    id: 'sub-1',
    name: 'Provider',
    url: 'https://sub.example.com/x',
  );
  final fetcher = SubscriptionFetcher(ShareLinkParser());

  group('SubscriptionFetcher.parse', () {
    test('sing-box JSON: keeps proxies, skips selector/direct', () {
      final body = jsonEncode({
        'outbounds': [
          {
            'type': 'selector',
            'tag': 'select',
            'outbounds': ['a'],
          },
          {
            'type': 'trojan',
            'tag': 'a',
            'server': 'a.example.com',
            'server_port': 443,
            'password': 'p',
          },
          {'type': 'direct', 'tag': 'direct'},
        ],
      });
      final servers = fetcher.parse(body, sub);
      expect(servers.single.name, 'a');
      expect(servers.single.group, 'Provider');
      expect(servers.single.subscriptionId, 'sub-1');
    });

    test('base64 list of links', () {
      final body = base64.encode(
        utf8.encode(
          'trojan://p@a.example.com:443#a\ntrojan://p@b.example.com:443#b',
        ),
      );
      expect(fetcher.parse(body, sub).map((s) => s.name), ['a', 'b']);
    });

    test('explains unsupported formats', () {
      expect(
        () => fetcher.parse('proxies:\n  - name: a', sub),
        throwsA(
          isA<SubscriptionException>().having(
            (e) => e.message,
            'm',
            contains('Clash YAML'),
          ),
        ),
      );
      expect(
        () => fetcher.parse('{"inbounds": []}', sub),
        throwsA(
          isA<SubscriptionException>().having(
            (e) => e.message,
            'm',
            contains('"outbounds"'),
          ),
        ),
      );
    });

    test('rejects non-http URLs', () {
      expect(
        () => SubscriptionFetcher.parseExtended('ftp://x.example.com'),
        throwsA(isA<SubscriptionException>()),
      );
      expect(
        () => SubscriptionFetcher.parseExtended('not a url'),
        throwsA(isA<SubscriptionException>()),
      );
    });
  });

  test('importAuto tells subscriptions from share links', () async {
    final fake = _FakeFetcher()..body = 'trojan://p@a.example.com:443#a';
    final container = ProviderContainer(
      overrides: [
        serverRepositoryProvider.overrideWithValue(_MemoryRepository()),
        subscriptionFetcherProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(serversProvider.notifier);
    await container.read(serversProvider.future);

    await controller.importAuto('  https://sub.example.com/a \n');
    await controller.importAuto('https://sub.example.com/b');
    await controller.importAuto('trojan://p@m.example.com:443#m');

    final state = container.read(serversProvider).value!;
    expect(state.subscriptions.map((s) => s.name), [
      'sub.example.com',
      'sub.example.com 2',
    ]);
    expect(state.servers.where((s) => !s.isFromSubscription).single.name, 'm');
  });

  test('a plain list ignores the link label', () async {
    final fake = _FakeFetcher()..body = 'trojan://p@a.example.com:443#a';
    final container = ProviderContainer(
      overrides: [
        serverRepositoryProvider.overrideWithValue(_MemoryRepository()),
        subscriptionFetcherProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await container.read(serversProvider.future);

    await container
        .read(serversProvider.notifier)
        .importAuto('https://api.example.com/v1/config?id=123#Gold');

    final sub = container.read(serversProvider).value!.subscriptions.single;
    expect(sub.name, 'api.example.com');
    expect(sub.url, endsWith('#Gold'));
  });

  test('a plain list behind routing parameters is refused', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen(
      (r) => r.response
        ..write('trojan://p@a.example.com:443#a')
        ..close(),
    );

    await expectLater(
      fetcher.fetch(
        Subscription(
          id: 's',
          name: 'n',
          url:
              'http://api.blocked.invalid/a'
              '#N?endpoint=127.0.0.1:${server.port}&header_host=panel.internal',
        ),
      ),
      throwsA(
        isA<SubscriptionException>().having(
          (e) => e.message,
          'message',
          contains('premium'),
        ),
      ),
    );
  });

  test(
    'refresh replaces subscription servers, keeps manual ones and overrides',
    () async {
      final repo = _MemoryRepository();
      final fake = _FakeFetcher();
      final container = ProviderContainer(
        overrides: [
          serverRepositoryProvider.overrideWithValue(repo),
          subscriptionFetcherProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(serversProvider.notifier);
      await container.read(serversProvider.future);

      await controller.importFromText(
        'trojan://p@manual.example.com:443#manual',
      );
      fake.body =
          'trojan://p@a.example.com:443#a\ntrojan://p@b.example.com:443#b';
      await controller.addSubscription(sub.url, name: 'Provider');

      var state = container.read(serversProvider).value!;
      final a = state.servers.firstWhere((s) => s.name == 'a');
      await controller.select(a.id);
      await controller.saveServer(
        a.copyWith(obfuscation: const ObfuscationConfig(fragment: true)),
      );

      // Provider drops "b" and adds "c".
      fake.body =
          'trojan://p@a.example.com:443#a\ntrojan://p@c.example.com:443#c';
      final result = await controller.refreshSubscriptions();

      state = container.read(serversProvider).value!;
      expect(result.updated, {'Provider': 2});
      expect(state.servers.map((s) => s.name), ['manual', 'a', 'c']);
      final refreshedA = state.servers.firstWhere((s) => s.name == 'a');
      expect(refreshedA.id, a.id, reason: 'selection survives refresh');
      expect(state.selectedId, a.id);
      expect(
        refreshedA.obfuscation.fragment,
        isTrue,
        reason: 'local overrides kept',
      );

      // Fragmentation the provider adds later wins over the kept overrides.
      fake.body =
          'trojan://p@a.example.com:443?fragment=1-2,0-1,tlshello#a\n'
          'trojan://p@c.example.com:443#c';
      await controller.refreshSubscriptions();
      final fragmented = container
          .read(serversProvider)
          .value!
          .servers
          .firstWhere((s) => s.name == 'a');
      expect(fragmented.id, a.id);
      expect(fragmented.obfuscation.xrayFragment, isTrue);
      expect(fragmented.obfuscation.xrayFragmentLength, '1-2');
      expect(
        fragmented.toOutbound()['tls'].containsKey('fragment'),
        isFalse,
        reason: 'one splitter at a time',
      );

      // A failing provider keeps its old servers and reports why.
      fake.error = SubscriptionException('HTTP 503 Service Unavailable');
      final failed = await controller.refreshSubscriptions();
      expect(failed.failures, {'Provider': 'HTTP 503 Service Unavailable'});
      expect(container.read(serversProvider).value!.servers.length, 3);
    },
  );
}

class _FakeFetcher extends SubscriptionFetcher {
  _FakeFetcher() : super(ShareLinkParser());

  String body = '';
  SubscriptionException? error;

  @override
  Future<FetchResult> fetch(Subscription sub) async {
    if (error != null) throw error!;
    return FetchResult(parse(body, sub));
  }
}

class _MemoryRepository implements ServerRepository {
  List<Server> servers = [];
  List<Subscription> subscriptions = [];
  String? selected;

  @override
  Future<List<Server>> loadAll() async => servers;
  @override
  Future<void> saveAll(List<Server> s) async => servers = s;
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
