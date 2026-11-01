/// Ed25519 keys of the WanX publisher service (`server/`), by key id.
/// A sealed subscription is accepted only if one of these signed it.
///
/// Add a key with `dart run bin/keygen.dart` in `server/`; keep retired
/// keys here until every sealed copy they signed has expired.
const publisherKeys = <String, String>{
  // Production key on wanx.dev (/etc/wanx/signing.key).
  '8zRCm-o2g1N': 'vzfTRJWvjxw5xu9sJ4PRBefV3VnfmFlWT5A/PjN0YqU=',
  // Backup key, kept offline: the way back if the production key is lost.
  '_VkhQNxiiOA': 'YDRcEy3WXa8t5QhyowK6Yjmrh180QoIaf+vbCTT6PHo=',
};
