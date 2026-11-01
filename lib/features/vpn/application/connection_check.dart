import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectionCheckProvider = Provider<ConnectionCheck>(
  (ref) => const ConnectionCheck(),
);

/// One real HTTP request from the app. With the VPN up the app's traffic
/// goes through the tunnel, so an answer means the server is alive right
/// now — useful when the traffic counters sit at zero.
class ConnectionCheck {
  const ConnectionCheck();

  static final url = Uri.parse('https://www.gstatic.com/generate_204');

  /// Round trip in ms (fresh connection: DNS, TCP, TLS and the request),
  /// or null when nothing came back within [timeout].
  Future<int?> run({Duration timeout = const Duration(seconds: 5)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final watch = Stopwatch()..start();
    try {
      final request = await client.getUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      return response.statusCode < 400 ? watch.elapsedMilliseconds : null;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
