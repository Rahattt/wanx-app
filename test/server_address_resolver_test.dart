import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/core/singbox/server_address_resolver.dart';

class _Resolver extends ServerAddressResolver {
  _Resolver(this.result);

  final List<InternetAddress>? result;
  final looked = <String>[];

  @override
  Future<List<InternetAddress>> lookup(String host) async {
    looked.add(host);
    final r = result;
    if (r == null) throw const SocketException('blocked');
    return r;
  }
}

void main() {
  test(
    'pins the IPv4 address and keeps the hostname in SNI and Host',
    () async {
      final resolver = _Resolver([
        InternetAddress('2001:db8::1'),
        InternetAddress('203.0.113.7'),
      ]);
      final out = await resolver.pin({
        'type': 'vless',
        'server': 'hel.example.com',
        'tls': {'enabled': true},
        'transport': {'type': 'ws', 'path': '/ws'},
      });
      expect(out['server'], '203.0.113.7');
      expect(out['tls'], {'enabled': true, 'server_name': 'hel.example.com'});
      expect(out['transport'], {
        'type': 'ws',
        'path': '/ws',
        'headers': {'Host': 'hel.example.com'},
      });
    },
  );

  test('keeps explicit SNI and Host header', () {
    final out = ServerAddressResolver.withAddress({
      'server': 'a.example.com',
      'tls': {'enabled': true, 'server_name': 'sni.example.com'},
      'transport': {'type': 'httpupgrade', 'host': 'cdn.example.com'},
    }, '203.0.113.7');
    expect((out['tls'] as Map)['server_name'], 'sni.example.com');
    expect((out['transport'] as Map)['host'], 'cdn.example.com');
  });

  test('leaves IP addresses alone without a lookup', () async {
    final resolver = _Resolver(null);
    final outbound = {'server': '198.51.100.1', 'server_port': 443};
    expect(await resolver.pin(outbound), same(outbound));
    expect(resolver.looked, isEmpty);
  });

  test('reports a host the system cannot resolve', () async {
    await expectLater(
      _Resolver(null).pin({'server': 'dead.example.com'}),
      throwsA(
        isA<ServerResolveException>().having(
          (e) => e.message,
          'message',
          'Could not resolve dead.example.com',
        ),
      ),
    );
  });
}
