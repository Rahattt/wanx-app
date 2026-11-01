import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wanx/app.dart';
import 'package:wanx/core/platform/vpn_channel.dart';
import 'package:wanx/features/servers/application/servers_controller.dart';
import 'package:wanx/features/servers/data/server_repository.dart';
import 'package:wanx/features/servers/data/share_link_parser.dart';
import 'package:wanx/features/servers/domain/server.dart';
import 'package:wanx/features/servers/domain/subscription.dart';
import 'package:wanx/features/servers/presentation/server_details_screen.dart';
import 'package:wanx/features/servers/presentation/widgets/server_tile.dart';
import 'package:wanx/features/settings/application/settings_controller.dart';
import 'package:wanx/features/settings/domain/app_settings.dart';
import 'package:wanx/features/settings/presentation/settings_screen.dart';
import 'package:wanx/features/vpn/application/vpn_controller.dart';
import 'package:wanx/features/vpn/domain/vpn_status.dart';

/// Screenshot tour of every screen with sample data, for design review.
/// Run with scripts/screenshots.sh (light + dark); images land in
/// build/screenshots/. Uses fake storage and a fake VPN channel, so it never
/// touches real servers or the system VPN.
const _suffix = String.fromEnvironment('SHOT_SUFFIX', defaultValue: 'light');

/// Language for a localized pass (e.g. ru, zh); empty = English full tour.
const _lang = String.fromEnvironment('SHOT_LANG');

/// pumpAndSettle with a ceiling: the connected screen's traffic arrows
/// loop forever, so stop waiting once everything else has had ~2s.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (!tester.binding.hasScheduledFrame) return;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // takeScreenshot() comes back blank on iOS (Metal layer), so render the
  // widget tree ourselves; overlays (sheets, dialogs) live inside it.
  final boundaryKey = GlobalKey();
  final shots = <String, String>{};

  // Pass settle: false for looping animations (connecting waves).
  Future<void> shot(
    WidgetTester tester,
    String name, {
    bool settle = true,
  }) async {
    if (settle) {
      await _settle(tester);
    } else {
      await tester.pump(const Duration(milliseconds: 700));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    shots['${name}_$_suffix${_lang.isEmpty ? '' : '_$_lang'}'] = base64Encode(
      png!.buffer.asUint8List(),
    );
    binding.reportData = {'screenshots': shots};
  }

  Future<void> launch(
    WidgetTester tester, {
    required List<Server> servers,
    List<Subscription> subscriptions = const [],
    VpnStatus status = VpnStatus.disconnected,
    String? error,
    bool settle = true,
  }) async {
    final repo = _MemoryRepository(servers, subscriptions);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [
            serverRepositoryProvider.overrideWithValue(repo),
            settingsStoreProvider.overrideWithValue(_MemorySettings()),
            vpnChannelProvider.overrideWithValue(
              _FakeVpnChannel(VpnState(status: status, error: error)),
            ),
          ],
          child: const WanXApp(),
        ),
      ),
    );
    if (settle) {
      await _settle(tester);
    } else {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('screenshot tour', (tester) async {
    await launch(tester, servers: const []);
    await shot(tester, '01_empty');

    final (servers, subs) = _sampleData();
    await launch(tester, servers: servers, subscriptions: subs);
    await shot(tester, '02_list');

    await launch(
      tester,
      servers: servers,
      subscriptions: subs,
      status: VpnStatus.connected,
    );
    await shot(tester, '03_list_connected');

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await shot(tester, '13_settings');
    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await _settle(tester);
    // The traffic stream resumes with its next sample.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 1500)),
    );
    await _settle(tester);
    // Localized passes only check the main and settings screens: the rest
    // of the tour finds widgets by their English text.
    if (_lang.isNotEmpty) {
      binding.reportData = {'screenshots': shots};
      return;
    }

    // Real request from the simulator; give it time to come back.
    await tester.tap(find.text('18 KB/s'));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
    await shot(tester, '03d_check');

    // Scrolled into the subscription: its header stays pinned on top.
    await tester.drag(find.text('Frankfurt'), const Offset(0, -330));
    await shot(tester, '03a_list_scrolled');

    await launch(
      tester,
      servers: servers,
      subscriptions: subs,
      status: VpnStatus.connecting,
      settle: false,
    );
    await shot(tester, '03b_connecting', settle: false);

    await launch(
      tester,
      servers: servers,
      subscriptions: subs,
      status: VpnStatus.error,
      error: 'Server did not respond',
    );
    await shot(tester, '03c_error');

    await launch(
      tester,
      servers: servers,
      subscriptions: subs,
      status: VpnStatus.connected,
    );

    final helsinkiRow = find.descendant(
      of: find.byType(ServerTile),
      matching: find.text('Helsinki'),
    );

    await tester.drag(helsinkiRow, const Offset(300, 0));
    await shot(tester, '04_swipe_test');
    Future<void> closeSwipe() async {
      // Not awaited: the animation only advances while frames are pumped.
      unawaited(Slidable.of(tester.element(helsinkiRow))!.close());
      await _settle(tester);
    }

    await closeSwipe();
    await tester.drag(helsinkiRow, const Offset(-300, 0));
    await shot(tester, '05_swipe_actions');
    await closeSwipe();

    await tester.tap(find.byTooltip('Add server'));
    await shot(tester, '06_add_menu');
    await tester.tap(find.text('Scan QR code'));
    await tester.pump(const Duration(seconds: 2));
    await shot(tester, '09_qr_scanner');
    await tester.pageBack();
    await _settle(tester);

    await tester.tap(find.byTooltip('Server details').first);
    await shot(tester, '10_details');
    final detailsList = find
        .descendant(
          of: find.byType(ServerDetailsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Advanced'),
      200,
      scrollable: detailsList,
    );
    // Clear the frosted Save bar that overlays the bottom of the list.
    await tester.drag(detailsList, const Offset(0, -200));
    await _settle(tester);
    await tester.tap(find.text('Advanced'));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.text('Reality'),
      200,
      scrollable: detailsList,
    );
    await shot(tester, '11_details_advanced');
    // Everything open, scrolled to the very end: nothing may hide under
    // the Save bar.
    await tester.tap(find.text('TLS fragmentation'));
    await _settle(tester);
    await tester.drag(detailsList, const Offset(0, -300));
    await _settle(tester);
    await tester.tap(find.text('Reality'));
    await _settle(tester);
    await tester.fling(detailsList, const Offset(0, -2000), 3000);
    await shot(tester, '12_details_bottom');
    binding.reportData = {'screenshots': shots};
  });
}

