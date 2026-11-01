import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/app_foreground.dart';
import '../../../core/platform/vpn_channel.dart';
import '../../../core/singbox/config_builder.dart';
import '../../../core/singbox/server_address_resolver.dart';
import '../../servers/application/premium_guard.dart';
import '../../servers/application/servers_controller.dart';
import '../../servers/domain/server.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/vpn_status.dart';

final vpnChannelProvider = Provider<VpnChannel>((ref) => VpnChannel());

final deviceIdentityProvider = FutureProvider<DeviceIdentity>(
  (ref) => ref.read(vpnChannelProvider).deviceInfo(),
);

/// Follows Settings; a change applies on the next connect.
final configBuilderProvider = Provider<SingBoxConfigBuilder>((ref) {
  final settings = ref.watch(settingsProvider).value ?? const AppSettings();
  return SingBoxConfigBuilder(
    remoteDns: settings.dns.url,
    ipMode: settings.ipMode,
    bypassLan: settings.bypassLan,
    // Per-app VPN exists only on Android.
    splitMode: Platform.isAndroid ? settings.splitMode : SplitTunnelMode.off,
    // WanX itself stays in the tunnel: premium checks go through it where
    // our service is blocked.
    splitApps: switch (settings.splitMode) {
      SplitTunnelMode.only => {...settings.splitApps, ownPackage}.toList(),
      SplitTunnelMode.bypass => [
        for (final p in settings.splitApps)
          if (p != ownPackage) p,
      ],
      SplitTunnelMode.off => settings.splitApps,
    },
  );
});

/// Live traffic; subscribed only while the tunnel is connected and the app
/// is on screen, so a backgrounded app isn't woken every second.
final trafficProvider = StreamProvider.autoDispose<TrafficStats>((ref) {
  final connected = ref.watch(
    vpnProvider.select((s) => s.status == VpnStatus.connected),
  );
  if (!connected || !ref.watch(appForegroundProvider)) {
    return const Stream.empty();
  }
  return ref.watch(vpnChannelProvider).watchTraffic();
});

/// Android application id, kept in the tunnel by the per-app VPN.
const ownPackage = 'com.wanx.wanx';

final vpnProvider = NotifierProvider<VpnController, VpnState>(
  VpnController.new,
);

class VpnController extends Notifier<VpnState> {
  VpnChannel get _channel => ref.read(vpnChannelProvider);

  /// Why the app itself ended the connection, shown once it is down.
  String? _stopReason;

  @override
  VpnState build() {
    final sub = _channel.watchStatus().listen(
      (s) {
        final reason = _stopReason;
        if (reason != null && s.status == VpnStatus.disconnected) {
          _stopReason = null;
          state = VpnState(error: reason);
        } else {
          state = s;
        }
      },
      onError: (Object e) =>
          state = VpnState(status: VpnStatus.error, error: '$e'),
    );
    ref.onDispose(sub.cancel);
    unawaited(_channel.status().then((s) => state = s, onError: (_) {}));
    return const VpnState();
  }

  Future<void> connect(Server server) async {
    if (server.isExpired) {
      final blocked = ref
          .read(serversProvider)
          .value
          ?.subscriptions
          .where((s) => s.id == server.subscriptionId)
          .firstOrNull
          ?.blocked;
      final l10n = appL10n(ref);
      state = VpnState(
        error: blocked == null
            ? l10n.premiumCheckOverdue
            : premiumRefusal(l10n, blocked),
      );
      return;
    }
    final premium = ref
        .read(serversProvider)
        .value
        ?.subscriptions
        .where((s) => s.id == server.subscriptionId)
        .firstOrNull;
    if (premium != null &&
        premium.pending &&
        !await ref.read(premiumGuardProvider).mayConnect(premium.id)) {
      state = VpnState(error: appL10n(ref).premiumCheckLimit);
      return;
    }
    state = const VpnState(status: VpnStatus.connecting);
    try {
      if (!await _channel.prepare()) {
        state = const VpnState(error: 'VPN permission denied');
        return;
      }
      // Android only, for the VPN status notification; asked once at first
      // connect. The tunnel works without it, so a refusal is not an error.
      if (Platform.isAndroid) {
        try {
          await _channel.requestNotificationPermission();
        } on PlatformException {
          // Dialog could not be shown (no activity / already open); skip.
        }
      }
      // Resolved now, while the VPN is still off: system DNS, not a public
      // resolver. Once up, all DNS goes through the tunnel.
      final outbound = await ref
          .read(serverAddressResolverProvider)
          .pin(server.toOutbound());
      final config = ref
          .read(configBuilderProvider)
          .buildJson(server, outbound: outbound);
      final l10n = appL10n(ref);
      await _channel.start(
        config: config,
        name: server.name,
        disconnectLabel: l10n.disconnect,
        // A link never checked runs only for the guard's window once up;
        // the VPN service ends it then itself unless the guard clears it.
        checkWindow: premium != null && premium.pending
            ? PremiumGuard.window
            : null,
        deadlineMessage: l10n.premiumCheckTimeout,
      );
    } on PlatformException catch (e) {
      state = VpnState(status: VpnStatus.error, error: e.message ?? e.code);
    } on ServerResolveException catch (e) {
      state = VpnState(status: VpnStatus.error, error: e.message);
    }
  }

  var _reconnects = 0;

  /// Switches a running tunnel to [server], like other clients do when the
  /// selection changes. Does nothing while disconnected. Rapid calls
  /// collapse: only the latest server is connected.
  Future<void> reconnect(Server server) async {
    if (state.status != VpnStatus.connected &&
        state.status != VpnStatus.connecting) {
      return;
    }
    final generation = ++_reconnects;
    await disconnect();
    // Wait for the old tunnel to go down before starting the new one.
    for (var i = 0; i < 100 && state.status != VpnStatus.disconnected; i++) {
      if (state.status == VpnStatus.error) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (generation != _reconnects) return;
    await connect(server);
  }

  /// Disconnects and then shows [reason] (e.g. a premium check failed).
  Future<void> stopWith(String reason) async {
    _stopReason = reason;
    await disconnect();
  }

  Future<void> disconnect() async {
    try {
      await _channel.stop();
    } on PlatformException catch (e) {
      state = VpnState(status: VpnStatus.error, error: e.message ?? e.code);
    }
  }

  Future<void> toggle(Server? server) async {
    switch (state.status) {
      case VpnStatus.connected || VpnStatus.connecting:
        await disconnect();
      case VpnStatus.disconnected || VpnStatus.error when server != null:
        await connect(server);
      default:
        break;
    }
  }
}
