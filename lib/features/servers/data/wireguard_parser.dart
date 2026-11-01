import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'share_link_parser.dart';

/// Parses WireGuard / AmneziaWG profiles into sing-box `wireguard` endpoint
/// JSON: `.conf` text (wg-quick / awg-quick), `wireguard://` links and the
/// Amnezia app's `vpn://` export.
abstract final class WireGuardParser {
  static bool isConf(String text) =>
      RegExp(r'^\s*\[Interface\]', multiLine: true).hasMatch(text);

  /// `[Interface]` keys → endpoint fields. AWG keys follow sing-box-lx's
  /// `awg.conf` mapping.
  static const _intKeys = {
    'jc': 'jc',
    'jmin': 'jmin',
    'jmax': 'jmax',
    's1': 's1',
    's2': 's2',
    's3': 's3',
    's4': 's4',
  };

  /// A number or an `N-M` range.
  static const _rangeKeys = {
    'h1': 'h1',
    'h2': 'h2',
    'h3': 'h3',
    'h4': 'h4',
    'contentpaddingaddition': 'content_padding_addition',
    'rekeyaftertime': 'rekey_after_time',
    'rekeytimeout': 'rekey_timeout',
    'rejectaftertime': 'reject_after_time',
    'keepalivetimeout': 'keepalive_timeout',
    'maxhandshakeattempts': 'max_handshake_attempts',
  };

  static const _stringKeys = {
    'i1': 'i1',
    'i2': 'i2',
    'i3': 'i3',
    'i4': 'i4',
    'i5': 'i5',
    'headerprotectionkey': 'header_protection_key',
  };

  static const _boolKeys = {
    'randomtrailers': 'random_trailers',
    'disablecookies': 'disable_cookies',
  };

