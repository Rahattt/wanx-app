import 'dart:convert';
import 'dart:typed_data';

/// Version of every layer below; bumped on any incompatible change.
const sealedVersion = 2;

/// What the service answers a plain GET of a sealed link with, so a client
/// knows to register its device key instead of parsing the body.
const sealedContentType = 'application/vnd.wanx.sealed+json';

class SealedException implements Exception {
  SealedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// ECIES ciphertext addressed to one device key.
class SealedEnvelope {
  const SealedEnvelope({
    required this.ephemeralKey,
    required this.nonce,
    required this.ciphertext,
  });

  /// Sender's one-off P-256 public key, uncompressed (65 bytes).
  final Uint8List ephemeralKey;

  /// AES-GCM nonce (12 bytes).
  final Uint8List nonce;

  /// AES-GCM ciphertext followed by its 16-byte tag.
  final Uint8List ciphertext;

  Map<String, Object> toJson() => {
    'v': sealedVersion,
    'epk': base64.encode(ephemeralKey),
    'nonce': base64.encode(nonce),
    'ct': base64.encode(ciphertext),
  };

  String encode() => jsonEncode(toJson());

  factory SealedEnvelope.decode(String text) {
    final json = _object(text, 'envelope');
    _checkVersion(json);
    return SealedEnvelope(
      ephemeralKey: _bytes(json, 'epk', length: 65),
      nonce: _bytes(json, 'nonce', length: 12),
      ciphertext: _bytes(json, 'ct'),
    );
  }
}

/// [payload] bytes with the service's signature over exactly those bytes.
class SignedPayload {
  const SignedPayload({
    required this.keyId,
    required this.payload,
    required this.signature,
  });

  /// Which pinned service key signed it.
  final String keyId;
  final Uint8List payload;
  final Uint8List signature;

  String encode() => jsonEncode({
    'v': sealedVersion,
    'kid': keyId,
    'payload': base64.encode(payload),
    'sig': base64.encode(signature),
  });

  factory SignedPayload.decode(String text) {
    final json = _object(text, 'signed payload');
    _checkVersion(json);
    final kid = json['kid'];
    if (kid is! String || kid.isEmpty) throw SealedException('Missing kid');
    return SignedPayload(
      keyId: kid,
      payload: _bytes(json, 'payload'),
      signature: _bytes(json, 'sig', length: 64),
    );
  }
}

/// What the provider publishes, bound to one device for a limited time.
class SealedPayload {
  const SealedPayload({
    required this.subscriptionId,
    required this.name,
    required this.provider,
    required this.device,
    required this.issuedAt,
    required this.expiresAt,
    required this.body,
  });

  /// Service-side subscription id; stable across refreshes.
  final String subscriptionId;

  /// Display name for the server group.
  final String name;

  /// Provider's display name.
  final String provider;

  /// [deviceFingerprint] of the key this was sealed to.
  final String device;
  final DateTime issuedAt;

  /// After this the app stops using the servers until it refreshes.
  final DateTime expiresAt;

  /// The provider's own subscription URL. The app downloads the configs
  /// from it directly; the service only vouches that the link is premium
  /// and within its import limit.
  final String body;

  Uint8List encode() => utf8.encode(
    jsonEncode({
      'v': sealedVersion,
      'sub': subscriptionId,
      'name': name,
      'provider': provider,
      'device': device,
      'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      'body': body,
    }),
  );

  factory SealedPayload.decode(Uint8List bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw SealedException('Payload is not UTF-8');
    }
    final json = _object(text, 'payload');
    _checkVersion(json);
    String str(String key) => switch (json[key]) {
      final String s => s,
      _ => throw SealedException('Payload has no "$key"'),
    };
    DateTime time(String key) => switch (json[key]) {
      final int s => DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true),
      _ => throw SealedException('Payload has no "$key"'),
    };
    return SealedPayload(
      subscriptionId: str('sub'),
      name: str('name'),
      provider: str('provider'),
      device: str('device'),
      issuedAt: time('iat'),
      expiresAt: time('exp'),
      body: str('body'),
    );
  }
}

Map<String, dynamic> _object(String text, String what) {
  try {
    final json = jsonDecode(text);
    if (json is Map<String, dynamic>) return json;
  } on FormatException {
    // Reported below.
  }
  throw SealedException('Malformed $what');
}

void _checkVersion(Map<String, dynamic> json) {
  if (json['v'] != sealedVersion) {
    throw SealedException('Unsupported sealed version ${json['v']}');
  }
}

Uint8List _bytes(Map<String, dynamic> json, String key, {int? length}) {
  final value = json[key];
  if (value is String) {
    try {
      final bytes = base64.decode(value);
      if (length == null || bytes.length == length) return bytes;
    } on FormatException {
      // Reported below.
    }
  }
  throw SealedException('Bad "$key"');
}
