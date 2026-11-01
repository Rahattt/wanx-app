import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app's UI is on screen. On Android the VPN service keeps the
/// process alive in the background, so UI-only work (live traffic, checks)
/// must stop on its own when nobody is looking.
final appForegroundProvider = NotifierProvider<AppForeground, bool>(
  AppForeground.new,
);

class AppForeground extends Notifier<bool> {
  @override
  bool build() {
    final listener = AppLifecycleListener(
      onStateChange: (s) => state = isVisible(s),
    );
    ref.onDispose(listener.dispose);
    return isVisible(WidgetsBinding.instance.lifecycleState);
  }

  /// Resumed or briefly covered (control centre, a system dialog); null
  /// before the first lifecycle event counts as visible.
  static bool isVisible(AppLifecycleState? s) =>
      s == null ||
      s == AppLifecycleState.resumed ||
      s == AppLifecycleState.inactive;
}
