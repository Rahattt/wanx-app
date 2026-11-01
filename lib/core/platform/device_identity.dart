/// Identifies this device to subscription panels, in the header format
/// Happ introduced and Remnawave/Marzban-style panels read for per-device
/// limits.
class DeviceIdentity {
  const DeviceIdentity({
    required this.hwid,
    required this.os,
    required this.osVersion,
    required this.model,
  });

  factory DeviceIdentity.fromMap(Map<String, Object?> map) => DeviceIdentity(
    hwid: map['hwid'] as String? ?? '',
    os: map['os'] as String? ?? '',
    osVersion: map['osVersion'] as String? ?? '',
    model: map['model'] as String? ?? '',
  );

  /// Stable across app restarts and reinstalls.
  final String hwid;
  final String os;
  final String osVersion;
  final String model;

  Map<String, String> get headers => {
    if (hwid.isNotEmpty) 'x-hwid': hwid,
    if (os.isNotEmpty) 'x-device-os': os,
    if (osVersion.isNotEmpty) 'x-ver-os': osVersion,
    if (model.isNotEmpty) 'x-device-model': model,
  };
}
