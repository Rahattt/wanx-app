import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/features/servers/domain/outbound_codec.dart';
import 'package:wanx/features/servers/domain/server.dart';
import 'package:wanx/features/servers/domain/server_config.dart';

void main() {
  final outbound = <String, dynamic>{
    'type': 'vless',
    'tag': 'DE-1',
    'server': 'de.example.com',
    'server_port': 443,
    'uuid': 'u-1',
    'packet_encoding': 'xudp',
    'multiplex': {'enabled': true, 'protocol': 'h2mux'},
    'tls': {
      'enabled': true,
      'server_name': 'front.example.com',
      'alpn': ['http/1.1'],
      'ech': {'enabled': true},
      'utls': {'enabled': true, 'fingerprint': 'firefox'},
      'fragment': true,
      'fragment_fallback_delay': '500ms',
    },
    'transport': {
      'type': 'ws',
      'path': '/p',
      'headers': {'Host': 'real.example.com', 'X-Extra': '1'},
    },
  };

  test('sing-box outbound round-trips losslessly', () {
    final s = OutboundCodec.fromOutbound(outbound);
    expect(s.name, 'DE-1');
    expect(s.transport.host, 'real.example.com');
    expect(s.obfuscation.fingerprint, UtlsFingerprint.firefox);
    expect(s.obfuscation.fragmentFallbackDelayMs, 500);
    expect(s.toOutbound(), {...outbound}..remove('tag'));
  });

  test('survives JSON persistence', () {
    final s = OutboundCodec.fromOutbound(
      outbound,
      group: 'Sub',
      subscriptionId: 'sub-1',
    );
    final restored = Server.fromJson(s.toJson());
    expect(restored.toOutbound(), s.toOutbound());
    expect(restored.group, 'Sub');
    expect(restored.subscriptionId, 'sub-1');
  });

  test('migrates profiles saved with a raw outbound', () {
    final legacy = {
      'id': 'old-id',
      'name': 'Old',
      'protocol': 'trojan',
      'host': 't.example.com',
      'port': 443,
      'outbound': {
        'type': 'trojan',
        'server': 't.example.com',
        'server_port': 443,
        'password': 'pw',
        'tls': {'enabled': true, 'server_name': 't.example.com'},
      },
    };
    final s = Server.fromJson(legacy);
    expect(s.id, 'old-id');
    expect(s.name, 'Old');
    expect(s.tls.enabled, isTrue);
    expect(s.toOutbound()['password'], 'pw');
  });

  test('Reality without a fingerprint defaults uTLS to chrome', () {
    final s =
        OutboundCodec.fromOutbound({
          'type': 'vless',
          'server': 'r.example.com',
          'server_port': 443,
          'uuid': 'u',
        }).copyWith(
          tls: const TlsConfig(enabled: true, sni: 'www.apple.com'),
          obfuscation: const ObfuscationConfig(
            reality: true,
            realityPublicKey: 'K',
          ),
        );
    expect(s.toOutbound()['tls']['utls'], {
      'enabled': true,
      'fingerprint': 'chrome',
    });
  });

  test('rejects unsupported or incomplete outbounds with a reason', () {
    expect(
      () => OutboundCodec.fromOutbound({
        'type': 'tor',
        'server': 'x',
        'server_port': 1,
      }),
      throwsA(
        isA<OutboundFormatException>().having(
          (e) => e.message,
          'message',
          contains('tor'),
        ),
      ),
    );
    expect(
      () => OutboundCodec.fromOutbound({'type': 'wireguard', 'peers': []}),
      throwsA(
        isA<OutboundFormatException>().having(
          (e) => e.message,
          'message',
          contains('no peers'),
        ),
      ),
    );
    expect(
      () => OutboundCodec.fromOutbound({
        'type': 'trojan',
        'server': 'x',
        'server_port': 70000,
      }),
      throwsA(
        isA<OutboundFormatException>().having(
          (e) => e.message,
          'message',
          contains('invalid port'),
        ),
      ),
    );
  });
}
