import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final serverAddressResolverProvider = Provider<ServerAddressResolver>(
  (ref) => const ServerAddressResolver(),
);

class ServerResolveException implements Exception {
  const ServerResolveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolves a server's hostname with the OS resolver and pins the outbound
/// to the IP.
///
/// Public resolvers are blocked in some networks, so sing-box must never
/// look the server up itself. The app asks the system instead: with the VPN
/// off that is the network's own DNS; with it on, the system DNS is the
/// tunnel, so the query goes through the proxy like every other one.
class ServerAddressResolver {
  const ServerAddressResolver();

  Future<List<InternetAddress>> lookup(String host) =>
      InternetAddress.lookup(host);

  /// Returns [outbound] with `server` replaced by an IP. The hostname moves
  /// to TLS SNI and HTTP Host so the server still sees it.
  Future<Map<String, dynamic>> pin(Map<String, dynamic> outbound) async {
    final host = _host(outbound);
    if (host is! String ||
        host.isEmpty ||
        InternetAddress.tryParse(host) != null) {
      return outbound;
    }
    final List<InternetAddress> addresses;
    try {
      addresses = await lookup(host).timeout(const Duration(seconds: 8));
    } on Object {
      throw ServerResolveException('Could not resolve $host');
    }
    if (addresses.isEmpty) {
      throw ServerResolveException('Could not resolve $host');
    }
    final ip =
        addresses
            .where((a) => a.type == InternetAddressType.IPv4)
            .firstOrNull ??
        addresses.first;
    return withAddress(outbound, ip.address);
  }

  /// The server's hostname: `server`, or a WireGuard endpoint's first peer.
  static Object? _host(Map<String, dynamic> outbound) {
    if (outbound['type'] != 'wireguard') return outbound['server'];
    final peer = (outbound['peers'] as List?)?.firstOrNull;
    return peer is Map ? peer['address'] : null;
  }

  static Map<String, dynamic> withAddress(
    Map<String, dynamic> outbound,
    String ip,
  ) {
    if (outbound['type'] == 'wireguard') {
      final peers = outbound['peers'] as List;
      return {
        ...outbound,
        'peers': [
          {...(peers.first as Map).cast<String, dynamic>(), 'address': ip},
          ...peers.skip(1),
        ],
      };
    }
    final host = outbound['server'] as String;
    final out = {...outbound, 'server': ip};
    if (outbound['tls'] case final Map<String, dynamic> tls
        when tls['enabled'] == true &&
            ((tls['server_name'] as String?) ?? '').isEmpty) {
      out['tls'] = {...tls, 'server_name': host};
    }
    if (outbound['transport'] case final Map<String, dynamic> t) {
      switch (t['type']) {
        case 'ws':
          final headers = Map<String, dynamic>.of(
            (t['headers'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          if (!headers.keys.any((k) => k.toLowerCase() == 'host')) {
            headers['Host'] = host;
          }
          out['transport'] = {...t, 'headers': headers};
        case 'httpupgrade' || 'xhttp'
            when ((t['host'] as String?) ?? '').isEmpty:
          out['transport'] = {...t, 'host': host};
        case 'http' when ((t['host'] as List?) ?? const []).isEmpty:
          out['transport'] = {
            ...t,
            'host': [host],
          };
      }
    }
    return out;
  }
}
