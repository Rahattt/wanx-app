import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/core/singbox/config_builder.dart';
import 'package:wanx/core/singbox/server_address_resolver.dart';
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

  group('XHTTP', () {
    test('parses packet-up over HTTP/3 and maps Xray extra keys', () {
      final s = parser.parse(
        'vless://11111111-2222-3333-4444-555555555555@x.example.com:443'
        '?type=xhttp&security=tls&sni=cdn.example.com&alpn=h3&fp=chrome'
        '&path=%2Fx&host=cdn.example.com&mode=packet-up'
        '&extra=%7B%22xPaddingBytes%22%3A%22100-1000%22%2C%22noGRPCHeader%22%3Atrue%2C%22sessionIDTable%22%3A%22Base62%22%2C%22sessionIDLength%22%3A%2216-32%22%2C%22scMaxBufferedPosts%22%3A30%2C%22downloadSettings%22%3A%7B%7D%2C%22xmux%22%3A%7B%22maxConnections%22%3A%222-4%22%2C%22maxConcurrency%22%3A0%2C%22hKeepAlivePeriod%22%3A30%7D%7D#X',
      );
      expect(s.transport.type, TransportType.xhttp);
      expect(s.transport.path, '/x');
      expect(s.transport.host, 'cdn.example.com');
      expect(s.transport.xhttpMode, 'packet-up');
      final out = s.toOutbound();
      expect(out['tls']['alpn'], ['h3']);
      // Server-only (scMaxBufferedPosts), unsupported (downloadSettings)
      // and unset (maxConcurrency: 0) keys are dropped.
      expect(out['transport'], {
        'type': 'xhttp',
        'mode': 'packet-up',
        'x_padding_bytes': '100-1000',
        'no_grpc_header': true,
        'session_table': 'Base62',
        'session_length': '16-32',
        'xmux': {'max_connections': '2-4', 'h_keep_alive_period': 30},
        'path': '/x',
        'host': 'cdn.example.com',
      });
      expect(Server.fromJson(s.toJson()).toOutbound(), out);
    });

    test('splithttp alias, auto mode, VLESS encryption', () {
      final s = parser.parse(
        'vless://u@x.example.com:443?type=splithttp&mode=auto&security=reality'
        '&sni=www.apple.com&pbk=PUB&sid=ab&encryption=mlkem768x25519plus.native.0rtt.K#t',
      );
      final out = s.toOutbound();
      expect(out['transport'], {'type': 'xhttp'});
      expect(out['encryption'], 'mlkem768x25519plus.native.0rtt.K');
      expect(
        parser
            .parse('vless://u@h.example.com:443?encryption=none#t')
            .toOutbound()
            .containsKey('encryption'),
        isFalse,
      );
    });

    test('pinning the address keeps the hostname as Host', () {
      final s = parser.parse(
        'vless://u@x.example.com:443?type=xhttp&security=tls#t',
      );
      final out = ServerAddressResolver.withAddress(s.toOutbound(), '1.2.3.4');
      expect(out['server'], '1.2.3.4');
      expect(out['transport']['host'], 'x.example.com');
    });

    test('changing the transport type drops the old type options', () {
      final s = parser.parse(
        'vless://u@x.example.com:443?type=xhttp&mode=stream-up#t',
      );
      final ws = s.transport.copyWith(type: TransportType.ws);
      expect(ws.extra, isEmpty);
    });
  });

  group('Remnawave / Happ subscriptions', () {
    test('fragment= becomes the Xray-style fragmentation', () {
      final s = parser.parse(
        'vless://u@1.2.3.4:443?fragment=1-2,0-1,tlshello&type=ws&path=%2F'
        '&host=h.example.com&security=tls&sni=h.example.com&fp=safari#f',
      );
      expect(s.obfuscation.xrayFragment, isTrue);
      expect(s.toOutbound()['tcp_fragment'], {
        'packets': 'tlshello',
        'length': '1-2',
        'interval': '0-1',
      });
      // packets first is accepted too; a zero interval is no pause.
      expect(
        parser
            .parse('trojan://p@t.example.com:443?fragment=tlshello,100-200,0#t')
            .toOutbound()['tcp_fragment'],
        {'packets': 'tlshello', 'length': '100-200'},
      );
      expect(
        parser
            .parse('trojan://p@t.example.com:443?fragment=junk#t')
            .obfuscation
            .xrayFragment,
        isFalse,
      );
    });

    test('XHTTP extra numbers become the string ranges the core takes', () {
      final extra = Uri.encodeComponent(
        '{"xmux":{"cMaxReuseTimes":0,"maxConcurrency":"16-32",'
        '"maxConnections":0,"hMaxRequestTimes":"600-900"},'
        '"scMaxEachPostBytes":1000000,"scMinPostsIntervalMs":30,'
        '"xPaddingBytes":[100,1000]}',
      );
      final t = parser
          .parse('vless://u@x.example.com:443?type=xhttp&extra=$extra#x')
          .toOutbound()['transport'];
      expect(t['sc_max_each_post_bytes'], '1000000');
      expect(t['sc_min_posts_interval_ms'], '30');
      expect(t['x_padding_bytes'], '100-1000');
      expect(t['xmux'], {
        'max_concurrency': '16-32',
        'h_max_request_times': '600-900',
      });
    });

    test('header comment lines are not reported as failures', () {
      final r = parser.parseMany(
        '# profile-title: Test\n'
        '# subscription-userinfo: upload=0; download=0\n'
        'trojan://p@t.example.com:443#t\n',
      );
      expect(r.servers, hasLength(1));
      expect(r.failures, isEmpty);
    });
  });
}