(List<Server>, List<Subscription>) _sampleData() {
  final parser = ShareLinkParser();
  const sub = Subscription(
    id: 'sub-1',
    name: 'Nordic Provider',
    url: 'https://sub.example.com/x',
  );
  final manual = parser
      .parseMany(
        [
          'vless://00000000-0000-0000-0000-000000000000@hel.example.com:443?security=tls&type=ws&path=%2Fws&host=cdn.example.com&sni=www.example.com#%F0%9F%87%AB%F0%9F%87%AE%20Helsinki',
          'trojan://secret@ams.example.com:443#Fast%20%7C%20%F0%9F%87%B3%F0%9F%87%B1%20Amsterdam',
          'hy2://secret@fra.example.com:8443#Frankfurt%20%F0%9F%87%A9%F0%9F%87%AA',
        ].join('\n'),
      )
      .servers;
  final fromSub = parser
      .parseMany(
        [
          'vless://00000000-0000-0000-0000-000000000000@sto.example.com:443?security=reality&sni=www.apple.com&pbk=KEY&fp=chrome#Stockholm',
          'ss://YWVzLTI1Ni1nY206c2VjcmV0@osl.example.com:8388#Oslo',
          'tuic://00000000-0000-0000-0000-000000000000:secret@cph.example.com:443#Copenhagen',
        ].join('\n'),
        group: sub.name,
        subscriptionId: sub.id,
      )
      .servers;
  final latencies = [84, 212, null, 132, Server.latencyFailed, 480];
  final all = [...manual, ...fromSub];
  return (
    [
      for (var i = 0; i < all.length; i++)
        all[i].copyWith(latencyMs: () => latencies[i]),
    ],
    [
      sub.copyWith(
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ],
  );
}

class _FakeVpnChannel extends VpnChannel {
  _FakeVpnChannel(this._state);

  final VpnState _state;

  @override
  Future<VpnState> status() async => _state;

  @override
  Stream<VpnState> watchStatus() => Stream.value(_state);

  @override
  // Like the real stream: a sample every second.
  Stream<TrafficStats> watchTraffic() async* {
    const stats = TrafficStats(
      uplink: 18400,
      downlink: 1450000,
      uplinkTotal: 3600000,
      downlinkTotal: 148000000,
    );
    yield stats;
    yield* Stream.periodic(const Duration(seconds: 1), (_) => stats);
  }
}

class _MemoryRepository implements ServerRepository {
  _MemoryRepository(this.servers, this.subscriptions);

  List<Server> servers;
  List<Subscription> subscriptions;
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

class _MemorySettings implements SettingsStore {
  AppSettings _settings = AppSettings(
    languageCode: _lang.isEmpty ? 'en' : _lang,
    privacyAccepted: true,
  );

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}
