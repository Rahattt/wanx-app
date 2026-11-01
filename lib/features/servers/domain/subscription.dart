/// A remote server list. Its servers carry [id] as `subscriptionId` and
/// [name] as `group`, and are replaced wholesale on refresh.
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.updatedAt,
    this.sealed = false,
    this.envelope,
    this.expiresAt,
    this.token,
    this.checkedAt,
    this.blocked,
    this.premiumLapsed = false,
  });

  final String id;
  final String name;
  final String url;
  final DateTime? updatedAt;

  /// A premium provider's link (see `packages/wanx_sealed`): servers
  /// locked, checked with WanX.
  final bool sealed;

  /// The last passed check, still encrypted; only this device opens it.
  final String? envelope;

  /// When the last check stops counting without a new one.
  final DateTime? expiresAt;

  /// The premium link's token, checked with the WanX service; null for a
  /// plain subscription. With it, [url] is the provider's own URL from the
  /// decrypted `wanx://` link — never shown.
  final String? token;

  /// Last time the WanX service accepted this premium link.
  final DateTime? checkedAt;

  /// A premium link not yet accepted even once: usable only while the
  /// guard checks it in the first minutes of a connection.
  bool get pending => token != null && checkedAt == null;

  /// Why the WanX service refused the link (`device_removed`, `revoked`,
  /// …); null while it is fine.
  final String? blocked;

  /// The provider's plan has lapsed: the link stays encrypted and keeps
  /// working, without fronting or a device limit, until it is renewed.
  final bool premiumLapsed;

  Subscription copyWith({
    String? name,
    DateTime? updatedAt,
    bool? sealed,
    String? envelope,
    DateTime? expiresAt,
    DateTime? checkedAt,
    String? Function()? blocked,
    bool? premiumLapsed,
  }) => Subscription(
    id: id,
    name: name ?? this.name,
    url: url,
    updatedAt: updatedAt ?? this.updatedAt,
    sealed: sealed ?? this.sealed,
    envelope: envelope ?? this.envelope,
    expiresAt: expiresAt ?? this.expiresAt,
    token: token,
    checkedAt: checkedAt ?? this.checkedAt,
    blocked: blocked != null ? blocked() : this.blocked,
    premiumLapsed: premiumLapsed ?? this.premiumLapsed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'updatedAt': ?updatedAt?.toIso8601String(),
    if (sealed) 'sealed': true,
    'envelope': ?envelope,
    'expiresAt': ?expiresAt?.toIso8601String(),
    'token': ?token,
    'checkedAt': ?checkedAt?.toIso8601String(),
    'blocked': ?blocked,
    if (premiumLapsed) 'premiumLapsed': true,
  };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    sealed: json['sealed'] == true,
    envelope: json['envelope'] as String?,
    expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    token: json['token'] as String?,
    checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? ''),
    blocked: json['blocked'] as String?,
    premiumLapsed: json['premiumLapsed'] == true,
  );
}
