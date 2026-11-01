import NetworkExtension

/// Seam between the tunnel provider and the sing-box core (Libbox.xcframework
/// built with gomobile, see scripts/build_libbox.sh). The implementation is
/// `LibboxCore`.
protocol BoxCore {
  var version: String { get }
  func start(provider: NEPacketTunnelProvider, configJson: String) async throws
  func stop()
}

func makeBoxCore() -> BoxCore { LibboxCore() }
