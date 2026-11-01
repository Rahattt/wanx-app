import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import 'package:wanx/core/platform/vpn_channel.dart';
import 'package:wanx/core/singbox/server_address_resolver.dart';
import 'package:wanx/features/servers/application/servers_controller.dart';
import 'package:wanx/features/servers/data/latency_tester.dart';
import 'package:wanx/features/servers/data/server_repository.dart';
import 'package:wanx/features/servers/domain/server.dart';
import 'package:wanx/features/servers/domain/subscription.dart';
import 'package:wanx/features/vpn/application/vpn_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(VpnChannel.methodChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(Future<Object?>? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('VpnChannel.testServerLatency', () {
    test('sends the outbound and options, returns the delay', () async {
      MethodCall? received;
      mock((call) async {
        received = call;
        return 123;
      });
      final ms = await VpnChannel().testServerLatency(
        '{"type":"hysteria2"}',
        timeout: const Duration(seconds: 5),
        dnsServer: '1.1.1.1',
      );
      expect(ms, 123);
      expect(received!.method, 'testLatency');
      expect(received!.arguments, {
        'outbound': '{"type":"hysteria2"}',
        'url': VpnChannel.latencyTestUrl,
        'timeoutMs': 5000,
        'dnsServer': '1.1.1.1',
      });
    });

    test('returns null when the server fails or times out', () async {
      mock((_) async => null);
      expect(await VpnChannel().testServerLatency('{}'), isNull);
    });

    test('returns null on other platform errors', () async {
      mock((_) async => throw PlatformException(code: 'BAD_ARGS'));
      expect(await VpnChannel().testServerLatency('{}'), isNull);
    });

    test(
      'throws LatencyTestUnsupported for UNSUPPORTED and missing plugin',
      () async {
        mock(
          (_) async => throw PlatformException(
            code: 'UNSUPPORTED',
            message: 'unknown outbound type',
          ),
        );
        await expectLater(
          VpnChannel().testServerLatency('{}'),
          throwsA(
            isA<LatencyTestUnsupported>().having(
              (e) => e.message,
              'message',
              'unknown outbound type',
            ),
          ),
        );
        mock((_) async => throw MissingPluginException());
        await expectLater(
          VpnChannel().testServerLatency('{}'),
          throwsA(isA<LatencyTestUnsupported>()),
        );
      },
    );

    test('throws LatencyTestUnavailable when the test could not run', () async {
      mock(
        (_) async =>
            throw PlatformException(code: 'UNAVAILABLE', message: 'low memory'),
      );
      await expectLater(
        VpnChannel().testServerLatency('{}'),
        throwsA(isA<LatencyTestUnavailable>()),
      );
    });

    test('parallel calls are independent', () async {
      mock((call) async {
        final type = jsonDecode(call.arguments['outbound'] as String)['type'];
        // The slower test must not hold up the faster one.
        await Future<void>.delayed(
          Duration(milliseconds: type == 'slow' ? 50 : 1),
        );
        return type == 'slow' ? 400 : 40;
      });
      final order = <int?>[];
      await Future.wait([
        VpnChannel().testServerLatency('{"type":"slow"}').then(order.add),
        VpnChannel().testServerLatency('{"type":"fast"}').then(order.add),
      ]);
      expect(order, [40, 400]);
    });
  });

  group('ServersController.testLatency', () {
    late ProviderContainer container;
    late _FakeTester fallback;
    late int? platformResult;
    late bool platformUnsupported;

    setUp(() async {
      fallback = _FakeTester();
      platformResult = 90;
      platformUnsupported = false;
      mock((_) async {
        if (platformUnsupported) throw PlatformException(code: 'UNSUPPORTED');
        return platformResult;
      });
      container = ProviderContainer(
        overrides: [
          serverRepositoryProvider.overrideWithValue(_MemoryRepository()),
          latencyTesterProvider.overrideWithValue(fallback),
          vpnChannelProvider.overrideWithValue(VpnChannel()),
          serverAddressResolverProvider.overrideWithValue(_FakeResolver()),
        ],
      );
      await container.read(serversProvider.future);
      await container
          .read(serversProvider.notifier)
          .importFromText(
            'hy2://pw@h.example.com:8443#hy\ntrojan://p@t.example.com:443#tr',
          );
    });

    tearDown(() => container.dispose());

    Server byName(String name) => container
        .read(serversProvider)
        .value!
        .servers
        .firstWhere((s) => s.name == name);

    test('uses the platform urltest for UDP protocols too', () async {
      final ms = await container
          .read(serversProvider.notifier)
          .testLatency(byName('hy').id);
      expect(ms, 90);
      expect(byName('hy').latencyMs, 90);
      expect(fallback.calls, 0);
    });

    test(
      'marks the server failed when the platform test returns null',
      () async {
        platformResult = null;
        final ms = await container
            .read(serversProvider.notifier)
            .testLatency(byName('tr').id);
        expect(ms, isNull);
        expect(byName('tr').latencyMs, Server.latencyFailed);
      },
    );

    test('falls back to the Dart handshake only when unsupported', () async {
      platformUnsupported = true;
      final ms = await container
          .read(serversProvider.notifier)
          .testLatency(byName('tr').id);
      expect(ms, 55);
      expect(fallback.calls, 1);
    });
  });
}

class _FakeTester extends LatencyTester {
  int calls = 0;

  @override
  Future<int> test(Server server) async {
    calls++;
    return 55;
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

class _FakeResolver extends ServerAddressResolver {
  @override
  Future<List<InternetAddress>> lookup(String host) async => [
    InternetAddress('203.0.113.7'),
  ];
}
