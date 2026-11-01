/// Sealed subscriptions: a premium provider's subscription URL, signed by
/// the WanX publisher service and encrypted to one device's hardware-held
/// key once the link passed the premium check and its import limit.
///
/// Layers, outside in:
///  1. [SealedEnvelope] — ECIES to the device's P-256 key
///     (ECDH → HKDF-SHA256 → AES-256-GCM). Only that device can open it.
///  2. [SignedPayload] — Ed25519 signature by the service, checked against
///     keys pinned in the app. Nobody can edit or forge the contents.
///  3. [SealedPayload] — the provider's subscription URL plus its device
///     binding and expiry.
library;

export 'src/ecies.dart';
export 'src/endpoints.dart';
export 'src/envelope.dart';
export 'src/link.dart';
export 'src/signing.dart';
