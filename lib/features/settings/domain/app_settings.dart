import 'package:flutter/material.dart';

/// Encrypted DNS resolvers offered in Settings. Addressed by IP so they
/// need no bootstrap lookup; all of them sit behind the proxy.
enum DnsPreset {
  cloudflare('Cloudflare', 'https://1.1.1.1/dns-query'),
  google('Google', 'https://8.8.8.8/dns-query'),
  quad9('Quad9', 'https://9.9.9.9/dns-query'),
  adguard('AdGuard', 'https://94.140.14.14/dns-query');

  const DnsPreset(this.label, this.url);

  final String label;
  final String url;
}

/// Which IP versions sites are reached over through the tunnel.
enum IpMode {
  /// IPv4 only: no IPv6 in the tunnel, DNS answers IPv4 only.
  ipv4,

  /// Both; IPv4 preferred when a site has both.
  dual,

  /// DNS answers IPv6 only. The tunnel still takes IPv4 so nothing leaks
  /// around it; only for servers with IPv6 egress.
  ipv6,
}

/// Android per-app VPN: which apps the tunnel carries.
enum SplitTunnelMode {
  /// Every app.
  off,

  /// Only [AppSettings.splitApps].
  only,

  /// Every app except [AppSettings.splitApps].
  bypass,
}

/// Languages the app is translated into, in the order Settings lists them.
/// Each is named in its own language.
const supportedLanguages = {
  'en': 'English',
  'ru': 'Русский',
  'tr': 'Türkçe',
  'fr': 'Français',
  'zh': '中文',
};

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.languageCode,
    this.dns = DnsPreset.cloudflare,
    this.ipMode = IpMode.ipv4,
    this.bypassLan = true,
    this.autoConnect = false,
    this.updateSubscriptionsOnLaunch = false,
    this.sendHwid = true,
    this.splitMode = SplitTunnelMode.off,
    this.splitApps = const [],
    this.privacyAccepted = false,
  });

  final ThemeMode themeMode;

  /// null follows the system language.
  final String? languageCode;
  final DnsPreset dns;

  /// IPv4 by default: many servers (e.g. behind Cloud Run) have no IPv6
  /// egress, and a tunnel that offers IPv6 makes apps try it first and fail.
  final IpMode ipMode;
  final bool bypassLan;
  final bool autoConnect;
  final bool updateSubscriptionsOnLaunch;

  /// Send the device ID with subscription requests so panels can apply
  /// per-device limits.
  final bool sendHwid;

  /// Android only; package names, sorted.
  final SplitTunnelMode splitMode;
  final List<String> splitApps;

  /// The first-launch data disclosure was accepted (App Store 5.4, Google
  /// Play's prominent disclosure).
  final bool privacyAccepted;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? Function()? languageCode,
    DnsPreset? dns,
    IpMode? ipMode,
    bool? bypassLan,
    bool? autoConnect,
    bool? updateSubscriptionsOnLaunch,
    bool? sendHwid,
    SplitTunnelMode? splitMode,
    List<String>? splitApps,
    bool? privacyAccepted,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode != null ? languageCode() : this.languageCode,
    dns: dns ?? this.dns,
    ipMode: ipMode ?? this.ipMode,
    bypassLan: bypassLan ?? this.bypassLan,
    autoConnect: autoConnect ?? this.autoConnect,
    updateSubscriptionsOnLaunch:
        updateSubscriptionsOnLaunch ?? this.updateSubscriptionsOnLaunch,
    sendHwid: sendHwid ?? this.sendHwid,
    splitMode: splitMode ?? this.splitMode,
    splitApps: splitApps ?? this.splitApps,
    privacyAccepted: privacyAccepted ?? this.privacyAccepted,
  );

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'languageCode': languageCode,
    'dns': dns.name,
    'ipMode': ipMode.name,
    'bypassLan': bypassLan,
    'autoConnect': autoConnect,
    'updateSubscriptionsOnLaunch': updateSubscriptionsOnLaunch,
    'sendHwid': sendHwid,
    'splitMode': splitMode.name,
    'splitApps': splitApps,
    'privacyAccepted': privacyAccepted,
  };

  /// Unknown or missing values fall back to defaults.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    final language = json['languageCode'] as String?;
    return AppSettings(
      themeMode: byName(ThemeMode.values, json['themeMode'], d.themeMode),
      languageCode: supportedLanguages.containsKey(language) ? language : null,
      dns: byName(DnsPreset.values, json['dns'], d.dns),
      ipMode: json.containsKey('ipMode')
          ? byName(IpMode.values, json['ipMode'], d.ipMode)
          // The older IPv6 switch; values saved under 'ipv6' predate the
          // safer default.
          : json['ipv6Routing'] == true
          ? IpMode.dual
          : d.ipMode,
      bypassLan: json['bypassLan'] as bool? ?? d.bypassLan,
      autoConnect: json['autoConnect'] as bool? ?? d.autoConnect,
      updateSubscriptionsOnLaunch:
          json['updateSubscriptionsOnLaunch'] as bool? ??
          d.updateSubscriptionsOnLaunch,
      sendHwid: json['sendHwid'] as bool? ?? d.sendHwid,
      splitMode: byName(SplitTunnelMode.values, json['splitMode'], d.splitMode),
      splitApps: [
        for (final p in json['splitApps'] as List? ?? const [])
          if (p is String) p,
      ]..sort(),
      privacyAccepted: json['privacyAccepted'] as bool? ?? d.privacyAccepted,
    );
  }
}
