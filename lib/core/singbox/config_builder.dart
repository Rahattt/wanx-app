import 'dart:convert';

import '../../features/servers/domain/server.dart';
import '../../features/settings/domain/app_settings.dart';

/// Builds a complete sing-box configuration (1.12+ schema) around one outbound.
///
/// The TUN inbound is what libbox hands to the platform: on Android it calls
/// `PlatformInterface.openTun` (backed by VpnService.Builder), on iOS it uses
/// the NEPacketTunnelProvider file descriptor.
class SingBoxConfigBuilder {
  const SingBoxConfigBuilder({
    this.logLevel = 'info',
    this.remoteDns = 'https://1.1.1.1/dns-query',
    this.ipMode = IpMode.ipv4,
    this.bypassLan = true,
    this.splitMode = SplitTunnelMode.off,
    this.splitApps = const [],
  });

  final String logLevel;

  /// Every DNS query from the device, sent through the proxy.
  final String remoteDns;

  /// IPv4 only: no v6 TUN address, DNS answers IPv4 only. The other modes
  /// give the TUN both addresses and differ in the DNS strategy.
  final IpMode ipMode;

  /// Private/LAN destinations go direct instead of through the proxy.
  final bool bypassLan;

  /// Android per-app VPN, applied by the platform's VpnService.Builder.
  /// An empty [splitApps] list means every app.
  final SplitTunnelMode splitMode;
  final List<String> splitApps;

  static const proxyTag = 'proxy';

  /// [outbound] overrides `server.toOutbound()`, e.g. with the address
  /// already resolved by [ServerAddressResolver].
  Map<String, dynamic> build(Server server, {Map<String, dynamic>? outbound}) {
    final proxy = {...(outbound ?? server.toOutbound()), 'tag': proxyTag};
    final remote = Uri.parse(remoteDns);
    final v6 = ipMode != IpMode.ipv4;
    return {
      'log': {'level': logLevel, 'timestamp': true},
      'dns': {
        'servers': [
          {
            'tag': 'remote',
            'type': remote.scheme == 'https' ? 'https' : 'udp',
            'server': remote.host.isNotEmpty ? remote.host : remoteDns,
            'detour': proxyTag,
          },
          // System resolver, only for names that must bypass the proxy.
          // Public resolvers can't be relied on (blocked in some networks).
          {'tag': 'local', 'type': 'local'},
        ],
        'final': 'remote',
        'strategy': switch (ipMode) {
          IpMode.ipv4 => 'ipv4_only',
          IpMode.dual => 'prefer_ipv4',
          IpMode.ipv6 => 'ipv6_only',
        },
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'address': ['172.19.0.1/30', if (v6) 'fdfe:dcba:9876::1/126'],
          'mtu': 9000,
          'auto_route': true,
          'strict_route': true,
          'stack': 'mixed',
          if (splitApps.isNotEmpty)
            if (splitMode == SplitTunnelMode.only)
              'include_package': splitApps
            else if (splitMode == SplitTunnelMode.bypass)
              'exclude_package': splitApps,
        },
      ],
      // WireGuard is an endpoint; route and DNS reach it by tag the same way.
      if (server.protocol.isEndpoint) 'endpoints': [proxy],
      'outbounds': [
        if (!server.protocol.isEndpoint) proxy,
        {'type': 'direct', 'tag': 'direct'},
      ],
      'route': {
        'rules': [
          {'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
          // QUIC relayed over a TCP transport (WebSocket, gRPC, …) stalls on
          // any loss: apps like TikTok stutter. Rejecting it makes them fall
          // back to TLS over TCP at once. QUIC-native servers carry it fine.
          if (!server.protocol.isUdpBased)
            {'protocol': 'quic', 'action': 'reject'},
          if (bypassLan) {'ip_is_private': true, 'outbound': 'direct'},
        ],
        'final': proxyTag,
        'auto_detect_interface': true,
        // Resolves the proxy server's own hostname without going through it.
        'default_domain_resolver': 'local',
      },
    };
  }

  String buildJson(Server server, {Map<String, dynamic>? outbound}) =>
      jsonEncode(build(server, outbound: outbound));
}
