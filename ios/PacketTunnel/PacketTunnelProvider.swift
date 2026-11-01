import NetworkExtension
import os

/// Network Extension that hosts the sing-box core. Runs in its own process
/// with a ~50 MB memory limit, so keep the config lean (no huge rule sets).
final class PacketTunnelProvider: NEPacketTunnelProvider {
  private static let appGroup = "group.com.wanx.wanx"
  // Under Library/ so it can be pulled with `devicectl device copy from`.
  private static let configFileName = "Library/Caches/config.json"
  /// Check window (ms) of an unchecked premium link: the tunnel ends that
  /// long after it is up unless the app confirms first. Shared with the app
  /// so a start from Settings can't skip it.
  static let deadlineFileName = "Library/Caches/deadline"

  private var deadlineTask: Task<Void, Never>?

  private let core: BoxCore = makeBoxCore()

  /// Probe cores share this process with the tunnel core; refuse to start
  /// one if it could push the extension over its memory limit.
  private static let probeMemoryReserve = 20 * 1024 * 1024

  override init() {
    super.init()
    LatencyProbe.libboxAlreadySetUp = true
    LatencyProbe.admissionCheck = {
      let available = os_proc_available_memory()
      return available < Self.probeMemoryReserve ? "Not enough memory in the tunnel extension" : nil
    }
  }

  override func startTunnel(options: [String: NSObject]?) async throws {
    let config = try (options?["config"] as? String) ?? loadSharedConfig()
    let window = sharedCheckWindow()
    // libbox calls back into `self` (openTun) to apply NEPacketTunnelNetworkSettings
    // and obtain the utun file descriptor.
    try await core.start(provider: self, configJson: config)
    // Unless the app confirmed while the core was starting.
    if let window, sharedCheckWindow() != nil {
      // The window runs from here, once the tunnel is up.
      let message = (options?["deadlineMessage"] as? String) ?? "Subscription not verified"
      scheduleDeadline(after: window, message: message)
    }
  }

  override func stopTunnel(with reason: NEProviderStopReason) async {
    deadlineTask?.cancel()
    core.stop()
  }

  /// App ↔ extension messages: "version" → core version string;
  /// "clearDeadline" → the premium check passed, keep running.
  override func handleAppMessage(_ messageData: Data) async -> Data? {
    switch String(data: messageData, encoding: .utf8) {
    case "version":
      return core.version.data(using: .utf8)
    case "clearDeadline":
      deadlineTask?.cancel()
      deadlineTask = nil
      if let file = Self.sharedFile(Self.deadlineFileName) {
        try? FileManager.default.removeItem(at: file)
      }
      return Data()
    default:
      break
    }
    return await LatencyProbe.handle(message: messageData)
  }

  /// Ends the tunnel after [window] unless "clearDeadline" comes first —
  /// here, so closing the app doesn't keep it up.
  private func scheduleDeadline(after window: TimeInterval, message: String) {
    deadlineTask?.cancel()
    deadlineTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(window * 1e9))
      guard !Task.isCancelled else { return }
      // A plain NSError: a custom Error loses its text on the way to the
      // system, which then shows a generic "operation couldn't be completed".
      self?.cancelTunnelWithError(
        NSError(domain: "com.wanx.wanx.tunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
      )
    }
  }

  private func sharedCheckWindow() -> TimeInterval? {
    guard let file = Self.sharedFile(Self.deadlineFileName),
          let text = try? String(contentsOf: file, encoding: .utf8),
          let ms = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), ms > 0 else { return nil }
    return ms / 1000
  }

  private static func sharedFile(_ name: String) -> URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent(name)
  }

  private func loadSharedConfig() throws -> String {
    guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) else {
      throw TunnelError.noAppGroup
    }
    return try String(contentsOf: dir.appendingPathComponent(Self.configFileName), encoding: .utf8)
  }
}

enum TunnelError: LocalizedError {
  case noAppGroup
  case unverified(String)

  var errorDescription: String? {
    switch self {
    case .noAppGroup: return "App Group container is unavailable"
    case .unverified(let message): return message
    }
  }
}
