import Foundation
import Libbox
import Network

/// Measures a server's delay through its real sing-box outbound, independent
/// of the active tunnel: each test starts a throwaway core in the app process
/// with only that outbound plus the Clash API, calls `/proxies/test/delay`
/// (sing-box's urltest) and shuts the core down.
///
/// iOS routes an app's sockets into the packet tunnel even when they are
/// bound to en0, so while the VPN is up the probe must run inside the
/// PacketTunnel extension (whose own sockets bypass its tunnel). This file is
/// compiled into both targets; the app forwards requests with
/// `sendProviderMessage` (see [message(outbound:dnsServer:url:timeoutMs:)]).
enum LatencyProbe {
  static let defaultURL = "https://www.gstatic.com/generate_204"
  static let defaultDNS = "1.1.1.1"
  private static let outboundTag = "test"

  enum Outcome: Sendable {
    case delay(Int)
    /// Tested but unreachable, timed out or rejected by the server.
    case failed
    /// The core refused the config (e.g. protocol not built into libbox).
    case unsupported(String)
    /// Not run, e.g. too little memory left in the extension.
    case unavailable(String)
  }

  /// Set by the extension: libbox is already set up by the tunnel core, and
  /// re-running setup would move its working directories.
  static var libboxAlreadySetUp = false

  /// Optional veto before a core is started; returns a reason to refuse.
  static var admissionCheck: (() -> String?)?

  // MARK: app ↔ extension message

  static func message(outbound: String, dnsServer: String, url: String, timeoutMs: Int) -> Data {
    let payload: [String: Any] = [
      "cmd": "testLatency", "outbound": outbound, "dnsServer": dnsServer,
      "url": url, "timeoutMs": timeoutMs,
    ]
    return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
  }

