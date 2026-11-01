import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/core/singbox/config_builder.dart';
import 'package:wanx/core/singbox/server_address_resolver.dart';
import 'package:wanx/features/servers/data/share_link_parser.dart';
import 'package:wanx/features/servers/domain/server.dart';
import 'package:wanx/features/servers/domain/wireguard_obfuscation.dart';

void main() {
  final parser = ShareLinkParser();

  const plainConf = '''
[Interface]
PrivateKey = cPRIV=
Address = 10.66.0.2/32, fd00::2/128
DNS = 1.1.1.1
MTU = 1380

[Peer]
PublicKey = sPUB=
PresharedKey = PSK=
Endpoint = wg.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';

  test('parses a wg-quick config into a sing-box endpoint', () {
    final s = parser.parseMany(plainConf).servers.single;
    expect(s.protocol, ServerProtocol.wireguard);
    expect(s.address, 'wg.example.com:51820');
    expect(WireGuardObfuscation.isEnabled(s.settings), isFalse);
    expect(s.toOutbound(), {
      'type': 'wireguard',
      'private_key': 'cPRIV=',
      'address': ['10.66.0.2/32', 'fd00::2/128'],
      'mtu': 1380,
      'peers': [
        {
          'public_key': 'sPUB=',
          'pre_shared_key': 'PSK=',
          'allowed_ips': ['0.0.0.0/0', '::/0'],
          'persistent_keepalive_interval': 25,
          'address': 'wg.example.com',
          'port': 51820,
        },
      ],
    });
    expect(Server.fromJson(s.toJson()).toOutbound(), s.toOutbound());
  });

  test('maps AmneziaWG fields; they need an AmneziaWG server', () {
    final s = parser
        .parseMany('''
[Interface]
PrivateKey = cPRIV=
Address = 10.8.1.7/32
Jc = 4
Jmin = 10
Jmax = 50
S1 = 55
S2 = 42
H1 = 1
H2 = 826869626-2105069164
I1 = <b 0x000100002112a442><r 12>
HeaderProtectionKey = HPK=
RandomTrailers = on

[Peer]
PublicKey = sPUB=
Endpoint = [2001:db8::1]:30565
''')
        .servers
        .single;
    expect(s.host, '2001:db8::1');
    final out = s.toOutbound();
    expect(out['jc'], 4);
    expect(out['s1'], 55);
    expect(out['h1'], 1);
    expect(out['h2'], '826869626-2105069164');
    expect(out['i1'], '<b 0x000100002112a442><r 12>');
    expect(out['header_protection_key'], 'HPK=');
    expect(out['random_trailers'], isTrue);
    expect(WireGuardObfuscation.needsAmneziaServer(s.settings), isTrue);
    // Turning the switch off keeps what the server requires.
    final off = WireGuardObfuscation.disable(s.settings);
    expect(off.containsKey('jc'), isFalse);
    expect(off['s1'], 55);
  });

  test('obfuscation adds what the Amnezia client adds to plain WireGuard', () {
    final s = parser.parseMany(plainConf).servers.single;
    final on = WireGuardObfuscation.enable(s.settings, random: Random(1));
    expect(on['jc'], inInclusiveRange(4, 6));
    expect(on['jmin'], 10);
    expect(on['jmax'], 50);
    expect(on['i1'], WireGuardObfuscation.amneziaI1);
    // Plain WireGuard server: no S/H changes.
    expect(WireGuardObfuscation.needsAmneziaServer(on), isFalse);
    expect(WireGuardObfuscation.isEnabled(on), isTrue);
    expect(WireGuardObfuscation.disable(on), s.settings);
  });

  test('parses a wireguard:// link', () {
    final s = parser.parse(
      'wireguard://cPRIV%3D@162.159.192.1:2408?publickey=sPUB%3D'
      '&address=172.16.0.2%2F32,2606:4700::2%2F128&mtu=1280'
      '&reserved=1,2,3&jc=3&jmin=40&jmax=70#warp',
    );
    expect(s.name, 'warp');
    final out = s.toOutbound();
    expect(out['private_key'], 'cPRIV=');
    expect(out['address'], ['172.16.0.2/32', '2606:4700::2/128']);
    expect(out['jc'], 3);
    expect(out['peers'][0]['reserved'], [1, 2, 3]);
    expect(out['peers'][0]['public_key'], 'sPUB=');
  });

  test("parses the Amnezia app's vpn:// export", () {
    final json = jsonEncode({
      'description': 'My AWG',
      'containers': [
        {
          'container': 'amnezia-awg',
          'awg': {
            'last_config': jsonEncode({'config': plainConf}),
          },
        },
      ],
    });
    final body = utf8.encode(json);
    final packed = BytesBuilder()
      ..add((ByteData(4)..setUint32(0, body.length)).buffer.asUint8List())
      ..add(ZLibEncoder().convert(body));
    final link =
        'vpn://${base64Url.encode(packed.toBytes()).replaceAll('=', '')}';
    final s = parser.parse(link);
    expect(s.name, 'My AWG');
    expect(s.address, 'wg.example.com:51820');
  });

  test('reports what is missing', () {
    final r = parser.parseMany('[Interface]\nAddress = 10.0.0.2/32\n');
    expect(r.servers, isEmpty);
    expect(r.failureSummary, contains('PrivateKey'));
  });

  test('config goes into endpoints; QUIC is not rejected', () {
    final s = parser.parseMany(plainConf).servers.single;
    final config = const SingBoxConfigBuilder().build(s);
    final endpoints = config['endpoints'] as List;
    expect(endpoints.single['tag'], SingBoxConfigBuilder.proxyTag);
    expect(endpoints.single['type'], 'wireguard');
    expect(
      (config['outbounds'] as List).map((o) => o['type']),
      isNot(contains('wireguard')),
    );
    expect(
      (config['route']['rules'] as List).any((r) => r['protocol'] == 'quic'),
      isFalse,
    );
  });

  test('pinning the address rewrites the first peer', () {
    final s = parser.parseMany(plainConf).servers.single;
    final out = ServerAddressResolver.withAddress(s.toOutbound(), '1.2.3.4');
    expect(out['peers'][0]['address'], '1.2.3.4');
    expect(out['peers'][0]['port'], 51820);
  });
}
