import 'package:uuid/uuid.dart';

import 'server.dart';
import 'server_config.dart';

class OutboundFormatException implements Exception {
  OutboundFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Maps between sing-box outbound JSON and the typed [Server] model.
/// Unmodelled fields are kept in the `extra`/`settings` maps, so a
/// fromOutbound → toOutbound round trip is lossless.
abstract final class OutboundCodec {
  static const _uuid = Uuid();
  static const _commonKeys = {
    'type',
    'tag',
    'server',
    'server_port',
    'tls',
    'transport',
  };

  static Server fromOutbound(
    Map<String, dynamic> outbound, {
    String? id,
    String? name,
    String? group,
    String? subscriptionId,
  }) {
    final type = outbound['type'] as String?;
    final protocol = ServerProtocol.fromOutboundType(type);
    if (protocol == null) {
      throw OutboundFormatException('Unsupported outbound type "$type"');
    }
    final host = outbound['server'];
    final port = outbound['server_port'];
    if (host is! String || host.isEmpty) {
      throw OutboundFormatException(
        '${protocol.label} outbound has no server address',
      );
    }
    if (port is! int || port <= 0 || port > 65535) {
      throw OutboundFormatException(
        '${protocol.label} outbound has invalid port "$port"',
      );
    }
    final tag = outbound['tag'] as String?;
    final tlsMap = _map(outbound['tls']);
    return Server(
      id: id ?? _uuid.v4(),
      name: name ?? (tag != null && tag.isNotEmpty ? tag : '$host:$port'),
      protocol: protocol,
      host: host,
      port: port,
      settings: {
        for (final e in outbound.entries)
          if (!_commonKeys.contains(e.key)) e.key: e.value,
      },
      transport: _transportFrom(_map(outbound['transport'])),
      tls: _tlsFrom(tlsMap, forceEnabled: protocol.isUdpBased),
      obfuscation: _obfuscationFrom(tlsMap),
      group: group,
      subscriptionId: subscriptionId,
    );
  }

  static Map<String, dynamic> toOutbound(Server s) {
    return {
      'type': s.protocol.outboundType,
      'server': s.host,
      'server_port': s.port,
      ...s.settings,
      if (s.protocol.supportsTls && (s.tls.enabled || s.protocol.isUdpBased))
        'tls': _tlsTo(s.tls, s.obfuscation),
      if (s.protocol.supportsTransport && s.transport.type != TransportType.tcp)
        'transport': _transportTo(s.transport),
    };
  }

  // region transport

  static TransportConfig _transportFrom(Map<String, dynamic> t) {
    if (t.isEmpty) return const TransportConfig();
    final type = TransportType.fromName(t['type'] as String?);
    final extra = Map<String, dynamic>.from(t)..remove('type');
    String path = '';
    String host = '';
    int earlyData = 0;
    switch (type) {
      case TransportType.ws:
        path = extra.remove('path') as String? ?? '';
        final headers = _map(extra.remove('headers'));
        host = headers.remove('Host')?.toString() ?? '';
        if (headers.isNotEmpty) extra['headers'] = headers;
        earlyData = extra.remove('max_early_data') as int? ?? 0;
      case TransportType.grpc:
        path = extra.remove('service_name') as String? ?? '';
      case TransportType.http:
        path = extra.remove('path') as String? ?? '';
        final hosts = extra.remove('host');
        host = hosts is List ? hosts.join(',') : (hosts?.toString() ?? '');
      case TransportType.httpupgrade:
        path = extra.remove('path') as String? ?? '';
        host = extra.remove('host') as String? ?? '';
      case TransportType.tcp:
        break;
    }
    return TransportConfig(
      type: type,
      path: path,
      host: host,
      maxEarlyData: earlyData,
      extra: extra,
    );
  }

