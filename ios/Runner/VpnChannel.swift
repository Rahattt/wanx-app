import Flutter
import Libbox
import NetworkExtension
import UIKit

/// Native side of lib/core/platform/vpn_channel.dart.
/// Controls the PacketTunnel extension through NETunnelProviderManager.
final class VpnChannel: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let tunnelBundleId = "com.wanx.wanx.PacketTunnel"
  static let appGroup = "group.com.wanx.wanx"
  // Under Library/ so it can be pulled with `devicectl device copy from`.
  static let configFileName = "Library/Caches/config.json"
  static let deadlineFileName = "Library/Caches/deadline"

  private var manager: NETunnelProviderManager?
  private var eventSink: FlutterEventSink?
  private var statusObserver: NSObjectProtocol?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VpnChannel()
    let methods = FlutterMethodChannel(name: "com.wanx/vpn", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "com.wanx/vpn/status", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
    FlutterEventChannel(name: "com.wanx/vpn/traffic", binaryMessenger: registrar.messenger())
      .setStreamHandler(TrafficMonitor())
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        switch call.method {
        case "requestNotificationPermission":
          // Nothing to ask for: iOS shows VPN status itself and the app
          // posts no notifications.
          result(false)
        case "prepare":
          _ = try await loadManager(createIfMissing: true)
          result(true)
        case "start":
          guard let args = call.arguments as? [String: Any],
                let config = args["config"] as? String else {
            return result(FlutterError(code: "BAD_ARGS", message: "config is required", details: nil))
          }
          try await start(
            config: config,
            checkWindowMs: (args["checkWindowMs"] as? NSNumber)?.int64Value,
            deadlineMessage: args["deadlineMessage"] as? String
          )
          result(nil)
        case "clearDeadline":
          if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(Self.deadlineFileName))
          }
          if let session = try await loadManager(createIfMissing: false)?.connection as? NETunnelProviderSession,
             session.status == .connected {
            try? session.sendProviderMessage(Data("clearDeadline".utf8)) { _ in }
          }
          result(nil)
        case "stop":
          try await loadManager(createIfMissing: false)?.connection.stopVPNTunnel()
          result(nil)
        case "status":
          let manager = try await loadManager(createIfMissing: false)
          result(Self.event(for: manager?.connection.status ?? .disconnected))
        case "testLatency":
          guard let args = call.arguments as? [String: Any],
                let outbound = args["outbound"] as? String else {
            return result(FlutterError(code: "BAD_ARGS", message: "outbound is required", details: nil))
          }
          let dns = args["dnsServer"] as? String ?? LatencyProbe.defaultDNS
          let url = args["url"] as? String ?? LatencyProbe.defaultURL
          let timeoutMs = args["timeoutMs"] as? Int ?? 5000
          let deliver: (LatencyProbe.Outcome) -> Void = { outcome in
            switch outcome {
            case .delay(let ms): result(ms)
            case .failed: result(nil)
            case .unsupported(let reason):
              result(FlutterError(code: "UNSUPPORTED", message: reason, details: nil))
            case .unavailable(let reason):
              result(FlutterError(code: "UNAVAILABLE", message: reason, details: nil))
            }
          }
          // With the VPN up, this app's sockets are forced into the tunnel,
          // so the extension runs the probe instead.
          if let session = try await loadManager(createIfMissing: false)?.connection as? NETunnelProviderSession,
             session.status == .connected {
            let message = LatencyProbe.message(outbound: outbound, dnsServer: dns, url: url, timeoutMs: timeoutMs)
            try session.sendProviderMessage(message) { reply in
              DispatchQueue.main.async { deliver(LatencyProbe.outcome(fromReply: reply)) }
            }
          } else {
            LatencyProbe.test(outboundJson: outbound, dnsServer: dns, url: url, timeoutMs: timeoutMs, completion: deliver)
          }
        case "version":
          // The app embeds the same Libbox.framework as the extension.
          result(LibboxVersion())
        case "deviceInfo":
          result(DeviceIdentity.info())
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "VPN_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }

  @MainActor
  /// [checkWindowMs]: see PacketTunnelProvider.deadlineFileName.
  private func start(config: String, checkWindowMs: Int64?, deadlineMessage: String?) async throws {
    guard let manager = try await loadManager(createIfMissing: true) else { return }
    // Persist the config in the App Group so the extension can also start
    // on its own (On Demand, system Settings toggle).
    let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
    if let dir {
      let file = dir.appendingPathComponent(Self.configFileName)
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try config.write(to: file, atomically: true, encoding: .utf8)
      let deadlineFile = dir.appendingPathComponent(Self.deadlineFileName)
      if let checkWindowMs, checkWindowMs > 0 {
        try String(checkWindowMs).write(to: deadlineFile, atomically: true, encoding: .utf8)
      } else {
        try? FileManager.default.removeItem(at: deadlineFile)
      }
    }
    if !manager.isEnabled {
      manager.isEnabled = true
      try await manager.saveToPreferences()
      try await manager.loadFromPreferences()
    }
    var options: [String: NSObject] = ["config": config as NSString]
    if let deadlineMessage { options["deadlineMessage"] = deadlineMessage as NSString }
    try manager.connection.startVPNTunnel(options: options)
  }

  /// Loads (or installs) the VPN profile. Installing triggers the system
  /// "Allow VPN configuration" prompt on first use.
  @MainActor
  @discardableResult
  private func loadManager(createIfMissing: Bool) async throws -> NETunnelProviderManager? {
    if let manager { return manager }
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    if let existing = managers.first {
      attach(existing)
      return existing
    }
    guard createIfMissing else { return nil }

    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = Self.tunnelBundleId
    proto.serverAddress = "sing-box"
    let manager = NETunnelProviderManager()
    manager.localizedDescription = "WanX"
    manager.protocolConfiguration = proto
    manager.isEnabled = true
    try await manager.saveToPreferences()
    // Required after the first save, otherwise startVPNTunnel fails with
    // NEVPNErrorConfigurationInvalid.
    try await manager.loadFromPreferences()
    attach(manager)
    return manager
  }

  @MainActor
  private func attach(_ manager: NETunnelProviderManager) {
    self.manager = manager
    if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
    statusObserver = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange, object: manager.connection, queue: .main
    ) { [weak self] _ in
      self?.emitStatus()
    }
    emitStatus()
  }

  private func emitStatus() {
    guard let sink = eventSink, let connection = manager?.connection else { return }
    let status = connection.status
    if status == .disconnected, #available(iOS 16.0, *) {
      connection.fetchLastDisconnectError { error in
        DispatchQueue.main.async {
          sink(Self.event(for: status, error: error?.localizedDescription))
        }
      }
    } else {
      sink(Self.event(for: status))
    }
  }

  private static func event(for status: NEVPNStatus, error: String? = nil) -> [String: Any?] {
    let wire: String
    switch status {
    case .connected: wire = "connected"
    case .connecting, .reasserting: wire = "connecting"
    case .disconnecting: wire = "disconnecting"
    case .invalid, .disconnected: wire = error == nil ? "disconnected" : "error"
    @unknown default: wire = "disconnected"
    }
    return ["status": wire, "error": error]
  }

  // MARK: FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    Task { @MainActor in
      if (try? await loadManager(createIfMissing: false)) == nil {
        events(Self.event(for: .disconnected))
      }
      emitStatus()
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

