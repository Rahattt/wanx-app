/// Tunnel state as reported by the native layer. The wire values match the
/// strings sent by `VpnStatus` in Kotlin and Swift.
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error;

  static VpnStatus fromWire(String? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => disconnected);

  bool get isBusy => this == connecting || this == disconnecting;
}

class VpnState {
  const VpnState({this.status = VpnStatus.disconnected, this.error});

  final VpnStatus status;
  final String? error;
}
