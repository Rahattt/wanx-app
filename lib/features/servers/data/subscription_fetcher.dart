import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:wanx_sealed/wanx_sealed.dart';

import '../../../core/sealed/publisher_keys.dart';
import '../../../core/sealed/sealed_keys.dart';
import '../domain/outbound_codec.dart';
import '../domain/server.dart';
import '../domain/subscription.dart';
import '../domain/subscription_url.dart';
import 'share_link_parser.dart';

class SubscriptionException implements Exception {
  SubscriptionException(
    this.message, {
    this.status,
    this.code,
    this.refused = false,
  });

  final String message;

  /// HTTP status of a non-200 answer; null when the server wasn't reached.
  final int? status;

  /// The WanX service's reason (`device_removed`, `revoked`,
  /// `plan_inactive`, …), when it gave one.
  final String? code;

  /// The WanX service refused a premium link outright (revoked, expired,
  /// plan lapsed, device removed or over the limit), as opposed to not
  /// answering — which must not cut anyone off. Never set for the
  /// provider's own answers.
  final bool refused;

  @override
  String toString() => message;
}

/// A passed premium check as received: still encrypted, plus what it says.
class SealedCopy {
  const SealedCopy(this.envelope, this.payload);

  final String envelope;
  final SealedPayload payload;
}

class FetchResult {
  const FetchResult(this.servers, {this.sealed, this.lapsed = false});

  final List<Server> servers;

  /// Set when a premium link's check passed on this fetch.
  final SealedCopy? sealed;

  /// The provider's plan has lapsed: the link stays encrypted and keeps
  /// working, without the premium extras (fronting, device limit).
  final bool lapsed;
}

/// Downloads a subscription and turns it into servers. Accepts a base64 or
/// plain list of share links, or a sing-box JSON config with `outbounds`.
///
/// A premium link (`wanx://`, [Subscription.token] set) is checked with the
/// WanX service at [checkEndpoints] — the app posts its device key and gets
/// a signed answer only it can open — while the servers always come from
/// the provider's own URL, fronted if the link says so.
class SubscriptionFetcher {
  SubscriptionFetcher(
    this._parser, {
    this.extraHeaders,
    this.sealedKeys,
    this.checkEndpoints,
    Map<String, String> trustedKeys = publisherKeys,
  }) : _trusted = {
         for (final e in trustedKeys.entries) e.key: base64.decode(e.value),
       };

  final ShareLinkParser _parser;

  /// Opens sealed links; null where there is no device key (tests).
  final SealedKeys? sealedKeys;
  final Map<String, List<int>> _trusted;

  /// Added to every request, e.g. the device's HWID headers.
  final Future<Map<String, String>> Function()? extraHeaders;

  /// Base URLs to check premium links at, tried in order; fronting hints
  /// allowed. See CheckEndpoints.
  final Future<List<String>> Function()? checkEndpoints;

  static const _timeout = Duration(seconds: 20);

  /// Validates [raw] and splits off any `#` fragment extras (profile label,
  /// `endpoint`/`resolve-address` address, `header_host`/`host` header).
  static SubscriptionUrl parseExtended(String raw) {
    try {
      return SubscriptionUrl.parse(raw);
    } on FormatException catch (e) {
      throw SubscriptionException(e.message);
    }
  }

  Future<FetchResult> fetch(Subscription sub) async {
    final route = parseExtended(sub.url);
    final token = sub.token;
    if (token == null) {
      // Balancer routing is a premium feature: a plain list can't use it.
      if (route.routed) {
        throw SubscriptionException(
          'Routing parameters in the link are only supported for '
          'premium subscriptions',
        );
      }
      final (body, _) = await _request('GET', route);
      return FetchResult(parse(body, sub));
    }

    // The check runs on import, then daily: where our service is blocked
    // a refresh still reaches the provider, and a link not yet checked is
    // checked through the tunnel once connected (see PremiumGuard).
    SealedCopy? copy;
    var lapsed = sub.premiumLapsed;
    if (_checkDue(sub)) {
      try {
        copy = await check(sub);
        lapsed = false;
      } on SubscriptionException catch (e) {
        // Unreachable keeps the last check (or the pending state); a lapsed
        // plan keeps the link without its extras.
        if (e.refused) rethrow;
        // A lapsed plan takes no new devices: only links already in stay.
        if (e.status == 402 && sub.pending) {
          throw SubscriptionException(
            e.message,
            status: 402,
            code: 'plan_inactive',
            refused: true,
          );
        }
        if (e.status == 402) lapsed = true;
      }
    }
    // Fronting is premium: without it, straight to the provider's URL.
    final (body, _) = await _request(
      'GET',
      lapsed
          ? parseExtended(route.originalUrl.removeFragment().toString())
          : route,
    );
    final until =
        copy?.payload.expiresAt ??
        (lapsed || sub.pending ? noExpiry : sub.expiresAt);
    return FetchResult(
      sealedServers(body, sub, until),
      sealed: copy,
      lapsed: lapsed,
    );
  }

