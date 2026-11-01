import 'dart:convert';

import '../domain/outbound_codec.dart';
import '../domain/server.dart';
import 'wireguard_parser.dart';

class ShareLinkException implements Exception {
  ShareLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One input line that could not be imported, with the reason.
class ParseFailure {
  const ParseFailure(this.input, this.reason);

  final String input;
  final String reason;

  /// Input shortened for display, without credentials after the scheme.
  String get preview {
    final scheme = input.split('://').first;
    return input.contains('://')
        ? '$scheme://…'
        : (input.length > 24 ? '${input.substring(0, 24)}…' : input);
  }
}

class ParseResult {
  const ParseResult(this.servers, this.failures);

  final List<Server> servers;
  final List<ParseFailure> failures;

  /// Human-readable reason when nothing could be imported.
  String get failureSummary {
    if (failures.isEmpty) return 'No server links found';
    final first = failures.first;
    final more = failures.length > 1 ? ' (+${failures.length - 1} more)' : '';
    return '${first.preview}: ${first.reason}$more';
  }
}

/// Converts share links (vless://, vmess://, trojan://, ss://, hysteria2://,
/// hy2://, tuic://, wireguard://, Amnezia vpn://) and WireGuard `.conf` text
/// into [Server] profiles.
class ShareLinkParser {
  static const supportedSchemes = [
    'vless',
    'vmess',
    'trojan',
    'ss',
    'hysteria2',
    'hy2',
    'tuic',
    'wireguard',
    'wg',
    'vpn',
  ];

  /// Parses every non-empty line in [text]. Also accepts a base64-encoded
  /// subscription body. [group]/[subscriptionId] are stamped on every server.
  ParseResult parseMany(String text, {String? group, String? subscriptionId}) {
    var body = text.trim();
    if (body.isEmpty) return const ParseResult([], []);
    // A WireGuard config is one multi-line profile, not a list of links.
    if (WireGuardParser.isConf(body)) {
      try {
        return ParseResult([
          _fromOutbound(
            WireGuardParser.parseConf(body),
            null,
            group: group,
            subscriptionId: subscriptionId,
          ),
        ], const []);
      } on ShareLinkException catch (e) {
        return ParseResult(const [], [ParseFailure('[Interface]', e.message)]);
      }
    }
    if (!body.contains('://')) {
      try {
        body = _decodeBase64(body.replaceAll(RegExp(r'\s'), ''));
      } on ShareLinkException {
        return ParseResult(const [], [
          ParseFailure(body, 'Not a share link and not a base64 subscription'),
        ]);
      }
    }
    final servers = <Server>[];
    final failures = <ParseFailure>[];
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      try {
        servers.add(parse(line, group: group, subscriptionId: subscriptionId));
      } on ShareLinkException catch (e) {
        failures.add(ParseFailure(line, e.message));
      }
    }
    return ParseResult(servers, failures);
  }

  Server parse(String link, {String? group, String? subscriptionId}) {
    try {
      final (outbound, name) = _parse(link);
      return _fromOutbound(
        outbound,
        name,
        group: group,
        subscriptionId: subscriptionId,
      );
    } on FormatException catch (e) {
      throw ShareLinkException('Malformed link: ${e.message}');
    } on OutboundFormatException catch (e) {
      throw ShareLinkException(e.message);
    }
  }

  Server _fromOutbound(
    Map<String, dynamic> outbound,
    String? name, {
    String? group,
    String? subscriptionId,
  }) {
    try {
      return OutboundCodec.fromOutbound(
        outbound,
        name: name,
        group: group,
        subscriptionId: subscriptionId,
      );
    } on OutboundFormatException catch (e) {
      throw ShareLinkException(e.message);
    }
  }

  (Map<String, dynamic>, String?) _parse(String link) {
    if (!link.contains('://')) {
      throw ShareLinkException('Not a link (expected scheme://…)');
    }
    final scheme = link.split('://').first.toLowerCase();
    return switch (scheme) {
      'vless' => _withName(Uri.parse(link), _vless),
      'trojan' => _withName(Uri.parse(link), _trojan),
      'hysteria2' || 'hy2' => _withName(Uri.parse(link), _hysteria2),
      'tuic' => _withName(Uri.parse(link), _tuic),
      'wireguard' ||
      'wg' => _withName(Uri.parse(link), WireGuardParser.parseLink),
      'vpn' => WireGuardParser.parseAmnezia(link),
      'ss' => _shadowsocks(link),
      'vmess' => _vmess(link),
      _ => throw ShareLinkException(
        'Unsupported scheme "$scheme://" (supported: ${supportedSchemes.join(', ')})',
      ),
    };
  }