/// Stable device identity sent with subscription requests (HWID), so
/// panels can enforce per-device limits.
enum DeviceIdentity {
  private static let service = "com.wanx.wanx.hwid"

  static func info() -> [String: String] {
    var system = utsname()
    uname(&system)
    let model = withUnsafeBytes(of: &system.machine) { raw in
      String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
    }
    return [
      "hwid": hwid(),
      "os": "iOS",
      "osVersion": UIDevice.current.systemVersion,
      "model": model,
    ]
  }

  /// 16 lowercase hex characters, like Happ. Kept in the Keychain so it
  /// survives reinstalls and doesn't take a new device slot on the panel.
  private static func hwid() -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecReturnData as String: true,
    ]
    var item: CFTypeRef?
    if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
       let data = item as? Data, let id = String(data: data, encoding: .utf8),
       isValid(id) {
      return id
    }
    // Replaces an ID saved in an older format.
    SecItemDelete([
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ] as CFDictionary)
    let uuid = (UIDevice.current.identifierForVendor ?? UUID()).uuidString
    let id = String(uuid.replacingOccurrences(of: "-", with: "").lowercased().prefix(16))
    SecItemAdd([
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: Data(id.utf8),
    ] as CFDictionary, nil)
    return id
  }

  private static func isValid(_ id: String) -> Bool {
    id.count == 16 && id.allSatisfy { $0.isHexDigit && !$0.isUppercase }
  }
}

/// Streams live traffic of the running tunnel to Flutter as
/// {uplink, downlink (bytes/s), uplinkTotal, downlinkTotal}, once a second.
/// Connects to the extension's libbox command server over the App Group
/// socket and keeps retrying while listened to, since the tunnel may still
/// be starting.
final class TrafficMonitor: NSObject, FlutterStreamHandler, LibboxCommandClientHandlerProtocol,
  @unchecked Sendable
{
  private let queue = DispatchQueue(label: "com.wanx.traffic")
  private var client: LibboxCommandClient?
  private var sink: FlutterEventSink?
  private var listening = false

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    queue.async {
      self.listening = true
      self.connect()
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    queue.async {
      self.listening = false
      try? self.client?.disconnect()
      self.client = nil
    }
    return nil
  }

  /// Runs on [queue].
  private func connect() {
    guard listening, client == nil else { return }
    do {
      try LatencyProbe.setup()
      let options = LibboxCommandClientOptions()
      options.addCommand(LibboxCommandStatus)
      options.statusInterval = Int64(NSEC_PER_SEC)
      guard let client = LibboxNewCommandClient(self, options) else { return retry() }
      self.client = client
      try client.connect()
    } catch {
      client = nil
      retry()
    }
  }

  private func retry() {
    queue.asyncAfter(deadline: .now() + 2) { self.connect() }
  }

  func connected() {}

  func disconnected(_ message: String?) {
    queue.async {
      self.client = nil
      self.retry()
    }
  }

  func writeStatus(_ message: LibboxStatusMessage?) {
    guard let message, message.trafficAvailable else { return }
    let event: [String: Int64] = [
      "uplink": message.uplink, "downlink": message.downlink,
      "uplinkTotal": message.uplinkTotal, "downlinkTotal": message.downlinkTotal,
    ]
    DispatchQueue.main.async { self.sink?(event) }
  }

  func clearLogs() {}
  func initializeClashMode(_ modeList: (any LibboxStringIteratorProtocol)?, currentMode: String?) {}
  func setDefaultLogLevel(_ level: Int32) {}
  func updateClashMode(_ newMode: String?) {}
  func write(_ events: LibboxConnectionEvents?) {}
  func write(_ query: LibboxDnsQuery?) {}
  func writeGroups(_ message: (any LibboxOutboundGroupIteratorProtocol)?) {}
  func writeLogs(_ messageList: (any LibboxLogIteratorProtocol)?) {}
  func writeOutbounds(_ message: (any LibboxOutboundGroupItemIteratorProtocol)?) {}
}
