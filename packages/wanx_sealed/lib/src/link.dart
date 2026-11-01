import 'dart:convert';
import 'dart:typed_data';

import 'ecies.dart';
import 'envelope.dart';

/// Scheme of the links WanX opens; the app registers it with the OS.
const linkScheme = 'wanx';

/// Format byte at the start of the encoded data, so it can change later
/// without the link looking any different.
const _linkFormat = 2;

/// What a premium link carries: the provider's own subscription URL (with
/// its fronting hints, if any) and the token the WanX service checks. No
/// WanX address is inside: the app knows where to check.
class PremiumLink {
  const PremiumLink({required this.subscriptionUrl, required this.token});

  final String subscriptionUrl;
  final String token;
}

/// `wanx://<base64url(format ‖ epk ‖ nonce ‖ ciphertext+tag)>`, ECIES (see
/// [seal]) to the link key whose private half ships inside the app. Hides
/// the contents from people and from other clients; it is not a secret
/// from someone who takes the app apart.
bool isEncryptedLink(String text) =>
    text.trim().toLowerCase().startsWith('$linkScheme://');

Future<String> encryptLink(PremiumLink link, Uint8List linkPublicKey) async {
  final e = await seal(
    linkPublicKey,
    utf8.encode(jsonEncode({'u': link.subscriptionUrl, 't': link.token})),
  );
  final bytes = [_linkFormat, ...e.ephemeralKey, ...e.nonce, ...e.ciphertext];
  return '$linkScheme://${base64Url.encode(bytes).replaceAll('=', '')}';
}

/// Reverses [encryptLink]. Throws [SealedException] for anything else.
Future<PremiumLink> decryptLink(
  String link, {
  required Uint8List privateKey,
  required Uint8List publicKey,
}) async {
  if (!isEncryptedLink(link)) throw SealedException('Not a WanX link');
  final damaged = SealedException('WanX link is damaged');
  final Uint8List bytes;
  try {
    bytes = base64Url.decode(
      base64Url.normalize(link.trim().substring(linkScheme.length + 3)),
    );
  } on FormatException {
    throw damaged;
  }
  if (bytes.length < 1 + 65 + 12 + 16) throw damaged;
  if (bytes[0] != _linkFormat) {
    throw SealedException('This WanX link needs a newer app');
  }
  final clear = await open(
    SealedEnvelope(
      ephemeralKey: bytes.sublist(1, 66),
      nonce: bytes.sublist(66, 78),
      ciphertext: bytes.sublist(78),
    ),
    privateKey: privateKey,
    publicKey: publicKey,
  );
  try {
    final json = jsonDecode(utf8.decode(clear));
    if (json case {'u': final String u, 't': final String t}
        when u.isNotEmpty && t.isNotEmpty) {
      return PremiumLink(subscriptionUrl: u, token: t);
    }
  } on FormatException {
    // Reported below.
  }
  throw damaged;
}
