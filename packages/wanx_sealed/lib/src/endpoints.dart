import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'envelope.dart';
import 'signing.dart';

final _ed25519 = Ed25519();

/// Where the app checks premium links: base URLs, each optionally with
/// `#?endpoint=…&header_host=…` fronting hints (e.g. Cloud Run behind
/// google.com). Signed by the service key so a copy can be served from
/// anywhere (our site, Cloud Run, GitHub Pages) and still be trusted; the
/// newest by [issuedAt] wins.
class EndpointList {
  const EndpointList({required this.issuedAt, required this.endpoints});

  final DateTime issuedAt;
  final List<String> endpoints;
}

Future<String> signEndpoints(EndpointList list, List<int> seed) async {
  final pair = await _ed25519.newKeyPairFromSeed(seed);
  final payload = utf8.encode(
    jsonEncode({
      'v': 1,
      'iat': list.issuedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
      'endpoints': list.endpoints,
    }),
  );
  final signature = await _ed25519.sign(payload, keyPair: pair);
  return jsonEncode({
    'kid': await signingKeyId((await pair.extractPublicKey()).bytes),
    'payload': base64.encode(payload),
    'sig': base64.encode(signature.bytes),
  });
}

/// Throws [SealedException] unless [text] is a list signed by one of
/// [trustedKeys] (key id → Ed25519 public key).
Future<EndpointList> verifyEndpoints(
  String text, {
  required Map<String, List<int>> trustedKeys,
}) async {
  final bad = SealedException('Endpoint list is not valid');
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw bad;
  }
  if (json case {
    'kid': final String kid,
    'payload': final String payload,
    'sig': final String sig,
  }) {
    final key = trustedKeys[kid];
    if (key == null) throw SealedException('Signed by an unknown key');
    final Uint8List bytes, signature;
    try {
      bytes = base64.decode(payload);
      signature = base64.decode(sig);
    } on FormatException {
      throw bad;
    }
    final ok = await _ed25519.verify(
      bytes,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(key, type: KeyPairType.ed25519),
      ),
    );
    if (!ok) throw SealedException('Signature does not match');
    try {
      if (jsonDecode(utf8.decode(bytes)) case {
        'v': 1,
        'iat': final int iat,
        'endpoints': final List endpoints,
      }) {
        return EndpointList(
          issuedAt: DateTime.fromMillisecondsSinceEpoch(
            iat * 1000,
            isUtc: true,
          ),
          endpoints: [
            for (final e in endpoints)
              if (e is String) e,
          ],
        );
      }
    } on FormatException {
      // Reported below.
    }
  }
  throw bad;
}