  /// Extension side: runs the request in [data] if it is a latency test.
  static func handle(message data: Data) async -> Data? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          json["cmd"] as? String == "testLatency",
          let outbound = json["outbound"] as? String else { return nil }
    let outcome = await withCheckedContinuation { (cont: CheckedContinuation<Outcome, Never>) in
      test(
        outboundJson: outbound,
        dnsServer: json["dnsServer"] as? String ?? defaultDNS,
        url: json["url"] as? String ?? defaultURL,
        timeoutMs: json["timeoutMs"] as? Int ?? 5000,
        completion: { cont.resume(returning: $0) })
    }
    let reply: [String: Any] = switch outcome {
    case .delay(let ms): ["ms": ms]
    case .failed: ["failed": true]
    case .unsupported(let reason): ["unsupported": reason]
    case .unavailable(let reason): ["unavailable": reason]
    }
    return try? JSONSerialization.data(withJSONObject: reply)
  }

  /// App side: decodes the extension's reply.
  static func outcome(fromReply data: Data?) -> Outcome {
    guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return .unavailable("tunnel extension did not answer")
    }
    if let ms = json["ms"] as? Int { return .delay(ms) }
    if let reason = json["unsupported"] as? String { return .unsupported(reason) }
    if let reason = json["unavailable"] as? String { return .unavailable(reason) }
    return .failed
  }

  private static let queue = DispatchQueue(label: "com.wanx.latency", attributes: .concurrent)
  // Tests are independent; cap how many throwaway cores run at once.
  private static let slots = DispatchSemaphore(value: 4)
  // Port pick + core start must not interleave, or two cores race for a port.
  private static let startLock = NSLock()
  private static var setupDone = false

  static func test(
    outboundJson: String, dnsServer: String, url: String, timeoutMs: Int,
    completion: @escaping (Outcome) -> Void
  ) {
    queue.async {
      if let reason = admissionCheck?() {
        DispatchQueue.main.async { completion(.unavailable(reason)) }
        return
      }
      slots.wait()
      defer { slots.signal() }
      let outcome = run(outboundJson: outboundJson, dns: dnsServer, url: url, timeoutMs: timeoutMs)
      DispatchQueue.main.async { completion(outcome) }
    }
  }

  private static func run(outboundJson: String, dns: String, url: String, timeoutMs: Int) -> Outcome {
    let platform = ProbePlatform()
    var server: LibboxCommandServer?
    defer {
      if let server {
        try? server.closeService()
        server.close()
      }
      platform.stop()
    }
    let secret = UUID().uuidString
    var port: Int32 = 0
    // libbox always opens a cache file; the default cache.db is locked by the
    // tunnel core in the same process, so each probe gets its own.
    let cacheFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("probe-\(secret).db")
    defer { try? FileManager.default.removeItem(at: cacheFile) }

    startLock.lock()
    do {
      defer { startLock.unlock() }
      try setup()
      var error: NSError?
      guard LibboxAvailablePort(Int32.random(in: 20000..<40000), &port, &error) else {
        return .unsupported(error?.localizedDescription ?? "no free port")
      }
      let config = try config(
        outboundJson: outboundJson, dns: dns, port: port, secret: secret, cacheFile: cacheFile.path)
      guard let created = LibboxNewCommandServer(NoopHandler(), platform, &error) else {
        return .unsupported(error?.localizedDescription ?? "cannot create core")
      }
      server = created
      try created.startOrReloadService(config, options: LibboxOverrideOptions())
    } catch {
      return .unsupported(error.localizedDescription)
    }

    guard let client = LibboxNewHTTPClient(), let request = client.newRequest() else {
      return .unsupported("libbox HTTP client unavailable")
    }
    defer { client.close() }
    do {
      let query = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(["&", "=", "?"])) ?? url
      try request.setURL("http://127.0.0.1:\(port)/proxies/\(outboundTag)/delay?url=\(query)&timeout=\(timeoutMs)")
      request.setHeader("Authorization", value: "Bearer \(secret)")
      let body = try request.execute().getContent().value
      let json = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
      let delay = json?["delay"] as? Int ?? 0
      return delay > 0 ? .delay(delay) : .failed
    } catch {
      // Non-200 from the Clash API: 503 (test failed) or 504 (timeout).
      return .failed
    }
  }

  private static func config(
    outboundJson: String, dns: String, port: Int32, secret: String, cacheFile: String
  ) throws -> String {
    guard var outbound = try JSONSerialization.jsonObject(with: Data(outboundJson.utf8)) as? [String: Any] else {
      throw ProbeError("outbound must be a JSON object")
    }
    outbound["tag"] = outboundTag
    let config: [String: Any] = [
      "log": ["level": "warn"],
      "dns": ["servers": [["tag": "local", "type": "udp", "server": dns]]],
      "outbounds": [outbound, ["type": "direct", "tag": "direct"]],
      "route": [
        "final": outboundTag,
        "auto_detect_interface": true,
        "default_domain_resolver": "local",
      ],
      "experimental": [
        "clash_api": ["external_controller": "127.0.0.1:\(port)", "secret": secret],
        "cache_file": ["path": cacheFile],
      ],
    ]
    return String(decoding: try JSONSerialization.data(withJSONObject: config), as: UTF8.self)
  }

  /// libbox init for the app process. Working files live in the app's own
  /// caches so they never touch the tunnel extension's; basePath is the App
  /// Group root only because that is where the tunnel's command.sock is,
  /// which TrafficMonitor connects to. The app never starts a server there.
  static func setup() throws {
    if setupDone || libboxAlreadySetUp { return }
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("libbox", isDirectory: true)
    let working = caches.appendingPathComponent("working", isDirectory: true)
    try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
    let shared = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.com.wanx.wanx")
    let options = LibboxSetupOptions()
    options.basePath = shared?.path ?? caches.path
    options.workingPath = working.path
    options.tempPath = NSTemporaryDirectory()
    var error: NSError?
    guard LibboxSetup(options, &error) else { throw error ?? ProbeError("libbox setup failed") }
    setupDone = true
  }
}

struct ProbeError: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

