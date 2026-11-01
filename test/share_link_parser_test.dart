import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/core/singbox/config_builder.dart';
import 'package:wanx/features/servers/data/share_link_parser.dart';
import 'package:wanx/features/servers/domain/server.dart';
import 'package:wanx/features/servers/domain/server_config.dart';

void main() {
  final parser = ShareLinkParser();

  test('parses VLESS Reality link into typed configs', () {
    final s = parser.parse(
      'vless://11111111-2222-3333-4444-555555555555@example.com:443'
      '?security=reality&sni=www.microsoft.com&pbk=PUBKEY&sid=ab&fp=chrome'
      '&flow=xtls-rprx-vision&type=tcp#My%20Server',
    );
    expect(s.protocol, ServerProtocol.vless);
    expect(s.name, 'My Server');
    expect(s.address, 'example.com:443');
    expect(s.tls.sni, 'www.microsoft.com');
    expect(s.obfuscation.reality, isTrue);
    expect(s.obfuscation.realityPublicKey, 'PUBKEY');
    expect(s.obfuscation.fingerprint, UtlsFingerprint.chrome);
    final out = s.toOutbound();
    expect(out['flow'], 'xtls-rprx-vision');
    expect(out['tls']['reality'], {
      'enabled': true,
      'public_key': 'PUBKEY',
      'short_id': 'ab',
    });
    expect(out['tls']['utls'], {'enabled': true, 'fingerprint': 'chrome'});
  });

  test('parses SIP002 Shadowsocks link', () {
    final userInfo = base64Url
        .encode(utf8.encode('aes-256-gcm:secret'))
        .replaceAll('=', '');
    final out = parser.parse('ss://$userInfo@1.2.3.4:8388#ss').toOutbound();
    expect(out['method'], 'aes-256-gcm');
    expect(out['password'], 'secret');
    expect(out.containsKey('tls'), isFalse);
  });

  test('parses vmess ws+tls link and forces HTTP/1.1 ALPN for ws', () {
    final json = jsonEncode({
      'ps': 'vm',
      'add': 'vm.example.com',
      'port': '443',
      'id': 'uuid',
      'aid': '0',
      'net': 'ws',
      'path': '/ws',
      'host': 'cdn.example.com',
      'tls': 'tls',
      'alpn': 'h2,http/1.1',
    });
    final s = parser.parse('vmess://${base64.encode(utf8.encode(json))}');
    expect(s.transport.type, TransportType.ws);
    expect(s.transport.host, 'cdn.example.com');
    expect(s.tls.alpn, ['http/1.1']);
    expect(s.toOutbound()['transport'], {
      'type': 'ws',
      'path': '/ws',
      'headers': {'Host': 'cdn.example.com'},
    });
  });

  test('moves ws early data from path to sing-box options', () {
    final s = parser.parse(
      'vless://id@h.example.com:443?security=tls&type=ws&path=%2Fws%3Fed%3D2048&host=cdn.example.com#x',
    );
    final transport = s.toOutbound()['transport'] as Map;
    expect(transport['path'], '/ws');
    expect(transport['max_early_data'], 2048);
    expect(transport['early_data_header_name'], 'Sec-WebSocket-Protocol');
  });

  test('parses base64 subscription and reports invalid lines', () {
    final body = base64.encode(
      utf8.encode(
        'trojan://pass@t.example.com:443#t\nfoo://bar\nhy2://pw@h.example.com:8443#h',
      ),
    );
    final result = parser.parseMany(body);
    expect(result.servers.map((s) => s.protocol), [
      ServerProtocol.trojan,
      ServerProtocol.hysteria2,
    ]);
    expect(
      result.failures.single.reason,
      startsWith('Unsupported scheme "foo://"'),
    );
  });

  test('explains why a single link failed', () {
    expect(
      parser.parseMany('vless://id@host.example.com#nport').failureSummary,
      contains('Link has no port'),
    );
    expect(
      parser.parseMany('hello').failureSummary,
      contains('Not a share link'),
    );
  });

  test('config builder wires the proxy outbound and TUN inbound', () {
    final s = parser.parse('trojan://pass@t.example.com:443#t');
    final config = const SingBoxConfigBuilder().build(s);
    final proxy = (config['outbounds'] as List).first as Map;
    expect(proxy['tag'], SingBoxConfigBuilder.proxyTag);
    expect(proxy['password'], 'pass');
    expect((config['inbounds'] as List).first['type'], 'tun');
    expect(config['route']['final'], SingBoxConfigBuilder.proxyTag);
  });

  test('QUIC is rejected over TCP transports, kept for QUIC servers', () {
    bool rejectsQuic(String link) {
      final config = const SingBoxConfigBuilder().build(parser.parse(link));
      return (config['route']['rules'] as List).any(
        (r) => r['protocol'] == 'quic' && r['action'] == 'reject',
      );
    }

    expect(rejectsQuic('trojan://pass@t.example.com:443#t'), isTrue);
    expect(rejectsQuic('hy2://pass@h.example.com:443#h'), isFalse);
  });
}