  /// Checks [sub]'s token at the first check endpoint that answers. Throws
  /// [SubscriptionException]: [SubscriptionException.refused] for a no,
  /// status 402 for a lapsed plan, no status when none could be reached.
  Future<SealedCopy> check(Subscription sub) async {
    final endpoints = await checkEndpoints?.call() ?? const <String>[];
    SubscriptionException? unreachable;
    for (final endpoint in endpoints) {
      try {
        return await openSealed(
          await _register(
            _checkRoute(endpoint, sub.token!),
            refresh: !sub.pending,
          ),
        );
      } on SubscriptionException catch (e) {
        if (e.status == null) {
          unreachable = e;
          continue;
        }
        final refused = const {403, 404, 410}.contains(e.status);
        throw SubscriptionException(
          e.message,
          status: e.status,
          code: e.code ?? (e.status == 402 ? 'plan_inactive' : null),
          refused: refused,
        );
      }
    }
    throw unreachable ??
        SubscriptionException('No premium check endpoint is configured');
  }

  /// `<endpoint>/s/<token>`, keeping the endpoint's fronting hints.
  static SubscriptionUrl _checkRoute(String endpoint, String token) {
    final base = Uri.parse(endpoint);
    return parseExtended(base.replace(path: '/s/$token').toString());
  }

  /// Downloads [url] (fronting hints allowed), e.g. an endpoint list copy.
  Future<String> download(String url) async =>
      (await _request('GET', parseExtended(url))).$1;

  /// Lock without end: a lapsed plan's links (no check left to renew them)
  /// and links waiting for their first check (the guard ends those).
  static final noExpiry = DateTime.utc(9999);

  /// How often an imported premium link is re-checked with the service.
  static const checkEvery = Duration(hours: 24);

  /// On import (and while pending), daily, and whenever the last check is
  /// about to run out (a renewed plan or link then extends it).
  static bool _checkDue(Subscription sub) {
    final now = DateTime.now();
    final checked = sub.checkedAt;
    final expires = sub.expiresAt;
    return checked == null ||
        now.difference(checked) >= checkEvery ||
        expires == null ||
        expires.isBefore(now.add(const Duration(hours: 6)));
  }

  /// Decrypts and verifies a stored or freshly received envelope.
  Future<SealedCopy> openSealed(String envelope) async {
    final keys = sealedKeys;
    if (keys == null) {
      throw SubscriptionException('Sealed subscriptions are not supported');
    }
    try {
      final clear = await keys.open(SealedEnvelope.decode(envelope));
      final payload = await verifyPayload(
        SignedPayload.decode(utf8.decode(clear)),
        trustedKeys: _trusted,
        deviceFingerprint: await deviceFingerprint(await keys.publicKey()),
      );
      return SealedCopy(envelope, payload);
    } on SealedException catch (e) {
      throw SubscriptionException(e.message);
    } on FormatException {
      throw SubscriptionException('Sealed subscription is corrupt');
    }
  }

  /// A premium link's servers from the provider's [body], locked down
  /// until [until] (the last check's expiry) and with ids that stay the
  /// same each refresh (selection survives).
  List<Server> sealedServers(String body, Subscription sub, DateTime? until) {
    final seen = <String, int>{};
    return [
      for (final s in parse(body, sub))
        s.copyWith(
          id: _stableId(sub.id, s.matchKey, seen),
          managedUntil: until ?? DateTime.now(),
        ),
    ];
  }

