import 'dart:math';

/// AmneziaWG obfuscation on a WireGuard endpoint (sing-box-lx `with_awg`).
///
/// Junk packets (`jc`/`jmin`/`jmax`) and decoys (`i1`–`i5`) are sent before
/// the handshake and are dropped by a plain WireGuard server, so they can be
/// added to any profile. The rest (`s1`–`s4`, `h1`–`h4`, the header
/// protection key) change the packets themselves and must match an
/// AmneziaWG server.
abstract final class WireGuardObfuscation {
  /// Amnezia's default decoy: a DNS response for icloud.com
  /// (`defaultSpecialJunk1` in amnezia-client protocolConstants.h).
  static const amneziaI1 =
      '<r 2><b 0x858000010001000000000669636c6f756403636f6d0000010001c00c000100010000105a00044d583737>';

  static const clientKeys = {
    'jc',
    'jmin',
    'jmax',
    'i1',
    'i2',
    'i3',
    'i4',
    'i5',
  };
  static const serverKeys = {
    's1',
    's2',
    's3',
    's4',
    'h1',
    'h2',
    'h3',
    'h4',
    'header_protection_key',
  };

  /// Settings that only an AmneziaWG server accepts.
  static bool needsAmneziaServer(Map<String, dynamic> settings) =>
      serverKeys.any((k) => _isSet(k, settings[k]));

  static bool isEnabled(Map<String, dynamic> settings) =>
      needsAmneziaServer(settings) ||
      clientKeys.any((k) => _isSet(k, settings[k]));

  /// What the Amnezia client adds when a plain WireGuard config is imported
  /// with obfuscation on (ImportController::processNativeWireGuardConfig):
  /// 4–6 junk packets of 10–50 bytes and the DNS decoy. S/H stay at the
  /// WireGuard defaults, so the server needs no change.
  static Map<String, dynamic> enable(
    Map<String, dynamic> settings, {
    Random? random,
  }) {
    if (isEnabled(settings)) return settings;
    return {
      ...settings,
      'jc': 4 + (random ?? Random.secure()).nextInt(3),
      'jmin': 10,
      'jmax': 50,
      'i1': amneziaI1,
    };
  }

  /// Removes the client-side obfuscation. Server-side parameters stay: the
  /// server rejects the handshake without them.
  static Map<String, dynamic> disable(Map<String, dynamic> settings) => {
    for (final e in settings.entries)
      if (!clientKeys.contains(e.key)) e.key: e.value,
  };

  /// `h1`–`h4` at 1–4 are WireGuard's own message types, and 0/"" is unset.
  static bool _isSet(String key, Object? value) {
    if (value == null || value == '' || value == 0) return false;
    if (key.length == 2 && key.startsWith('h')) {
      return '$value' != key.substring(1);
    }
    return true;
  }
}
