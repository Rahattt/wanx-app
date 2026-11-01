import Flutter
import UIKit

/// Native side of lib/core/platform/link_channel.dart: hands wanx:// links
/// the app is opened with to Dart.
enum LinkChannel {
  private static var channel: FlutterMethodChannel?

  /// A link that arrived before Dart asked for it.
  private static var pending: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.wanx/link", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "take" else { return result(FlutterMethodNotImplemented) }
      result(pending)
      pending = nil
    }
    self.channel = channel
  }

  static func receive(_ url: URL) {
    guard url.scheme?.lowercased() == "wanx" else { return }
    if let channel {
      channel.invokeMethod("link", arguments: url.absoluteString)
    } else {
      pending = url.absoluteString
    }
  }
}