  /// Hashed so no host or port ends up in the stored selection.
  static String _stableId(String subId, String key, Map<String, int> seen) {
    final n = seen[key] = (seen[key] ?? 0) + 1;
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(key)) {
      hash = (hash ^ unit) * 0x100000001b3;
    }
    return 'sealed-$subId-${hash.toUnsigned(64).toRadixString(16)}-$n';
  }

  /// Posts this device's key; returns the envelope sealed to it.
  Future<String> _register(
    SubscriptionUrl route, {
    bool refresh = false,
  }) async {
    final keys = sealedKeys;
    if (keys == null) {
      throw SubscriptionException('Sealed subscriptions are not supported');
    }
    final device = await extraHeaders?.call() ?? const {};
    final (body, _) = await _request(
      'POST',
      route,
      json: {
        'key': base64.encode(await keys.publicKey()),
        'os': ?device['x-device-os'],
        'model': ?device['x-device-model'],
        if (refresh) 'mode': 'refresh',
      },
    );
    return body;
  }

  List<Server> parse(String body, Subscription sub) {
    final text = body.trim();
    if (text.isEmpty) throw SubscriptionException('Subscription is empty');
    if (text.startsWith('{')) return _parseSingBox(text, sub);
    if (RegExp(r'^proxies:', multiLine: true).hasMatch(text)) {
      throw SubscriptionException('Clash YAML subscriptions are not supported');
    }
    final result = _parser.parseMany(
      text,
      group: sub.name,
      subscriptionId: sub.id,
    );
    if (result.servers.isEmpty) {
      throw SubscriptionException(result.failureSummary);
    }
    return result.servers;
  }

  List<Server> _parseSingBox(String text, Subscription sub) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      throw SubscriptionException('Invalid sing-box JSON: ${e.message}');
    }
    final outbounds = json is Map ? json['outbounds'] : null;
    if (outbounds is! List) {
      throw SubscriptionException('sing-box JSON has no "outbounds" list');
    }
    final servers = <Server>[];
    String? firstError;
    for (final o in outbounds.whereType<Map>()) {
      final outbound = Map<String, dynamic>.from(o);
      // selector/urltest/direct/block/dns are routing helpers, not servers.
      if (ServerProtocol.fromOutboundType(outbound['type'] as String?) ==
          null) {
        continue;
      }
      try {
        servers.add(
          OutboundCodec.fromOutbound(
            outbound,
            group: sub.name,
            subscriptionId: sub.id,
          ),
        );
      } on OutboundFormatException catch (e) {
        firstError ??= e.message;
      }
    }
    if (servers.isEmpty) {
      throw SubscriptionException(
        firstError ?? 'No supported outbounds in sing-box JSON',
      );
    }
    return servers;
  }

  static const _maxRedirects = 5;

  /// Redirects dart:io would follow: any for GET/HEAD, 303 for others.
  static bool _isRedirect(String method, int status) =>
      status == HttpStatus.seeOther ||
      ((method == 'GET' || method == 'HEAD') &&
          const {
            HttpStatus.movedPermanently,
            HttpStatus.found,
            HttpStatus.temporaryRedirect,
            HttpStatus.permanentRedirect,
          }.contains(status));

  /// Returns the body and its MIME type. Non-200 answers throw, with the
  /// service's `{"error": …}` message when it sent one.
  Future<(String, String?)> _request(
    String method,
    SubscriptionUrl route, {
    Map<String, Object>? json,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      // TLS ends on the link's endpoint, so the URL (and with it SNI and the
      // certificate check) names the endpoint; the inner service is picked by
      // the Host header alone. dart:io would rebuild Host on a redirect, so
      // redirects are followed here to keep it on same-host hops.
      var url = route.requestUrl;
      var host = route.hostHeader;
      var verb = method;
      var payload = json;
      for (var hops = 0; ; hops++) {
        final request = await client.openUrl(verb, url).timeout(_timeout);
        request.followRedirects = false;
        // Many panels pick the response format from the User-Agent.
        request.headers.set(HttpHeaders.userAgentHeader, 'WanX/0.1 sing-box');
        final extra = await extraHeaders?.call() ?? const {};
        extra.forEach(request.headers.set);
        if (host != null) request.headers.set(HttpHeaders.hostHeader, host);
        if (payload != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(payload));
        }
        final response = await request.close().timeout(_timeout);
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null && _isRedirect(verb, response.statusCode)) {
          if (hops == _maxRedirects) {
            throw SubscriptionException('Too many redirects');
          }
          await response.drain<void>().timeout(_timeout);
          final next = url.resolve(location);
          // The inner name only means something behind this endpoint.
          if (next.host != url.host) host = null;
          if (response.statusCode == HttpStatus.seeOther) {
            verb = 'GET';
            payload = null;
          }
          url = next;
          continue;
        }
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(_timeout);
        if (response.statusCode != HttpStatus.ok) {
          throw SubscriptionException(
            _serviceError(body, 'error') ??
                'HTTP ${response.statusCode} ${response.reasonPhrase}',
            status: response.statusCode,
            code: _serviceError(body, 'code'),
          );
        }
        return (body, response.headers.contentType?.mimeType);
      }
    } on TimeoutException {
      throw SubscriptionException('Timed out after ${_timeout.inSeconds}s');
    } on SocketException catch (e) {
      throw SubscriptionException(
        'Network error: ${e.osError?.message ?? e.message}',
      );
    } on HandshakeException catch (e) {
      throw SubscriptionException('TLS error: ${e.message}');
    } on HttpException catch (e) {
      throw SubscriptionException('HTTP error: ${e.message}');
    } on FormatException {
      throw SubscriptionException('Response is not valid UTF-8 text');
    } finally {
      client.close(force: true);
    }
  }

  /// [field] of the service's `{"error": …, "code": …}` answer.
  static String? _serviceError(String body, String field) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json[field] is String) {
        return json[field] as String;
      }
    } on FormatException {
      // Not the publisher service.
    }
    return null;
  }
}