/// Minimal platform interface for the probe core: reports the physical
/// default interface (never utun) so sing-box binds sockets to it.
private final class ProbePlatform: NSObject, LibboxPlatformInterfaceProtocol, @unchecked Sendable {
  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "com.wanx.latency.path")
  private var started = false

  func stop() { if started { monitor.cancel() } }

  private static func physical(_ path: NWPath) -> [NWInterface] {
    path.availableInterfaces.filter { $0.type != .other && $0.type != .loopback }
  }

  func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
    guard let listener else { return }
    let ready = DispatchSemaphore(value: 0)
    var first = true
    monitor.pathUpdateHandler = { path in
      if let iface = Self.physical(path).first, path.status != .unsatisfied {
        listener.updateDefaultInterface(
          iface.name, interfaceIndex: Int32(iface.index),
          isExpensive: path.isExpensive, isConstrained: path.isConstrained)
      } else {
        listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
      }
      if first { first = false; ready.signal() }
    }
    monitor.start(queue: monitorQueue)
    started = true
    // The core needs a default interface before it dials.
    _ = ready.wait(timeout: .now() + 2)
  }

  func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}

  func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
    let path = monitor.currentPath
    return ProbeInterfaces(Self.physical(path).map { iface in
      let item = LibboxNetworkInterface()
      item.name = iface.name
      item.index = Int32(iface.index)
      switch iface.type {
      case .wifi: item.type = LibboxInterfaceTypeWIFI
      case .cellular: item.type = LibboxInterfaceTypeCellular
      case .wiredEthernet: item.type = LibboxInterfaceTypeEthernet
      default: item.type = LibboxInterfaceTypeOther
      }
      item.metered = path.isExpensive
      return item
    })
  }

  // sing-box binds to the monitored interface itself (IP_BOUND_IF).
  func usePlatformAutoDetectControl() -> Bool { false }
  func autoDetectControl(_ fd: Int32) throws {}
  func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
    throw ProbeError("latency probe has no TUN")
  }
  func underNetworkExtension() -> Bool { false }
  func includeAllNetworks() -> Bool { false }
  func useProcFS() -> Bool { false }
  func findConnectionOwner(
    _ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32,
    destinationAddress: String?, destinationPort: Int32
  ) throws -> LibboxConnectionOwner { throw ProbeError("not supported") }
  func localDNSTransport() -> LibboxLocalDNSTransportProtocol? { nil }
  func readWIFIState() -> LibboxWIFIState? { nil }
  func clearDNSCache() {}
  func registerMyInterface(_ name: String?) {}
  func startNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}
  func closeNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}
  func send(_ notification: LibboxNotification?) throws {}
  func cancelNotification(_ identifier: String?, typeID: Int32) throws {}
  func usePlatformShell() -> Bool { false }
  func checkPlatformShell() throws { throw ProbeError("not supported") }
  func openShellSession(
    _ user: LibboxPlatformUser?, command: String?, environ: LibboxStringIteratorProtocol?,
    term: String?, rows: Int32, cols: Int32
  ) throws -> LibboxShellSessionProtocol { throw ProbeError("not supported") }
  func lookupUser(_ username: String?) throws -> LibboxPlatformUser { throw ProbeError("not supported") }
  func lookupSFTPServer(_ error: NSErrorPointer) -> String {
    error?.pointee = NSError(domain: "com.wanx.latency", code: 1)
    return ""
  }
  func readSystemSSHHostKey(_ error: NSErrorPointer) -> String {
    error?.pointee = NSError(domain: "com.wanx.latency", code: 1)
    return ""
  }
  func tailscaleHostname() -> String { "" }
  func usePlatformBridge() -> Bool { false }
  func createBridge(_ options: LibboxBridgeOptions?) throws -> LibboxBridgeSessionProtocol {
    throw ProbeError("not supported")
  }
}

private final class NoopHandler: NSObject, LibboxCommandServerHandlerProtocol {
  func serviceStop() throws {}
  func serviceReload() throws {}
  func getSystemProxyStatus() throws -> LibboxSystemProxyStatus { LibboxSystemProxyStatus() }
  func setSystemProxyEnabled(_ enabled: Bool) throws {}
  func triggerNativeCrash() throws {}
  func writeDebugMessage(_ message: String?) {}
  func connectSSHAgent(_ ret0_: UnsafeMutablePointer<Int32>?) throws { throw ProbeError("not supported") }
}

private final class ProbeInterfaces: NSObject, LibboxNetworkInterfaceIteratorProtocol {
  private var items: [LibboxNetworkInterface]
  init(_ items: [LibboxNetworkInterface]) { self.items = items }
  func hasNext() -> Bool { !items.isEmpty }
  func next() -> LibboxNetworkInterface? { items.isEmpty ? nil : items.removeFirst() }
}
