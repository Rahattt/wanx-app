import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../domain/server.dart';
import '../domain/server_config.dart';

class LatencyTestException implements Exception {
  LatencyTestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fallback test, used only when the platform urltest is unsupported.
///
/// Measures a real handshake against the server using the profile's own
/// settings: TCP connect → TLS (profile SNI/ALPN) → for ws/httpupgrade the
/// HTTP upgrade, which must answer 101. This catches dead endpoints (e.g. a
/// fronted Cloud Run service answering 503) that ICMP ping would miss.
///
/// It does not send traffic through the sing-box outbound itself (that needs
/// a URL test in the native core). While the VPN is up, this app's own
/// sockets also go through the tunnel, which inflates the numbers.
class LatencyTester {
  static const _timeout = Duration(seconds: 8);

  /// Returns the handshake time in milliseconds.
  Future<int> test(Server server) async {
    if (server.protocol.isUdpBased) {
      throw LatencyTestException(
        '${server.protocol.label} runs over QUIC/UDP and cannot be tested yet',
      );
    }
    if (server.transport.type == TransportType.xhttp &&
        server.tls.alpn.length == 1 &&
        server.tls.alpn.single == 'h3') {
      throw LatencyTestException(
        'XHTTP over HTTP/3 runs over QUIC/UDP and cannot be tested yet',
      );
    }
    final watch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        server.host,
        server.port,
        timeout: _timeout,
      );
      if (server.tls.enabled) {
        socket = await SecureSocket.secure(
          socket,
          host: server.tls.sni.isNotEmpty ? server.tls.sni : server.host,
          supportedProtocols: _alpn(server),
          // Timing only: Reality and self-signed servers present certificates
          // that don't validate, and nothing sensitive is sent.
          onBadCertificate: (_) => true,
        ).timeout(_timeout);
      }
      if (server.protocol.supportsTransport &&
          server.transport.type.isHttpUpgrade) {
        await _upgrade(socket, server);
      }
      return watch.elapsedMilliseconds;
    } on TimeoutException {
      throw LatencyTestException('Timed out');
    } on SocketException catch (e) {
      throw LatencyTestException(e.osError?.message ?? e.message);
    } on HandshakeException catch (e) {
      throw LatencyTestException('TLS handshake failed: ${e.message}');
    } on StateError {
      // Stream.first on a socket the server closed without answering.
      throw LatencyTestException('Server closed the connection');
    } finally {
      socket?.destroy();
    }
  }

  List<String>? _alpn(Server s) {
    if (s.protocol.supportsTransport && s.transport.type.isHttpUpgrade) {
      return ['http/1.1'];
    }
    return s.tls.alpn.isEmpty ? null : s.tls.alpn;
  }

  Future<void> _upgrade(Socket socket, Server s) async {
    final t = s.transport;
    final path = t.path.isEmpty ? '/' : t.path;
    final host = t.host.isNotEmpty
        ? t.host
        : (s.tls.sni.isNotEmpty ? s.tls.sni : s.host);
    final key = base64.encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    socket.write(
      'GET $path HTTP/1.1\r\n'
      'Host: $host\r\n'
      'Upgrade: websocket\r\n'
      'Connection: Upgrade\r\n'
      'Sec-WebSocket-Key: $key\r\n'
      'Sec-WebSocket-Version: 13\r\n'
      'User-Agent: Mozilla/5.0\r\n\r\n',
    );
    final statusLine = await socket
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .first
        .timeout(_timeout);
    final code = int.tryParse(statusLine.split(' ').elementAtOrNull(1) ?? '');
    if (code != HttpStatus.switchingProtocols) {
      throw LatencyTestException(
        code == null
            ? 'Unexpected response: $statusLine'
            : '${t.type.label} upgrade rejected: HTTP $code',
      );
    }
  }
}
