import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:wanx_sealed/wanx_sealed.dart';
import 'package:test/test.dart';

void main() {
  final seed = List.generate(32, (i) => i);

  Future<Map<String, List<int>>> trusted() async {
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    final pub = (await pair.extractPublicKey()).bytes;
    return {await signingKeyId(pub): pub};
  }

  SealedPayload payload(
    String device, {
    Duration ttl = const Duration(hours: 1),
  }) {
    final now = DateTime.now().toUtc();
    return SealedPayload(
      subscriptionId: 's1',
      name: 'Premium',
      provider: 'Acme',
      device: device,
      issuedAt: now,
      expiresAt: now.add(ttl),
      body: 'vless://u@h:443#a',
    );
  }

  test('seal → open → verify round trip', () async {
    final (priv, pub) = generateDeviceKey();
    final fp = await deviceFingerprint(pub);
    final signed = await signPayload(payload(fp), seed);
    final envelope = await seal(pub, utf8.encode(signed.encode()));
    final wire = SealedEnvelope.decode(envelope.encode());
    final clear = await open(wire, privateKey: priv, publicKey: pub);
    final result = await verifyPayload(
      SignedPayload.decode(utf8.decode(clear)),
      trustedKeys: await trusted(),
      deviceFingerprint: fp,
    );
    expect(result.body, 'vless://u@h:443#a');
    expect(result.name, 'Premium');
  });

  test('another device cannot open it', () async {
    final (_, pub) = generateDeviceKey();
    final (otherPriv, otherPub) = generateDeviceKey();
    final envelope = await seal(pub, utf8.encode('secret'));
    expect(
      () => open(envelope, privateKey: otherPriv, publicKey: otherPub),
      throwsA(isA<SealedException>()),
    );
  });

  test('tampered ciphertext is rejected', () async {
    final (priv, pub) = generateDeviceKey();
    final envelope = await seal(pub, utf8.encode('secret'));
    envelope.ciphertext[0] ^= 1;
    expect(
      () => open(envelope, privateKey: priv, publicKey: pub),
      throwsA(isA<SealedException>()),
    );
  });

  test('edited payload fails the signature', () async {
    final signed = await signPayload(payload('d'), seed);
    final edited = utf8.decode(signed.payload).replaceFirst('h:443', 'x:443');
    expect(
      () => verifyPayload(
        SignedPayload(
          keyId: signed.keyId,
          payload: Uint8List.fromList(utf8.encode(edited)),
          signature: signed.signature,
        ),
        trustedKeys: {},
        deviceFingerprint: 'd',
      ),
      throwsA(isA<SealedException>()),
    );
    expect(
      () async => verifyPayload(
        SignedPayload(
          keyId: signed.keyId,
          payload: Uint8List.fromList(utf8.encode(edited)),
          signature: signed.signature,
        ),
        trustedKeys: await trusted(),
        deviceFingerprint: 'd',
      ),
      throwsA(
        isA<SealedException>().having(
          (e) => e.message,
          'message',
          contains('Signature'),
        ),
      ),
    );
  });

  test('wrong device and expiry are rejected', () async {
    final keys = await trusted();
    final signed = await signPayload(payload('d'), seed);
    expect(
      () =>
          verifyPayload(signed, trustedKeys: keys, deviceFingerprint: 'other'),
      throwsA(isA<SealedException>()),
    );
    final old = await signPayload(
      payload('d', ttl: const Duration(seconds: -1)),
      seed,
    );
    expect(
      () => verifyPayload(old, trustedKeys: keys, deviceFingerprint: 'd'),
      throwsA(isA<SealedException>()),
    );
  });

  test('rejects points off the curve', () async {
    final bad = Uint8List(65)
      ..[0] = 4
      ..[64] = 1;
    expect(() => seal(bad, [1]), throwsA(isA<SealedException>()));
  });

  group('encrypted links', () {
    const link = PremiumLink(
      subscriptionUrl:
          'https://www.google.com/sub#Gold?resolve-address=www.google.com'
          '&host=drive.example',
      token: 'tok123',
    );

    test('only the link key opens them, and nothing shows outside', () async {
      final (priv, pub) = generateDeviceKey();
      final text = await encryptLink(link, pub);
      expect(text, startsWith('wanx://'));
      expect(text, isNot(contains('crypt')));
      expect(text, isNot(contains('google')));
      expect(isEncryptedLink(text), isTrue);
      final back = await decryptLink(text, privateKey: priv, publicKey: pub);
      expect(back.subscriptionUrl, link.subscriptionUrl);
      expect(back.token, 'tok123');
      final (otherPriv, otherPub) = generateDeviceKey();
      expect(
        () => decryptLink(text, privateKey: otherPriv, publicKey: otherPub),
        throwsA(isA<SealedException>()),
      );
    });

    test('damaged or foreign links are rejected', () async {
      final (priv, pub) = generateDeviceKey();
      final text = await encryptLink(link, pub);
      for (final bad in [
        'https://wanx.dev/s/abc',
        'wanx://!!!',
        'wanx://AAAA',
        '${text.substring(0, text.length - 4)}AAAA',
      ]) {
        await expectLater(
          decryptLink(bad, privateKey: priv, publicKey: pub),
          throwsA(isA<SealedException>()),
          reason: bad,
        );
      }
    });
  });

  group('endpoint list', () {
    final seed = List.generate(32, (i) => i);
    Future<Map<String, List<int>>> trusted(List<int> seed) async {
      final pair = await Ed25519().newKeyPairFromSeed(seed);
      final pub = (await pair.extractPublicKey()).bytes;
      return {await signingKeyId(pub): pub};
    }

    test('signed lists verify; edited or foreign ones do not', () async {
      final list = EndpointList(
        issuedAt: DateTime.utc(2026, 11, 1),
        endpoints: [
          'https://wanx.dev',
          'https://wanx.dev#?endpoint=www.google.com&header_host=x.run.app',
        ],
      );
      final text = await signEndpoints(list, seed);
      final back = await verifyEndpoints(
        text,
        trustedKeys: await trusted(seed),
      );
      expect(back.endpoints, list.endpoints);
      expect(back.issuedAt, list.issuedAt);

      final edited = text.replaceFirst('"sig":"', '"sig":"A');
      await expectLater(
        verifyEndpoints(edited, trustedKeys: await trusted(seed)),
        throwsA(isA<SealedException>()),
      );
      await expectLater(
        verifyEndpoints(text, trustedKeys: await trusted(List.filled(32, 9))),
        throwsA(isA<SealedException>()),
      );
    });
  });
}
