/// Serializable sub-configs of a [Server]. Each keeps an [extra] map with
/// sing-box fields WanX doesn't model, so profiles imported from sing-box
/// JSON subscriptions round-trip without losing options.
library;

enum TransportType {
  tcp('TCP'),
  ws('WebSocket'),
  grpc('gRPC'),
  httpupgrade('HTTPUpgrade'),
  http('HTTP/2');

  const TransportType(this.label);

  final String label;

  static TransportType fromName(String? name) =>
      values.firstWhere((t) => t.name == name, orElse: () => tcp);

  /// Transports that run an HTTP/1.1 upgrade handshake.
  bool get isHttpUpgrade => this == ws || this == httpupgrade;
}

class TransportConfig {
  const TransportConfig({
    this.type = TransportType.tcp,
    this.path = '',
    this.host = '',
    this.maxEarlyData = 0,
    this.extra = const {},
  });

  final TransportType type;

  /// URL path for ws/httpupgrade/http, service name for gRPC.
  final String path;

  /// Host header (domain fronting target).
  final String host;

  /// WebSocket early data (`?ed=2048` in share links).
  final int maxEarlyData;
  final Map<String, dynamic> extra;

  TransportConfig copyWith({TransportType? type, String? path, String? host}) =>
      TransportConfig(
        type: type ?? this.type,
        path: path ?? this.path,
        host: host ?? this.host,
        maxEarlyData: maxEarlyData,
        extra: extra,
      );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'path': path,
    'host': host,
    'maxEarlyData': maxEarlyData,
    'extra': extra,
  };

  factory TransportConfig.fromJson(Map<String, dynamic> json) =>
      TransportConfig(
        type: TransportType.fromName(json['type'] as String?),
        path: json['path'] as String? ?? '',
        host: json['host'] as String? ?? '',
        maxEarlyData: json['maxEarlyData'] as int? ?? 0,
        extra: _map(json['extra']),
      );
}

class TlsConfig {
  const TlsConfig({
    this.enabled = false,
    this.sni = '',
    this.alpn = const [],
    this.insecure = false,
    this.extra = const {},
  });

  final bool enabled;
  final String sni;
  final List<String> alpn;
  final bool insecure;
  final Map<String, dynamic> extra;

  TlsConfig copyWith({
    bool? enabled,
    String? sni,
    List<String>? alpn,
    bool? insecure,
  }) => TlsConfig(
    enabled: enabled ?? this.enabled,
    sni: sni ?? this.sni,
    alpn: alpn ?? this.alpn,
    insecure: insecure ?? this.insecure,
    extra: extra,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'sni': sni,
    'alpn': alpn,
    'insecure': insecure,
    'extra': extra,
  };

  factory TlsConfig.fromJson(Map<String, dynamic> json) => TlsConfig(
    enabled: json['enabled'] as bool? ?? false,
    sni: json['sni'] as String? ?? '',
    alpn: List<String>.from(json['alpn'] as List? ?? const []),
    insecure: json['insecure'] as bool? ?? false,
    extra: _map(json['extra']),
  );
}

enum UtlsFingerprint {
  none('None'),
  chrome('Chrome'),
  firefox('Firefox'),
  safari('Safari'),
  random('Random');

  const UtlsFingerprint(this.label);

  final String label;

  static UtlsFingerprint fromName(String? name) =>
      values.firstWhere((f) => f.name == name, orElse: () => none);
}

/// Censorship-circumvention options. Mapped onto sing-box `tls` fields:
/// `utls`, `fragment`, `record_fragment`, `fragment_fallback_delay`, `reality`.
class ObfuscationConfig {
  const ObfuscationConfig({
    this.fingerprint = UtlsFingerprint.none,
    this.fragment = false,
    this.recordFragment = false,
    this.fragmentFallbackDelayMs,
    this.reality = false,
    this.realityPublicKey = '',
    this.realityShortId = '',
  });

  final UtlsFingerprint fingerprint;

  /// Split the TLS ClientHello across TCP segments.
  final bool fragment;

  /// Split the ClientHello into multiple TLS records.
  final bool recordFragment;

  /// Fallback delay when the fragment timing can't be auto-detected;
  /// null = sing-box default.
  final int? fragmentFallbackDelayMs;

  final bool reality;
  final String realityPublicKey;
  final String realityShortId;

  Map<String, dynamic> toJson() => {
    'fingerprint': fingerprint.name,
    'fragment': fragment,
    'recordFragment': recordFragment,
    'fragmentFallbackDelayMs': ?fragmentFallbackDelayMs,
    'reality': reality,
    'realityPublicKey': realityPublicKey,
    'realityShortId': realityShortId,
  };

  factory ObfuscationConfig.fromJson(Map<String, dynamic> json) =>
      ObfuscationConfig(
        fingerprint: UtlsFingerprint.fromName(json['fingerprint'] as String?),
        fragment: json['fragment'] as bool? ?? false,
        recordFragment: json['recordFragment'] as bool? ?? false,
        fragmentFallbackDelayMs: json['fragmentFallbackDelayMs'] as int?,
        reality: json['reality'] as bool? ?? false,
        realityPublicKey: json['realityPublicKey'] as String? ?? '',
        realityShortId: json['realityShortId'] as String? ?? '',
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
