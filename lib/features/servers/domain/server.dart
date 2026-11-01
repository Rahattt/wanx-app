import 'outbound_codec.dart';
import 'server_config.dart';

/// Supported sing-box outbound protocols.
enum ServerProtocol {
  vless('VLESS'),
  vmess('VMess'),
  trojan('Trojan'),
  shadowsocks('Shadowsocks'),
  hysteria2('Hysteria2'),
  tuic('TUIC');

  const ServerProtocol(this.label);

  final String label;

  static ServerProtocol fromName(String name) =>
      values.firstWhere((p) => p.name == name);

  /// sing-box outbound `type`.
  String get outboundType => this == shadowsocks ? 'shadowsocks' : name;

  static ServerProtocol? fromOutboundType(String? type) {
    for (final p in values) {
      if (p.outboundType == type) return p;
    }
    return null;
  }

  bool get supportsTransport =>
      this == vless || this == vmess || this == trojan;

  bool get supportsTls => this != shadowsocks;

  /// QUIC-based: TLS is mandatory and there is no TCP handshake to probe.
  bool get isUdpBased => this == hysteria2 || this == tuic;
}

/// A server profile. The sing-box outbound is derived from the typed configs
/// via [toOutbound]; [settings] holds protocol-specific credentials and any
/// other outbound fields WanX doesn't model (uuid, password, flow, …).
class Server {
  const Server({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.settings = const {},
    this.transport = const TransportConfig(),
    this.tls = const TlsConfig(),
    this.obfuscation = const ObfuscationConfig(),
    this.group,
    this.subscriptionId,
    this.latencyMs,
    this.managedUntil,
  });

  final String id;
  final String name;
  final ServerProtocol protocol;
  final String host;
  final int port;
  final Map<String, dynamic> settings;
  final TransportConfig transport;
  final TlsConfig tls;
  final ObfuscationConfig obfuscation;

  /// Display group (subscription name). Null for manually added servers.
  final String? group;

  /// Owning subscription; its servers are replaced on refresh.
  final String? subscriptionId;

  /// Last test result: null = not tested, negative = test failed.
  final int? latencyMs;

  static const latencyFailed = -1;

  /// Set for servers from a sealed subscription: they are never stored in
  /// plain text, can't be viewed or edited, and stop working at this time
  /// until the subscription is refreshed.
  final DateTime? managedUntil;

  bool get isFromSubscription => subscriptionId != null;

  bool get isManaged => managedUntil != null;

  bool get isExpired =>
      managedUntil != null && !DateTime.now().isBefore(managedUntil!);

  String get address => '$host:$port';

  /// Identity that survives a subscription refresh (ids are regenerated).
  String get matchKey => '${protocol.name}|$host|$port|$name';

  Map<String, dynamic> toOutbound() => OutboundCodec.toOutbound(this);

  Server copyWith({
    String? name,
    String? host,
    int? port,
    TransportConfig? transport,
    TlsConfig? tls,
    ObfuscationConfig? obfuscation,
    String? id,
    int? Function()? latencyMs,
    DateTime? managedUntil,
    String? group,
  }) => Server(
    id: id ?? this.id,
    name: name ?? this.name,
    protocol: protocol,
    host: host ?? this.host,
    port: port ?? this.port,
    settings: settings,
    transport: transport ?? this.transport,
    tls: tls ?? this.tls,
    obfuscation: obfuscation ?? this.obfuscation,
    group: group ?? this.group,
    subscriptionId: subscriptionId,
    latencyMs: latencyMs != null ? latencyMs() : this.latencyMs,
    managedUntil: managedUntil ?? this.managedUntil,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.name,
    'host': host,
    'port': port,
    'settings': settings,
    'transport': transport.toJson(),
    'tls': tls.toJson(),
    'obfuscation': obfuscation.toJson(),
    'group': ?group,
    'subscriptionId': ?subscriptionId,
    'latencyMs': ?latencyMs,
    'managedUntil': ?managedUntil?.toIso8601String(),
  };

  factory Server.fromJson(Map<String, dynamic> json) {
    // Profiles saved before the typed configs existed stored a raw outbound.
    if (json['outbound'] case final Map outbound
        when json['transport'] == null) {
      return OutboundCodec.fromOutbound(
        Map<String, dynamic>.from(outbound),
        id: json['id'] as String,
        name: json['name'] as String,
      );
    }
    return Server(
      id: json['id'] as String,
      name: json['name'] as String,
      protocol: ServerProtocol.fromName(json['protocol'] as String),
      host: json['host'] as String,
      port: json['port'] as int,
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      transport: TransportConfig.fromJson(_map(json['transport'])),
      tls: TlsConfig.fromJson(_map(json['tls'])),
      obfuscation: ObfuscationConfig.fromJson(_map(json['obfuscation'])),
      group: json['group'] as String?,
      subscriptionId: json['subscriptionId'] as String?,
      latencyMs: json['latencyMs'] as int?,
      managedUntil: DateTime.tryParse(json['managedUntil'] as String? ?? ''),
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
