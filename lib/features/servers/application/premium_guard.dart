import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/application/settings_controller.dart';
import '../../vpn/application/vpn_controller.dart';
import '../../vpn/domain/vpn_status.dart';
import 'servers_controller.dart';

final premiumGuardProvider = Provider<PremiumGuard>(
  (ref) => PremiumGuard(ref, SharedPreferencesAsync()),
);

/// A premium link that never passed its check (imported where our service
/// is blocked) may connect, and is then checked — through the tunnel, which
/// reaches our service — within [window]. A refusal or no answer in time
/// disconnects; the VPN service enforces the deadline itself too, so closing
/// the app doesn't keep the tunnel up. At most [windowsPerDay] windows per
/// link, so reconnecting is not a way around the check.
class PremiumGuard {
  PremiumGuard(this._ref, this._prefs);

  final Ref _ref;
  final SharedPreferencesAsync _prefs;

  /// From the moment the tunnel is up.
  static const window = Duration(seconds: 5);
  static const retryEvery = Duration(seconds: 1);
  static const windowsPerDay = 3;

  final _running = <String>{};

  Future<bool> mayConnect(String subscriptionId) async =>
      (await _windows(subscriptionId)).length < windowsPerDay;

  /// Checks [subscriptionId] until it passes, is refused or [window] ends.
  Future<void> run(String subscriptionId) async {
    if (!_running.add(subscriptionId)) return;
    try {
      await _prefs.setString(
        _key(subscriptionId),
        jsonEncode([
          for (final t in await _windows(subscriptionId)) t.toIso8601String(),
          DateTime.now().toIso8601String(),
        ]),
      );
      final deadline = DateTime.now().add(window);
      final servers = _ref.read(serversProvider.notifier);
      while (DateTime.now().isBefore(deadline)) {
        if (_ref.read(vpnProvider).status != VpnStatus.connected) return;
        await servers.confirmPending(subscriptionId);
        final sub = _ref
            .read(serversProvider)
            .value
            ?.subscriptions
            .where((s) => s.id == subscriptionId)
            .firstOrNull;
        if (sub == null) return;
        if (sub.blocked case final code?) {
          await _stop(premiumRefusal(appL10n(_ref), code));
          return;
        }
        if (!sub.pending) {
          // Passed: lift the VPN service's own deadline.
          await _ref.read(vpnChannelProvider).clearDeadline();
          return;
        }
        await Future<void>.delayed(retryEvery);
      }
      await _stop(appL10n(_ref).premiumCheckTimeout);
    } finally {
      _running.remove(subscriptionId);
    }
  }

  Future<void> _stop(String reason) async {
    if (_ref.read(vpnProvider).status == VpnStatus.connected) {
      await _ref.read(vpnProvider.notifier).stopWith(reason);
    }
  }

  /// Window starts in the last 24 hours.
  Future<List<DateTime>> _windows(String subscriptionId) async {
    final since = DateTime.now().subtract(const Duration(days: 1));
    try {
      final raw = jsonDecode(
        await _prefs.getString(_key(subscriptionId)) ?? '[]',
      );
      return [
        for (final t in raw as List)
          if (DateTime.tryParse('$t') case final d? when d.isAfter(since)) d,
      ];
    } on FormatException {
      return [];
    }
  }

  static String _key(String id) => 'premium_windows_$id';
}
