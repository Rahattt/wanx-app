import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/features/servers/domain/subscription_url.dart';

void main() {
  group('SubscriptionUrl.parse', () {
    test('plain URL: no label, no routing, request URL unchanged', () {
      final p = SubscriptionUrl.parse('https://sub.example.com/x?id=1');
      expect(p.label, isNull);
      expect(p.hostHeader, isNull);
      expect(p.requestUrl.toString(), 'https://sub.example.com/x?id=1');
    });

    test('fragment without "?" is a bare label', () {
      final p = SubscriptionUrl.parse('https://sub.example.com/x#Wagtlayyn');
      expect(p.label, 'Wagtlayyn');
      expect(p.hostHeader, isNull);
      expect(p.requestUrl.toString(), 'https://sub.example.com/x');
    });

    test('CRM format: URL/SNI on the endpoint, header_host only in Host', () {
      final p = SubscriptionUrl.parse(
        'https://api.example.com/v1/config?id=123'
        '#Tariff?endpoint=node1.example.com&header_host=panel.example.com',
      );
      expect(p.label, 'Tariff');
      // TLS terminates on the endpoint, so the URL (SNI, cert) names it...
      expect(
        p.requestUrl.toString(),
        'https://node1.example.com/v1/config?id=123',
      );
      // ...and the inner service is picked by the Host header alone.
      expect(p.hostHeader, 'panel.example.com');
      expect(p.originalUrl.host, 'api.example.com');
      expect(p.originalUrl.fragment, contains('endpoint=node1.example.com'));
    });

    test('resolve-address alone: URL on it, Host is the link host', () {
      final p = SubscriptionUrl.parse(
        'https://api.example.com/c#Plan?resolve-address=1.2.3.4',
      );
      expect(p.requestUrl.host, '1.2.3.4');
      expect(p.hostHeader, 'api.example.com');
      final withPort = SubscriptionUrl.parse(
        'https://api.example.com:8443/c#Plan?resolve-address=1.2.3.4',
      );
      expect(withPort.hostHeader, 'api.example.com:8443');
      final same = SubscriptionUrl.parse(
        'https://api.example.com/c#Plan?resolve-address=api.example.com',
      );
      expect(same.hostHeader, isNull);
    });

    test('header_host alone: URL keeps the link host, Host overridden', () {
      final p = SubscriptionUrl.parse(
        'https://api.example.com/c#Plan?header_host=in.example.com',
      );
      expect(p.requestUrl.host, 'api.example.com');
      expect(p.hostHeader, 'in.example.com');
    });

    test('legacy keys, and new keys winning over them', () {
      final legacy = SubscriptionUrl.parse(
        'https://api.example.com/c#P?resolve-address=1.2.3.4&host=panel.example.com',
      );
      expect(legacy.requestUrl.host, '1.2.3.4');
      expect(legacy.hostHeader, 'panel.example.com');
      final both = SubscriptionUrl.parse(
        'https://api.example.com/c#X?endpoint=new.example.com'
        '&resolve-address=old.example.com'
        '&header_host=new-host.example.com&host=old-host.example.com',
      );
      expect(both.requestUrl.host, 'new.example.com');
      expect(both.hostHeader, 'new-host.example.com');
    });

    test('empty label with only params yields a null label', () {
      final p = SubscriptionUrl.parse(
        'https://api.example.com/c#?resolve-address=n.example.com&host=panel.example.com',
      );
      expect(p.label, isNull);
      expect(p.requestUrl.host, 'n.example.com');
      expect(p.hostHeader, 'panel.example.com');
    });

    test('labels: spaces, Cyrillic, emoji, raw or encoded, stray %', () {
      String? label(String frag) =>
          SubscriptionUrl.parse('https://a.example.com/c#$frag').label;
      expect(label('My%20VPN?endpoint=n.example.com'), 'My VPN');
      expect(label('Мой тариф 🚀?endpoint=n.example.com'), 'Мой тариф 🚀');
      expect(label('%D0%9F%D1%80%D0%BE%20%E2%AD%90'), 'Про ⭐');
      expect(label('100%'), '100%');
      expect(label('a%26b%3Fc?endpoint=n.example.com'), 'a&b?c');
      expect(label('%20%20?endpoint=n.example.com'), isNull);
    });

    test('a link round-trips through its stored form unchanged', () {
      final first = SubscriptionUrl.parse(
        'https://api.example.com/c#Мой тариф?endpoint=n.example.com&header_host=p.example.com',
      );
      final again = SubscriptionUrl.parse(first.originalUrl.toString());
      expect(again.label, first.label);
      expect(again.hostHeader, first.hostHeader);
      expect(again.requestUrl, first.requestUrl);
    });

    test('endpoint equal to the link host, or different from it', () {
      final same = SubscriptionUrl.parse(
        'https://api.example.com/c?id=1'
        '#N?resolve-address=api.example.com&host=in.example.com',
      );
      expect(same.requestUrl.toString(), 'https://api.example.com/c?id=1');
      expect(same.hostHeader, 'in.example.com');
      final other = SubscriptionUrl.parse(
        'https://api.example.com/c?id=1#N?resolve-address=edge.example.com',
      );
      expect(other.requestUrl.toString(), 'https://edge.example.com/c?id=1');
    });

    test('endpoint with a port or as IPv6', () {
      final port = SubscriptionUrl.parse(
        'https://api.example.com/c#N?endpoint=n.example.com:8443',
      );
      expect(port.requestUrl.toString(), 'https://n.example.com:8443/c');
      final v6 = SubscriptionUrl.parse(
        'https://api.example.com/c#N?endpoint=%5B2001:db8::1%5D:8443',
      );
      expect(v6.requestUrl.host, '2001:db8::1');
      expect(v6.requestUrl.port, 8443);
    });

    test('blank params are ignored; malformed ones are rejected', () {
      final p = SubscriptionUrl.parse(
        'https://api.example.com/c#Name?endpoint=&header_host=',
      );
      expect(p.label, 'Name');
      expect(p.hostHeader, isNull);
      expect(p.requestUrl.host, 'api.example.com');
      for (final bad in ['endpoint=x/y', 'header_host=a/b']) {
        expect(
          () => SubscriptionUrl.parse('https://a.example.com/c#N?$bad'),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects non-http and malformed URLs', () {
      expect(
        () => SubscriptionUrl.parse('ftp://x.example.com'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SubscriptionUrl.parse('not a url'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
