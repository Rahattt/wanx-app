/// A subscription URL plus the extras some CRMs pack into the `#` fragment.
///
/// Our CRM (and a few panels) hand out links like:
///
/// ```
/// https://api.example.com/v1/config?id=123#Tariff?endpoint=node1.example.com&header_host=panel.example.com
/// ```
///
/// Everything after `#` is a fragment, which is never sent on the wire. We read
/// it ourselves:
///
///  * The text before the first `?` is a human [label] for the profile card.
///  * The query-like tail routes the request through a balancer: the URL's
///    host becomes the `endpoint` address, which terminates TLS with its own
///    certificate (so SNI and the certificate check use it), and the inner
///    service is chosen by the `Host` header alone ([hostHeader], from
///    `header_host`). The older keys `resolve-address` (address) and `host`
///    (header) are still accepted.
class SubscriptionUrl {
  const SubscriptionUrl({
    required this.originalUrl,
    required this.requestUrl,
    this.label,
    this.hostHeader,
  });

  /// The validated link exactly as given, fragment and all. Stored on the
  /// subscription so the routing hints survive refreshes, and used for
  /// de-duplication and the fallback group name.
  final Uri originalUrl;

  /// The URL to request, fragment stripped, with the `endpoint` address (and
  /// its port, if given) in place of the link's host. TLS SNI and the
  /// certificate check follow its host.
  final Uri requestUrl;

  /// Name to show on the profile card, or null to fall back to the host. The
  /// parameter tail is never part of this.
  final String? label;

  /// Value for the HTTP `Host` header only (never SNI): `header_host`, else
  /// the link's own host when an `endpoint` replaced it, else null to let the
  /// client derive it from [requestUrl].
  final String? hostHeader;

  /// Whether the link carries `endpoint`/`header_host` routing hints. Only
  /// sealed (premium) subscriptions may use them.
  bool get routed =>
      hostHeader != null || requestUrl != originalUrl.removeFragment();

  /// Validates [raw] and splits off the fragment extras. Throws
  /// [FormatException] when it is not an http(s) URL or a hint is malformed.
  static SubscriptionUrl parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Not a valid URL');
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw FormatException(
        'Unsupported URL scheme "${uri.scheme}" (use https://)',
      );
    }

    // Uri.fragment stays percent-encoded (stray `%` already escaped), so an
    // encoded `?`, `&` or `=` in the label can't be mistaken for the tail.
    final fragment = uri.fragment;
    String? label;
    var endpoint = '';
    var header = '';
    final q = fragment.indexOf('?');
    final labelPart = (q == -1 ? fragment : fragment.substring(0, q)).trim();
    if (labelPart.isNotEmpty) {
      final decoded = Uri.decodeComponent(labelPart).trim();
      if (decoded.isNotEmpty) label = decoded;
    }
    if (q != -1) {
      final params = Uri.splitQueryString(fragment.substring(q + 1));
      endpoint = (params['endpoint'] ?? params['resolve-address'] ?? '').trim();
      header = (params['header_host'] ?? params['host'] ?? '').trim();
    }

    var requestUrl = uri.removeFragment();
    if (endpoint.isNotEmpty) {
      final (host, port) = _hostPort(endpoint, 'endpoint');
      requestUrl = requestUrl.replace(host: host, port: port ?? uri.port);
    }
    if (header.isNotEmpty) _hostPort(header, 'header_host');

    return SubscriptionUrl(
      originalUrl: uri,
      requestUrl: requestUrl,
      label: label,
      // With only an endpoint, the balancer still needs the link's own name.
      hostHeader: header.isNotEmpty
          ? header
          : (requestUrl.host != uri.host
                ? Uri(
                    host: uri.host,
                    port: uri.hasPort ? uri.port : null,
                  ).authority
                : null),
    );
  }

  /// Splits `host`, `host:port`, `[v6]:port` or a bare IPv6 literal.
  static (String, int?) _hostPort(String value, String key) {
    if (':'.allMatches(value).length > 1 && !value.startsWith('[')) {
      return (value.toLowerCase(), null);
    }
    final u = Uri.tryParse('//$value');
    if (u == null || u.host.isEmpty || u.path.isNotEmpty || u.hasQuery) {
      throw FormatException('Invalid $key "$value" in the link');
    }
    return (u.host, u.hasPort ? u.port : null);
  }
}
