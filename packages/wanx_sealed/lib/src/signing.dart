import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'envelope.dart';

final _ed25519 = Ed25519();

/// Short id of a service signing key: base64url(SHA-256(public key))[:11].
Future<String> signingKeyId(List<int> publicKey) async {
  final hash = await Sha256().hash(publicKey);
  return base64Url.encode(hash.bytes).substring(0, 11);
}

/// Service side: signs [payload] with the Ed25519 key derived from [seed].
Future<SignedPayload> signPayload(SealedPayload payload, List<int> seed) async {
  final pair = await _ed25519.newKeyPairFromSeed(seed);
  final publicKey = await pair.extractPublicKey();
  final bytes = payload.encode();
  final signature = await _ed25519.sign(bytes, keyPair: pair);
  return SignedPayload(
    keyId: await signingKeyId(publicKey.bytes),
    payload: bytes,
    signature: Uint8List.fromList(signature.bytes),
  );
}

/// App side: checks the signature against [trustedKeys] (key id → Ed25519
/// public key), then that the payload is for [deviceFingerprint] and not
/// expired. Throws [SealedException] on any mismatch.
Future<SealedPayload> verifyPayload(
  SignedPayload signed, {
  required Map<String, List<int>> trustedKeys,
  required String deviceFingerprint,
  DateTime? now,
}) async {
  final key = trustedKeys[signed.keyId];
  if (key == null) throw SealedException('Signed by an unknown key');
  final ok = await _ed25519.verify(
    signed.payload,
    signature: Signature(
      signed.signature,
      publicKey: SimplePublicKey(key, type: KeyPairType.ed25519),
    ),
  );
  if (!ok) throw SealedException('Signature does not match');
  final payload = SealedPayload.decode(signed.payload);
  if (payload.device != deviceFingerprint) {
    throw SealedException('Sealed for another device');
  }
  if (!(now ?? DateTime.now()).isBefore(payload.expiresAt)) {
    throw SealedException('Sealed subscription expired');
  }
  return payload;
}