  static Map<String, dynamic> _transportTo(TransportConfig t) {
    final out = <String, dynamic>{...t.extra, 'type': t.type.name};
    switch (t.type) {
      case TransportType.ws:
        out['path'] = t.path.isEmpty ? '/' : t.path;
        final headers = _map(t.extra['headers']);
        if (t.host.isNotEmpty) headers['Host'] = t.host;
        if (headers.isNotEmpty) out['headers'] = headers;
        if (t.maxEarlyData > 0) {
          out['max_early_data'] = t.maxEarlyData;
          out['early_data_header_name'] ??= 'Sec-WebSocket-Protocol';
        }
      case TransportType.grpc:
        out['service_name'] = t.path;
      case TransportType.http:
        out['path'] = t.path.isEmpty ? '/' : t.path;
        if (t.host.isNotEmpty) out['host'] = t.host.split(',');
      case TransportType.httpupgrade:
        out['path'] = t.path.isEmpty ? '/' : t.path;
        if (t.host.isNotEmpty) out['host'] = t.host;
      case TransportType.tcp:
        break;
    }
    return out;
  }

  // endregion

  // region tls

  static const _obfuscationTlsKeys = {
    'utls',
    'fragment',
    'record_fragment',
    'fragment_fallback_delay',
    'reality',
  };

  static TlsConfig _tlsFrom(
    Map<String, dynamic> t, {
    required bool forceEnabled,
  }) {
    final alpn = t['alpn'];
    return TlsConfig(
      enabled: forceEnabled || (t['enabled'] as bool? ?? false),
      sni: t['server_name'] as String? ?? '',
      alpn: alpn is List
          ? alpn.map((e) => '$e').toList()
          : (alpn is String ? [alpn] : const []),
      insecure: t['insecure'] as bool? ?? false,
      extra: {
        for (final e in t.entries)
          if (!{
            'enabled',
            'server_name',
            'alpn',
            'insecure',
            ..._obfuscationTlsKeys,
          }.contains(e.key))
            e.key: e.value,
      },
    );
  }

  static ObfuscationConfig _obfuscationFrom(Map<String, dynamic> t) {
    final utls = _map(t['utls']);
    final reality = _map(t['reality']);
    return ObfuscationConfig(
      fingerprint: utls['enabled'] == true
          ? UtlsFingerprint.fromName(utls['fingerprint'] as String? ?? 'chrome')
          : UtlsFingerprint.none,
      fragment: t['fragment'] as bool? ?? false,
      recordFragment: t['record_fragment'] as bool? ?? false,
      fragmentFallbackDelayMs: _parseMs(t['fragment_fallback_delay']),
      reality: reality['enabled'] == true,
      realityPublicKey: reality['public_key'] as String? ?? '',
      realityShortId: reality['short_id'] as String? ?? '',
    );
  }

  static Map<String, dynamic> _tlsTo(TlsConfig t, ObfuscationConfig o) {
    // Reality needs a uTLS ClientHello; default to Chrome if none chosen.
    final fingerprint = o.reality && o.fingerprint == UtlsFingerprint.none
        ? UtlsFingerprint.chrome
        : o.fingerprint;
    return {
      ...t.extra,
      'enabled': true,
      if (t.sni.isNotEmpty) 'server_name': t.sni,
      if (t.insecure) 'insecure': true,
      if (t.alpn.isNotEmpty) 'alpn': t.alpn,
      if (fingerprint != UtlsFingerprint.none)
        'utls': {'enabled': true, 'fingerprint': fingerprint.name},
      if (o.fragment) 'fragment': true,
      if (o.recordFragment) 'record_fragment': true,
      if ((o.fragment || o.recordFragment) && o.fragmentFallbackDelayMs != null)
        'fragment_fallback_delay': '${o.fragmentFallbackDelayMs}ms',
      if (o.reality)
        'reality': {
          'enabled': true,
          'public_key': o.realityPublicKey,
          if (o.realityShortId.isNotEmpty) 'short_id': o.realityShortId,
        },
    };
  }

  /// sing-box durations: "300ms", "1s", or a bare number of nanoseconds.
  static int? _parseMs(Object? value) {
    if (value is int) return value ~/ 1000000;
    if (value is! String || value.isEmpty) return null;
    final m = RegExp(r'^(\d+(?:\.\d+)?)(ms|s)$').firstMatch(value.trim());
    if (m == null) return null;
    final n = double.parse(m.group(1)!);
    return (m.group(2) == 's' ? n * 1000 : n).round();
  }

  // endregion
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