  /// wg-quick / awg-quick config. Interface options the tunnel doesn't use
  /// (DNS, ListenPort, Table, Post/PreUp…) are ignored.
  static Map<String, dynamic> parseConf(String text) {
    final interface = <String, String>{};
    final peers = <Map<String, String>>[];
    Map<String, String>? section;
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.split('#').first.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('[')) {
        switch (line.toLowerCase()) {
          case '[interface]':
            section = interface;
          case '[peer]':
            peers.add(section = {});
          default:
            section = null;
        }
        continue;
      }
      final i = line.indexOf('=');
      if (i == -1 || section == null) continue;
      section[line.substring(0, i).trim().toLowerCase()] = line
          .substring(i + 1)
          .trim();
    }
    final privateKey = interface['privatekey'] ?? '';
    if (privateKey.isEmpty) {
      throw ShareLinkException('WireGuard config has no PrivateKey');
    }
    if (peers.isEmpty) {
      throw ShareLinkException('WireGuard config has no [Peer]');
    }
    return {
      'type': 'wireguard',
      'private_key': privateKey,
      'address': _list(interface['address']),
      'mtu': ?int.tryParse(interface['mtu'] ?? ''),
      ..._awg(interface),
      'peers': [for (final p in peers) _peer(p)],
    };
  }

  static Map<String, dynamic> _awg(Map<String, String> fields) {
    Object range(String v) => int.tryParse(v) ?? v;
    return {
      for (final MapEntry(:key, :value) in fields.entries)
        if (value.isNotEmpty)
          if (_intKeys[key] case final k?)
            k: int.tryParse(value) ?? (throw _bad(key, value))
          else if (_rangeKeys[key] case final k?)
            k: range(value)
          else if (_stringKeys[key] case final k?)
            k: value
          else
            ?_boolKeys[key]: const {
              'on',
              'true',
              '1',
              'yes',
            }.contains(value.toLowerCase()),
    };
  }

  static Map<String, dynamic> _peer(Map<String, String> p) {
    final publicKey = p['publickey'] ?? '';
    if (publicKey.isEmpty) {
      throw ShareLinkException('WireGuard peer has no PublicKey');
    }
    final (host, port) = _endpoint(p['endpoint'] ?? '');
    final keepalive = p['persistentkeepalive'] ?? '';
    return {
      'address': host,
      'port': port,
      'public_key': publicKey,
      if ((p['presharedkey'] ?? '').isNotEmpty)
        'pre_shared_key': p['presharedkey'],
      'allowed_ips': _list(p['allowedips']).isEmpty
          ? const ['0.0.0.0/0', '::/0']
          : _list(p['allowedips']),
      if (keepalive.isNotEmpty && keepalive != '0')
        'persistent_keepalive_interval': int.tryParse(keepalive) ?? keepalive,
    };
  }

  /// `host:port`, `[v6]:port`.
  static (String, int) _endpoint(String value) {
    final m = RegExp(r'^\[?([^\]]+?)\]?:(\d+)$').firstMatch(value);
    final port = int.tryParse(m?.group(2) ?? '') ?? 0;
    if (m == null || port <= 0 || port > 65535) {
      throw ShareLinkException(
        value.isEmpty
            ? 'WireGuard peer has no Endpoint'
            : 'WireGuard peer has invalid Endpoint "$value"',
      );
    }
    return (m.group(1)!, port);
  }

  /// `wireguard://<private key>@host:port?publickey=…&address=…#name`, the
  /// v2rayN form; AWG options as lowercase query keys.
  static Map<String, dynamic> parseLink(Uri uri) {
    final q = {
      for (final e in uri.queryParameters.entries) e.key.toLowerCase(): e.value,
    };
    String? first(List<String> keys) => keys
        .map((k) => q[k])
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    final privateKey = uri.userInfo.isNotEmpty
        ? Uri.decodeComponent(uri.userInfo)
        : first(['privatekey', 'private_key', 'pk']) ?? '';
    final publicKey = first(['publickey', 'public_key', 'peer_pk']) ?? '';
    if (privateKey.isEmpty) {
      throw ShareLinkException('WireGuard link has no private key');
    }
    if (publicKey.isEmpty) {
      throw ShareLinkException('WireGuard link has no peer public key');
    }
    if (!uri.hasPort) throw ShareLinkException('Link has no port');
    final reserved = _list(first(['reserved']))
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    final keepalive = first(['keepalive', 'persistentkeepalive']);
    final allowedIps = _list(first(['allowedips', 'allowed_ips']));
    return {
      'type': 'wireguard',
      'private_key': privateKey,
      'address': _list(first(['address', 'local_address', 'ip'])),
      'mtu': ?int.tryParse(q['mtu'] ?? ''),
      ..._awg({
        for (final e in q.entries)
          if (_isAwgKey(e.key)) e.key: e.value,
      }),
      'peers': [
        {
          'address': uri.host,
          'port': uri.port,
          'public_key': publicKey,
          'pre_shared_key': ?first(['presharedkey', 'pre_shared_key', 'psk']),
          'allowed_ips': allowedIps.isEmpty
              ? const ['0.0.0.0/0', '::/0']
              : allowedIps,
          if (reserved.length == 3) 'reserved': reserved,
          if (int.tryParse(keepalive ?? '') case final k? when k > 0)
            'persistent_keepalive_interval': k,
        },
      ],
    };
  }

  static bool _isAwgKey(String key) =>
      _intKeys.containsKey(key) ||
      _rangeKeys.containsKey(key) ||
      _stringKeys.containsKey(key) ||
      _boolKeys.containsKey(key);

  /// Amnezia's `vpn://` export: base64url of a Qt qCompress'ed JSON (4-byte
  /// length, then zlib). The tunnel is the `.conf` text in the AWG or
  /// WireGuard container's `last_config`.
  static (Map<String, dynamic>, String?) parseAmnezia(String link) {
    final Map<String, dynamic> json;
    try {
      final packed = base64Url.decode(
        base64Url.normalize(link.substring('vpn://'.length).trim()),
      );
      if (packed.length < 5) throw const FormatException();
      final body = ZLibDecoder().convert(Uint8List.sublistView(packed, 4));
      json = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    } on Object {
      throw ShareLinkException('Not a valid Amnezia vpn:// link');
    }
    for (final container in (json['containers'] as List? ?? const [])) {
      if (container is! Map) continue;
      for (final key in const ['awg', 'wireguard']) {
        final lastConfig = (container[key] as Map?)?['last_config'];
        if (lastConfig is! String) continue;
        final config = (jsonDecode(lastConfig) as Map)['config'];
        if (config is String && isConf(config)) {
          final name = json['description'] as String?;
          return (parseConf(config), (name ?? '').isEmpty ? null : name);
        }
      }
    }
    throw ShareLinkException(
      'Amnezia link has no WireGuard/AmneziaWG config '
      '(other protocols are not supported)',
    );
  }

  static List<String> _list(String? value) => [
    for (final v in (value ?? '').split(','))
      if (v.trim().isNotEmpty) v.trim(),
  ];

  static ShareLinkException _bad(String key, String value) =>
      ShareLinkException('WireGuard config has invalid $key "$value"');
}
