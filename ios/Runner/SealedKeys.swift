import CryptoKit
import Flutter
import Foundation
import Security

/// This device's key for sealed subscriptions (`packages/wanx_sealed`).
///
/// The P-256 private key is created in the Secure Enclave and never leaves
/// it; the Keychain holds only the enclave's opaque handle, marked
/// this-device-only so it is neither synced nor restored onto another
/// phone. Without an enclave (simulator) a software key is kept in the
/// Keychain instead.
///
/// Methods on [channelName]:
///  - `publicKey` → bytes: the uncompressed point (65 bytes)
///  - `open` {epk, nonce, ct: bytes} → bytes: the decrypted envelope
final class SealedKeys: NSObject, FlutterPlugin {
  static let channelName = "com.wanx/sealed"

  private static let service = "com.wanx.sealed"
  private static let account = "device-key-v1"
  private static let info = Data("wanx-sealed-v1".utf8)

  private static let lock = NSLock()
  private static var cached: DeviceKey?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SealedKeys(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "publicKey":
      run(result) { try Self.key().publicKey }
    case "open":
      guard let args = call.arguments as? [String: Any],
            let epk = (args["epk"] as? FlutterStandardTypedData)?.data,
            let nonce = (args["nonce"] as? FlutterStandardTypedData)?.data,
            let ct = (args["ct"] as? FlutterStandardTypedData)?.data else {
        return result(FlutterError(code: "BAD_ARGS", message: "epk, nonce and ct are required", details: nil))
      }
      run(result) { try Self.open(key: Self.key(), epk: epk, nonce: nonce, ct: ct) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Key work off the main thread; enclave operations can take a moment.
  private func run(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Data) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let data = try work()
        DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: data)) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "SEALED", message: "\(error)", details: nil))
        }
      }
    }
  }

  /// ECDH → HKDF-SHA256 (empty salt, info ‖ epk ‖ own key) → AES-256-GCM,
  /// exactly as `ecies.dart` seals it.
  static func open(key: DeviceKey, epk: Data, nonce: Data, ct: Data) throws -> Data {
    guard ct.count >= 16 else { throw SealedError.malformed }
    let peer = try P256.KeyAgreement.PublicKey(x963Representation: epk)
    let shared = try key.sharedSecret(with: peer)
    var sharedInfo = info
    sharedInfo.append(epk)
    sharedInfo.append(key.publicKey)
    let symmetric = shared.hkdfDerivedSymmetricKey(
      using: SHA256.self, salt: Data(), sharedInfo: sharedInfo, outputByteCount: 32)
    let box = try AES.GCM.SealedBox(
      nonce: AES.GCM.Nonce(data: nonce),
      ciphertext: ct.prefix(ct.count - 16),
      tag: ct.suffix(16))
    return try AES.GCM.open(box, using: symmetric)
  }

  private static func key() throws -> DeviceKey {
    lock.lock()
    defer { lock.unlock() }
    if let cached { return cached }
    let key = try load() ?? create()
    cached = key
    return key
  }

  private static func create() throws -> DeviceKey {
    let key: DeviceKey
    if SecureEnclave.isAvailable {
      var error: Unmanaged<CFError>?
      guard let access = SecAccessControlCreateWithFlags(
        nil, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, .privateKeyUsage, &error)
      else { throw error!.takeRetainedValue() as Error }
      key = .enclave(try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: access))
    } else {
      key = .software(P256.KeyAgreement.PrivateKey())
    }
    let status = SecItemAdd([
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData: key.stored,
    ] as CFDictionary, nil)
    guard status == errSecSuccess else { throw SealedError.keychain(status) }
    return key
  }

  private static func load() throws -> DeviceKey? {
    var item: CFTypeRef?
    let status = SecItemCopyMatching([
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
      kSecReturnData: true,
    ] as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw SealedError.keychain(status)
    }
    return try DeviceKey(stored: data)
  }
}

enum SealedError: Error {
  case malformed
  case keychain(OSStatus)
}

enum DeviceKey {
  case enclave(SecureEnclave.P256.KeyAgreement.PrivateKey)
  case software(P256.KeyAgreement.PrivateKey)

  var publicKey: Data {
    switch self {
    case .enclave(let k): return k.publicKey.x963Representation
    case .software(let k): return k.publicKey.x963Representation
    }
  }

  func sharedSecret(with peer: P256.KeyAgreement.PublicKey) throws -> SharedSecret {
    switch self {
    case .enclave(let k): return try k.sharedSecretFromKeyAgreement(with: peer)
    case .software(let k): return try k.sharedSecretFromKeyAgreement(with: peer)
    }
  }

  /// Kind byte + representation: the enclave's handle, or the raw scalar.
  var stored: Data {
    switch self {
    case .enclave(let k): return Data([1]) + k.dataRepresentation
    case .software(let k): return Data([2]) + k.rawRepresentation
    }
  }

  init(stored: Data) throws {
    let body = stored.dropFirst()
    switch stored.first {
    case 1: self = .enclave(try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: body))
    case 2: self = .software(try P256.KeyAgreement.PrivateKey(rawRepresentation: body))
    default: throw SealedError.malformed
    }
  }
}
