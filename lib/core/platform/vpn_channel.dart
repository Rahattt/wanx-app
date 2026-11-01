import 'dart:async';

import 'package:flutter/services.dart';

import '../../features/vpn/domain/vpn_status.dart';
import 'device_identity.dart';

export 'device_identity.dart';

/// Dart side of the platform channel to the native VPN module.
///
/// Native counterparts:
///  - Android: `android/app/src/main/kotlin/com/wanx/wanx/vpn/VpnChannel.kt`
///  - iOS:     `ios/Runner/VpnChannel.swift`
///
/// Methods (on [methodChannelName]):
///  - `prepare`   → bool. Android: VpnService consent dialog. iOS: installs
///                  the NETunnelProviderManager profile (system prompt).
///  - `requestNotificationPermission` → bool. Android 13+: POST_NOTIFICATIONS
///                  (VPN status notification). iOS: always false, no
///                  prompt — the app posts no notifications there.
///  - `start`     {config: String (sing-box JSON), name: String,
///                  disconnectLabel: String? (Android notification action),
///                  checkWindowMs: int?, deadlineMessage: String?} → void.
///                  With a check window the native side ends the tunnel
///                  itself that long after it is up, unless
///                  `clearDeadline` comes first.
///  - `clearDeadline` → void (a premium link's first check passed)
///  - `stop`      → void
///  - `status`    → {status: String, error: String?}
///  - `version`   → String (libbox core version)
///  - `deviceInfo` → {hwid, os, osVersion, model} (see DeviceIdentity)
///  - `installedApps` → [{package, label, icon: PNG bytes?}], launchable
///                  apps for the per-app VPN. Android only.
///  - `testLatency` {outbound: String (one sing-box outbound JSON),
///                  url, timeoutMs, dnsServer} → int? delay in ms, null if
///                  the server failed or timed out; error UNSUPPORTED if the
///                  core can't run the outbound, UNAVAILABLE if the test
///                  could not run right now (e.g. low memory in the extension). Runs a throwaway core,
///                  independent of the active tunnel.
///
/// Events (on [eventChannelName]): {status: String, error: String?}
///
/// Traffic (on [trafficChannelName], only while the tunnel runs), once a
/// second: {uplink, downlink: bytes in the last second, uplinkTotal,
/// downlinkTotal: bytes since connect}. Read from libbox's command server.
/// An app the per-app VPN can include or bypass.
class InstalledApp {
  const InstalledApp({required this.package, required this.label, this.icon});

  final String package;
  final String label;
  final Uint8List? icon;
}

class VpnChannel {
  static const methodChannelName = 'com.wanx/vpn';
  static const eventChannelName = 'com.wanx/vpn/status';
  static const trafficChannelName = 'com.wanx/vpn/traffic';

  static const _methods = MethodChannel(methodChannelName);
  static const _events = EventChannel(eventChannelName);
  static const _traffic = EventChannel(trafficChannelName);

  Stream<TrafficStats> watchTraffic() => _traffic.receiveBroadcastStream().map(
    (e) => TrafficStats.fromMap((e as Map).cast<String, Object?>()),
  );

  Future<bool> prepare() async =>
      await _methods.invokeMethod<bool>('prepare') ?? false;

  Future<bool> requestNotificationPermission() async =>
      await _methods.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  Future<void> start({
    required String config,
    required String name,
    String? disconnectLabel,
    Duration? checkWindow,
    String? deadlineMessage,
  }) => _methods.invokeMethod<void>('start', {
    'config': config,
    'name': name,
    'disconnectLabel': ?disconnectLabel,
    'checkWindowMs': ?checkWindow?.inMilliseconds,
    'deadlineMessage': ?deadlineMessage,
  });

  Future<void> clearDeadline() => _methods.invokeMethod<void>('clearDeadline');

  Future<void> stop() => _methods.invokeMethod<void>('stop');

  Future<VpnState> status() async {
    final raw = await _methods.invokeMapMethod<String, dynamic>('status');
    return _toState(raw);
  }

  Future<String?> coreVersion() => _methods.invokeMethod<String>('version');

  Future<DeviceIdentity> deviceInfo() async => DeviceIdentity.fromMap(
    await _methods.invokeMapMethod<String, Object?>('deviceInfo') ?? const {},
  );

  Future<List<InstalledApp>> installedApps() async => [
    for (final raw
        in await _methods.invokeListMethod<Map>('installedApps') ?? const [])
      InstalledApp(
        package: raw['package'] as String,
        label: raw['label'] as String,
        icon: raw['icon'] as Uint8List?,
      ),
  ];

  static const latencyTestUrl = 'https://www.gstatic.com/generate_204';

  /// Measures delay through the real sing-box outbound [outboundJson] with
  /// sing-box's urltest. Returns milliseconds, or null on failure/timeout.
  /// Throws [LatencyTestUnsupported] when the platform or core can't run
  /// the test, so callers can fall back to another method.
  Future<int?> testServerLatency(
    String outboundJson, {
    String url = latencyTestUrl,
    Duration timeout = const Duration(seconds: 5),
    String? dnsServer,
  }) async {
    try {
      return await _methods
          .invokeMethod<int>('testLatency', {
            'outbound': outboundJson,
            'url': url,
            'timeoutMs': timeout.inMilliseconds,
            'dnsServer': ?dnsServer,
          })
          // The native side enforces [timeout] on the delay request; this
          // guards against core startup hanging.
          .timeout(timeout + const Duration(seconds: 10));
    } on MissingPluginException {
      throw LatencyTestUnsupported(
        'Latency test is not available on this platform',
      );
    } on PlatformException catch (e) {
      if (e.code == 'UNSUPPORTED') {
        throw LatencyTestUnsupported(e.message ?? 'Not supported by the core');
      }
      if (e.code == 'UNAVAILABLE') {
        throw LatencyTestUnavailable(e.message ?? 'Latency test unavailable');
      }
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Stream<VpnState> watchStatus() => _events.receiveBroadcastStream().map(
    (event) => _toState(Map<String, dynamic>.from(event as Map)),
  );

  static VpnState _toState(Map<String, dynamic>? raw) => VpnState(
    status: VpnStatus.fromWire(raw?['status'] as String?),
    error: raw?['error'] as String?,
  );
}

class LatencyTestUnsupported implements Exception {
  LatencyTestUnsupported(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The test did not run (says nothing about the server).
class LatencyTestUnavailable implements Exception {
  LatencyTestUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Tunnel throughput: per-second rates and totals since connect, in bytes.
class TrafficStats {
  const TrafficStats({
    this.uplink = 0,
    this.downlink = 0,
    this.uplinkTotal = 0,
    this.downlinkTotal = 0,
  });

  factory TrafficStats.fromMap(Map<String, Object?> m) {
    int v(String k) => (m[k] as num?)?.toInt() ?? 0;
    return TrafficStats(
      uplink: v('uplink'),
      downlink: v('downlink'),
      uplinkTotal: v('uplinkTotal'),
      downlinkTotal: v('downlinkTotal'),
    );
  }

  final int uplink;
  final int downlink;
  final int uplinkTotal;
  final int downlinkTotal;
}
