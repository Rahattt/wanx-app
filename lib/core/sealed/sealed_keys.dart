import 'package:flutter/services.dart';
import 'package:wanx_sealed/wanx_sealed.dart';

/// This device's hardware-held key for sealed subscriptions.
///
/// Native counterparts (channel `com.wanx/sealed`):
///  - iOS:     `ios/Runner/SealedKeys.swift` (Secure Enclave)
///  - Android: `android/app/src/main/kotlin/com/wanx/wanx/sealed/SealedKeys.kt`
///             (Android Keystore)
class SealedKeys {
  static const _channel = MethodChannel('com.wanx/sealed');

  Uint8List? _publicKey;

  /// Uncompressed P-256 point; the key is created on first use.
  Future<Uint8List> publicKey() async =>
      _publicKey ??= (await _call<Uint8List>('publicKey'))!;

  /// Decrypts [envelope] inside the secure hardware.
  Future<Uint8List> open(SealedEnvelope envelope) async =>
      (await _call<Uint8List>('open', {
        'epk': envelope.ephemeralKey,
        'nonce': envelope.nonce,
        'ct': envelope.ciphertext,
      }))!;

  /// Blocks screenshots and screen recording while sealed servers are
  /// present. Android only; iOS offers no such switch.
  Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // iOS.
    }
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw SealedException(e.message ?? e.code);
    }
  }
}
