import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanx/core/platform/device_identity.dart';
import 'package:wanx/core/singbox/config_builder.dart';
import 'package:wanx/features/servers/data/share_link_parser.dart';
import 'package:wanx/features/settings/domain/app_settings.dart';

void main() {
  test('settings survive a JSON round trip', () {
    const s = AppSettings(
      themeMode: ThemeMode.dark,
      languageCode: 'tr',
      dns: DnsPreset.adguard,
      ipMode: IpMode.ipv6,
      bypassLan: false,
      autoConnect: true,
      updateSubscriptionsOnLaunch: true,
      splitMode: SplitTunnelMode.bypass,
      splitApps: ['com.a', 'org.b'],
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });

  test('unknown or missing values fall back to defaults', () {
    final s = AppSettings.fromJson({
      'themeMode': 'neon',
      'languageCode': 'xx',
      'dns': 'nope',
    });
    expect(s.toJson(), const AppSettings().toJson());
  });

  test('config follows DNS, IPv6 and LAN settings', () {
    final server = ShareLinkParser()
        .parseMany('trojan://p@t.example.com:443#t')
        .servers
        .single;
    final config = SingBoxConfigBuilder(
      remoteDns: DnsPreset.quad9.url,
      bypassLan: false,
    ).build(server);
    final dns = config['dns'] as Map;
    expect((dns['servers'] as List).first['server'], '9.9.9.9');
    expect(dns['strategy'], 'ipv4_only');
    final tun = (config['inbounds'] as List).single as Map;
    expect(tun['address'], ['172.19.0.1/30']);
    final rules = (config['route'] as Map)['rules'] as List;
    expect(rules.any((r) => (r as Map).containsKey('ip_is_private')), isFalse);
  });

  test('the old IPv6 switch maps to an IP mode', () {
    expect(AppSettings.fromJson({'ipv6Routing': true}).ipMode, IpMode.dual);
    expect(AppSettings.fromJson({'ipv6Routing': false}).ipMode, IpMode.ipv4);
    expect(AppSettings.fromJson(const {}).ipMode, IpMode.ipv4);
  });

  test('IP mode sets the DNS strategy and TUN addresses', () {
    final server = ShareLinkParser()
        .parseMany('trojan://p@t.example.com:443#t')
        .servers
        .single;
    for (final (mode, strategy, v6) in [
      (IpMode.ipv4, 'ipv4_only', false),
      (IpMode.dual, 'prefer_ipv4', true),
      // IPv4 stays in the tunnel so it can't leak around it.
      (IpMode.ipv6, 'ipv6_only', true),
    ]) {
      final config = SingBoxConfigBuilder(ipMode: mode).build(server);
      expect((config['dns'] as Map)['strategy'], strategy);
      final tun = (config['inbounds'] as List).single as Map;
      expect(tun['address'], [
        '172.19.0.1/30',
        if (v6) 'fdfe:dcba:9876::1/126',
      ]);
    }
  });

  test('per-app VPN goes into the TUN inbound', () {
    final server = ShareLinkParser()
        .parseMany('trojan://p@t.example.com:443#t')
        .servers
        .single;
    Map tun(SplitTunnelMode mode, List<String> apps) =>
        (SingBoxConfigBuilder(
                  splitMode: mode,
                  splitApps: apps,
                ).build(server)['inbounds']
                as List)
            .single;
    expect(tun(SplitTunnelMode.only, ['com.a'])['include_package'], ['com.a']);
    expect(tun(SplitTunnelMode.bypass, ['com.a'])['exclude_package'], [
      'com.a',
    ]);
    // No apps picked, or the feature off: every app.
    for (final t in [
      tun(SplitTunnelMode.only, []),
      tun(SplitTunnelMode.off, ['com.a']),
    ]) {
      expect(t.containsKey('include_package'), isFalse);
      expect(t.containsKey('exclude_package'), isFalse);
    }
  });

  test('HWID is sent by default and can be turned off', () {
    expect(const AppSettings().sendHwid, isTrue);
    final off = const AppSettings().copyWith(sendHwid: false);
    expect(AppSettings.fromJson(off.toJson()).sendHwid, isFalse);
    expect(AppSettings.fromJson(const {}).sendHwid, isTrue);
  });

  test('device identity maps to Happ-style headers', () {
    final id = DeviceIdentity.fromMap(const {
      'hwid': 'abc',
      'os': 'iOS',
      'osVersion': '26.0',
      'model': 'iPhone17,1',
    });
    expect(id.headers, {
      'x-hwid': 'abc',
      'x-device-os': 'iOS',
      'x-ver-os': '26.0',
      'x-device-model': 'iPhone17,1',
    });
    expect(DeviceIdentity.fromMap(const {}).headers, isEmpty);
  });
}