  (Map<String, dynamic>, String?) _withName(
    Uri uri,
    Map<String, dynamic> Function(Uri) build,
  ) {
    if (uri.host.isEmpty) throw ShareLinkException('Link has no host');
    final name = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
        : null;
    return (build(uri), name);
  }

  Map<String, dynamic> _vless(Uri uri) {
    final q = uri.queryParameters;
    final id = Uri.decodeComponent(uri.userInfo);
    if (id.isEmpty) throw ShareLinkException('VLESS link has no UUID');
    return {
      'type': 'vless',
      'server': uri.host,
      'server_port': _port(uri),
      'uuid': id,
      if ((q['flow'] ?? '').isNotEmpty) 'flow': q['flow'],
      // VLESS Encryption (post-quantum layer inside VLESS).
      if ((q['encryption'] ?? 'none') case final e when e != 'none' && e != '')
        'encryption': e,
      ..._tlsAndTransport(q, uri.host),
    };
  }

  Map<String, dynamic> _trojan(Uri uri) {
    final q = uri.queryParameters;
    return {
      'type': 'trojan',
      'server': uri.host,
      'server_port': _port(uri),
      'password': Uri.decodeComponent(uri.userInfo),
      // Trojan always runs over TLS.
      ..._tlsAndTransport({'security': 'tls', ...q}, uri.host),
    };
  }

  Map<String, dynamic> _hysteria2(Uri uri) {
    final q = uri.queryParameters;
    return {
      'type': 'hysteria2',
      'server': uri.host,
      'server_port': _port(uri),
      'password': Uri.decodeComponent(uri.userInfo),
      if ((q['obfs'] ?? '').isNotEmpty)
        'obfs': {'type': q['obfs'], 'password': q['obfs-password'] ?? ''},
      'tls': _tls(q, uri.host, alpn: 'h3'),
    };
  }

  Map<String, dynamic> _tuic(Uri uri) {
    final q = uri.queryParameters;
    final [id, password] = _splitUserInfo(uri.userInfo);
    return {
      'type': 'tuic',
      'server': uri.host,
      'server_port': _port(uri),
      'uuid': id,
      'password': password,
      if ((q['congestion_control'] ?? '').isNotEmpty)
        'congestion_control': q['congestion_control'],
      'tls': _tls(q, uri.host, alpn: 'h3'),
    };
  }

  /// SIP002: ss://base64(method:password)@host:port#name
  /// or legacy: ss://base64(method:password@host:port)#name
  (Map<String, dynamic>, String?) _shadowsocks(String link) {
    var uri = Uri.parse(link);
    if (uri.host.isEmpty) {
      final hashIndex = link.indexOf('#');
      final encoded = link.substring(
        5,
        hashIndex == -1 ? link.length : hashIndex,
      );
      final fragment = hashIndex == -1 ? '' : link.substring(hashIndex);
      uri = Uri.parse('ss://${_decodeBase64(encoded)}$fragment');
    }
    var userInfo = Uri.decodeComponent(uri.userInfo);
    if (!userInfo.contains(':')) userInfo = _decodeBase64(userInfo);
    final [method, password] = _splitUserInfo(userInfo);
    return _withName(
      uri,
      (uri) => {
        'type': 'shadowsocks',
        'server': uri.host,
        'server_port': _port(uri),
        'method': method,
        'password': password,
      },
    );
  }

