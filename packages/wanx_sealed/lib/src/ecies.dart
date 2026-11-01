import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' as pc;

import 'envelope.dart';

/// ECIES over P-256, chosen because it is what Secure Enclave and Android
/// Keystore can hold. Native openers (`SealedKeys.swift`, `SealedKeys.kt`)
/// must match exactly:
///
///  - shared secret: ECDH x-coordinate, 32 bytes big-endian
///  - key: HKDF-SHA256, empty salt, info = [eciesInfo] ‖ epk ‖ recipient
///    public key (both uncompressed, 65 bytes), 32 bytes out
///  - AES-256-GCM, 12-byte random nonce, no AAD, 16-byte tag appended
const eciesInfo = 'wanx-sealed-v1';

final _domain = pc.ECDomainParameters('prime256v1');
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
final _aes = AesGcm.with256bits();

/// Encrypts [plaintext] so only the holder of [recipientKey]'s private half
/// can read it. [recipientKey] is an uncompressed P-256 point.
Future<SealedEnvelope> seal(Uint8List recipientKey, List<int> plaintext) async {
  final recipient = _publicKey(recipientKey);
  final generator = pc.ECKeyGenerator()
    ..init(
      pc.ParametersWithRandom(pc.ECKeyGeneratorParameters(_domain), _random()),
    );
  final pair = generator.generateKeyPair();
  final ephemeral = pair.privateKey as pc.ECPrivateKey;
  final epk = (pair.publicKey as pc.ECPublicKey).Q!.getEncoded(false);
  final key = await _deriveKey(_agree(ephemeral, recipient), epk, recipientKey);
  final nonce = _aes.newNonce();
  final box = await _aes.encrypt(plaintext, secretKey: key, nonce: nonce);
  return SealedEnvelope(
    ephemeralKey: epk,
    nonce: Uint8List.fromList(nonce),
    ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
  );
}

/// Software counterpart of the native openers, for tests and tooling.
/// [privateKey] is the 32-byte scalar; [publicKey] its uncompressed point.
Future<Uint8List> open(
  SealedEnvelope envelope, {
  required Uint8List privateKey,
  required Uint8List publicKey,
}) async {
  final d = pc.ECPrivateKey(_toBigInt(privateKey), _domain);
  final key = await _deriveKey(
    _agree(d, _publicKey(envelope.ephemeralKey)),
    envelope.ephemeralKey,
    publicKey,
  );
  final ct = envelope.ciphertext;
  if (ct.length < 16) throw SealedException('Ciphertext too short');
  try {
    final clear = await _aes.decrypt(
      SecretBox(
        ct.sublist(0, ct.length - 16),
        nonce: envelope.nonce,
        mac: Mac(ct.sublist(ct.length - 16)),
      ),
      secretKey: key,
    );
    return Uint8List.fromList(clear);
  } on SecretBoxAuthenticationError {
    throw SealedException('Envelope does not open with this key');
  }
}

/// A fresh software key pair: (32-byte scalar, uncompressed public key).
/// Devices keep theirs in hardware; this is for tests and tooling.
(Uint8List, Uint8List) generateDeviceKey() {
  final generator = pc.ECKeyGenerator()
    ..init(
      pc.ParametersWithRandom(pc.ECKeyGeneratorParameters(_domain), _random()),
    );
  final pair = generator.generateKeyPair();
  return (
    _fromBigInt((pair.privateKey as pc.ECPrivateKey).d!),
    (pair.publicKey as pc.ECPublicKey).Q!.getEncoded(false),
  );
}

/// Stable id of a device key: base64url(SHA-256(uncompressed point)).
Future<String> deviceFingerprint(Uint8List publicKey) async {
  final hash = await Sha256().hash(publicKey);
  return base64Url.encode(hash.bytes).replaceAll('=', '');
}

/// Throws [SealedException] unless [publicKey] is a valid uncompressed
/// P-256 point.
void checkDeviceKey(Uint8List publicKey) => _publicKey(publicKey);

/// Rejects anything but a valid uncompressed point on P-256.
pc.ECPublicKey _publicKey(Uint8List bytes) {
  if (bytes.length != 65 || bytes[0] != 0x04) {
    throw SealedException('Device key must be an uncompressed P-256 point');
  }
  final pc.ECPoint? point;
  try {
    point = _domain.curve.decodePoint(bytes);
  } on Object {
    throw SealedException('Device key is not on P-256');
  }
  if (point == null || point.isInfinity || !_onCurve(point)) {
    throw SealedException('Device key is not on P-256');
  }
  return pc.ECPublicKey(point, _domain);
}

/// P-256 field prime: 2^256 − 2^224 + 2^192 + 2^96 − 1.
final _p256Prime =
    (BigInt.one << 256) -
    (BigInt.one << 224) +
    (BigInt.one << 192) +
    (BigInt.one << 96) -
    BigInt.one;

bool _onCurve(pc.ECPoint p) {
  final x = p.x!.toBigInteger()!;
  final y = p.y!.toBigInteger()!;
  final a = _domain.curve.a!.toBigInteger()!;
  final b = _domain.curve.b!.toBigInteger()!;
  return (y * y - (x * x * x + a * x + b)) % _p256Prime == BigInt.zero;
}

Uint8List _agree(pc.ECPrivateKey private, pc.ECPublicKey public) {
  final agreement = pc.ECDHBasicAgreement()..init(private);
  return _fromBigInt(agreement.calculateAgreement(public));
}

Future<SecretKey> _deriveKey(
  Uint8List shared,
  Uint8List epk,
  Uint8List recipient,
) => _hkdf.deriveKey(
  secretKey: SecretKey(shared),
  nonce: const [],
  info: [...utf8.encode(eciesInfo), ...epk, ...recipient],
);

pc.SecureRandom _random() {
  final seed = Random.secure();
  return pc.FortunaRandom()..seed(
    pc.KeyParameter(
      Uint8List.fromList(List.generate(32, (_) => seed.nextInt(256))),
    ),
  );
}

BigInt _toBigInt(Uint8List bytes) =>
    bytes.fold(BigInt.zero, (n, b) => (n << 8) | BigInt.from(b));

/// 32 bytes big-endian, left-padded.
Uint8List _fromBigInt(BigInt n) {
  final out = Uint8List(32);
  for (var i = 31; i >= 0; i--) {
    out[i] = (n & BigInt.from(0xff)).toInt();
    n >>= 8;
  }
  return out;
}
