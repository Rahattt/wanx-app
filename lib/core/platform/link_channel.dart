import 'dart:async';

import 'package:flutter/services.dart';

/// wanx:// links the app is opened with (a tap in a messenger or browser).
///
/// Native counterparts: `MainActivity.kt` (Android), `LinkChannel.swift`
/// (iOS). Methods: `take` → String?, the link the app was launched with;
/// the native side calls `link` (String) for links arriving while running.
class LinkChannel {
  static const _channel = MethodChannel('com.wanx/link');

  /// The launch link (if any), then every later one.
  Stream<String> links() {
    final controller = StreamController<String>();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        controller.add(call.arguments as String);
      }
    });
    _channel.invokeMethod<String>('take').then((link) {
      if (link != null) controller.add(link);
    }, onError: (_) {});
    controller.onCancel = () => _channel.setMethodCallHandler(null);
    return controller.stream;
  }
}