  /// vmess://base64(json) — the v2rayN format.
  (Map<String, dynamic>, String?) _vmess(String link) {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(_decodeBase64(link.substring(8))) as Map<String, dynamic>;
    } on FormatException {
      throw ShareLinkException('VMess payload is not base64-encoded JSON');
    }
    final host = '${j['add'] ?? ''}';
    final port = int.tryParse('${j['port']}') ?? 0;
    if (host.isEmpty) throw ShareLinkException('VMess link has no address');
    if (port <= 0 || port > 65535) {
      throw ShareLinkException('VMess link has invalid port "${j['port']}"');
    }
    final q = <String, String>{
      'type': '${j['net'] ?? 'tcp'}',
      'security': '${j['tls'] ?? ''}',
      if (j['sni'] != null) 'sni': '${j['sni']}',
      if (j['host'] != null) 'host': '${j['host']}',
      if (j['path'] != null) 'path': '${j['path']}',
      if (j['alpn'] != null) 'alpn': '${j['alpn']}',
      if (j['fp'] != null) 'fp': '${j['fp']}',
    };
    final name = '${j['ps'] ?? ''}';
    return (
      {
        'type': 'vmess',
        'server': host,
        'server_port': port,
        'uuid': '${j['id']}',
        'security': '${j['scy'] ?? 'auto'}',
        'alter_id': int.tryParse('${j['aid'] ?? 0}') ?? 0,
        ..._tlsAndTransport(q, host),
      },
      name.isEmpty ? null : name,
    );
  }

  Map<String, dynamic> _tlsAndTransport(Map<String, String> q, String host) {
    final security = q['security'] ?? 'none';
    final transport = _transport(q);
    return {
      if (security == 'tls' || security == 'reality')
        'tls': _tls(
          q,
          host,
          // sing-box's ws/httpupgrade client only speaks HTTP/1.1; negotiating
          // h2 via ALPN makes the upgrade fail.
          forceHttp1:
              transport?['type'] == 'ws' || transport?['type'] == 'httpupgrade',
        ),
      'transport': ?transport,
    };
  }

  Map<String, dynamic> _tls(
    Map<String, String> q,
    String host, {
    String? alpn,
    bool forceHttp1 = false,
  }) {
    final alpnValue = forceHttp1 ? 'http/1.1' : (q['alpn'] ?? alpn);
    return {
      'enabled': true,
      'server_name': q['sni'] ?? q['peer'] ?? host,
      if (q['insecure'] == '1' || q['allowInsecure'] == '1') 'insecure': true,
      if (alpnValue != null && alpnValue.isNotEmpty)
        'alpn': alpnValue.split(','),
      if ((q['fp'] ?? '').isNotEmpty)
        'utls': {'enabled': true, 'fingerprint': q['fp']},
      if (q['security'] == 'reality')
        'reality': {
          'enabled': true,
          'public_key': q['pbk'] ?? '',
          'short_id': q['sid'] ?? '',
        },
    };
  }

  Map<String, dynamic>? _transport(Map<String, String> q) {
    return switch (q['type']) {
      'ws' => _websocket(q),
      'grpc' => {'type': 'grpc', 'service_name': q['serviceName'] ?? ''},
      'http' || 'h2' => {
        'type': 'http',
        'path': q['path'] ?? '/',
        if ((q['host'] ?? '').isNotEmpty) 'host': q['host']!.split(','),
      },
      'httpupgrade' => {
        'type': 'httpupgrade',
        'path': q['path'] ?? '/',
        if ((q['host'] ?? '').isNotEmpty) 'host': q['host'],
      },
      'xhttp' || 'splithttp' => _xhttp(q),
      _ => null,
    };
  }

  /// XHTTP from Xray links: `path`, `host`, `mode`, and `extra` (Xray's
  /// camelCase JSON of the advanced options). The HTTP version follows from
  /// the TLS ALPN (`alpn=h3` = HTTP/3), as in Xray.
  Map<String, dynamic> _xhttp(Map<String, String> q) {
    Object? extra;
    if ((q['extra'] ?? '').isNotEmpty) {
      try {
        extra = jsonDecode(q['extra']!);
      } on FormatException {
        throw ShareLinkException('XHTTP "extra" is not valid JSON');
      }
    }
    final mode = q['mode'] ?? '';
    return {
      'type': 'xhttp',
      if (mode.isNotEmpty && mode != 'auto') 'mode': mode,
      if ((q['path'] ?? '').isNotEmpty) 'path': q['path'],
      if ((q['host'] ?? '').isNotEmpty) 'host': q['host'],
      if (extra is Map) ..._xhttpExtra(extra.cast<String, dynamic>()),
    };
  }

  /// Xray XHTTP keys → sing-box-lx keys. Server-only and unsupported keys
  /// (downloadSettings) are dropped: the core rejects unknown fields.
  static const _xhttpKeys = {
    'headers': 'headers',
    'xPaddingBytes': 'x_padding_bytes',
    'xPaddingObfsMode': 'x_padding_obfs_mode',
    'xPaddingKey': 'x_padding_key',
    'xPaddingHeader': 'x_padding_header',
    'xPaddingPlacement': 'x_padding_placement',
    'xPaddingMethod': 'x_padding_method',
    'uplinkHTTPMethod': 'uplink_http_method',
    'sessionPlacement': 'session_placement',
    'sessionKey': 'session_key',
    'sessionIDTable': 'session_table',
    'sessionIDLength': 'session_length',
    'seqPlacement': 'seq_placement',
    'seqKey': 'seq_key',
    'uplinkDataPlacement': 'uplink_data_placement',
    'uplinkDataKey': 'uplink_data_key',
    'uplinkChunkSize': 'uplink_chunk_size',
    'noGRPCHeader': 'no_grpc_header',
    'scMaxEachPostBytes': 'sc_max_each_post_bytes',
    'scMinPostsIntervalMs': 'sc_min_posts_interval_ms',
  };

  static const _xmuxKeys = {
    'maxConcurrency': 'max_concurrency',
    'maxConnections': 'max_connections',
    'cMaxReuseTimes': 'c_max_reuse_times',
    'hMaxRequestTimes': 'h_max_request_times',
    'hMaxReusableSecs': 'h_max_reusable_secs',
    'hKeepAlivePeriod': 'h_keep_alive_period',
  };

  Map<String, dynamic> _xhttpExtra(Map<String, dynamic> extra) {
    bool isSet(Object? v) => v != null && v != '' && v != 0 && v != false;
    final xmux = extra['xmux'] is Map
        ? {
            for (final MapEntry(:key, :value)
                in (extra['xmux'] as Map).cast<String, dynamic>().entries)
              if (_xmuxKeys[key] case final k? when isSet(value)) k: value,
          }
        : const <String, dynamic>{};
    return {
      for (final MapEntry(:key, :value) in extra.entries)
        if (_xhttpKeys[key] case final k? when isSet(value)) k: value,
      if (xmux.isNotEmpty) 'xmux': xmux,
    };
  }

  /// Xray encodes WebSocket early data as `?ed=N` in the path; sing-box
  /// wants it as separate options.
  Map<String, dynamic> _websocket(Map<String, String> q) {
    var path = q['path'] ?? '/';
    var earlyData = 0;
    final pathUri = Uri.tryParse(path);
    final ed = int.tryParse(pathUri?.queryParameters['ed'] ?? '');
    if (pathUri != null && ed != null) {
      earlyData = ed;
      final rest = Map.of(pathUri.queryParameters)..remove('ed');
      // Uri.replace(queryParameters: null) keeps the old query, so rebuild.
      path = rest.isEmpty
          ? pathUri.path
          : '${pathUri.path}?${Uri(queryParameters: rest).query}';
    }
    return {
      'type': 'ws',
      'path': path.isEmpty ? '/' : path,
      if ((q['host'] ?? '').isNotEmpty) 'headers': {'Host': q['host']},
      if (earlyData > 0) ...{
        'max_early_data': earlyData,
        'early_data_header_name': 'Sec-WebSocket-Protocol',
      },
    };
  }

  int _port(Uri uri) {
    if (!uri.hasPort) throw ShareLinkException('Link has no port');
    return uri.port;
  }

  List<String> _splitUserInfo(String userInfo) {
    final decoded = Uri.decodeComponent(userInfo);
    final i = decoded.indexOf(':');
    if (i == -1) {
      throw ShareLinkException(
        'Malformed credentials (expected user:password)',
      );
    }
    return [decoded.substring(0, i), decoded.substring(i + 1)];
  }

  String _decodeBase64(String input) {
    try {
      final normalized = base64.normalize(
        input.trim().replaceAll('-', '+').replaceAll('_', '/'),
      );
      return utf8.decode(base64.decode(normalized));
    } on FormatException {
      throw ShareLinkException('Invalid base64');
    }
  }
}
