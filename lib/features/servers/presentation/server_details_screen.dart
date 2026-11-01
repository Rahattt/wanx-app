import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../vpn/application/vpn_controller.dart';
import '../application/servers_controller.dart';
import '../domain/server.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components.dart';
import '../../../theme/motion.dart';
import '../domain/server_config.dart';
import '../domain/wireguard_obfuscation.dart';
import 'widgets/server_tile.dart';

/// View/edit a server profile, or create one by hand ([ServerDetailsScreen.create]).
/// Saving only updates the stored profile; an active tunnel is not restarted.
class ServerDetailsScreen extends ConsumerStatefulWidget {
  const ServerDetailsScreen({super.key, required String this.serverId})
    : newProtocol = null;

  /// Empty form for a manually entered server of [protocol].
  const ServerDetailsScreen.create({
    super.key,
    required ServerProtocol protocol,
  }) : serverId = null,
       newProtocol = protocol;

  final String? serverId;
  final ServerProtocol? newProtocol;

  @override
  ConsumerState<ServerDetailsScreen> createState() =>
      _ServerDetailsScreenState();
}

class _ServerDetailsScreenState extends ConsumerState<ServerDetailsScreen> {
  final _form = GlobalKey<FormState>();
  late final Server _original;

  late final _name = TextEditingController(text: _original.name);
  late final _host = TextEditingController(text: _original.host);
  late final _port = TextEditingController(text: '${_original.port}');
  late final _path = TextEditingController(text: _original.transport.path);
  late final _hostHeader = TextEditingController(
    text: _original.transport.host,
  );
  late final _sni = TextEditingController(text: _original.tls.sni);
  late final _alpn = TextEditingController(text: _original.tls.alpn.join(','));
  late final _fallbackDelay = TextEditingController(
    text: _original.obfuscation.fragmentFallbackDelayMs?.toString() ?? '',
  );
  late final _realityKey = TextEditingController(
    text: _original.obfuscation.realityPublicKey,
  );
  late final _realityShortId = TextEditingController(
    text: _original.obfuscation.realityShortId,
  );
  late final _uuid = TextEditingController(text: _setting('uuid'));
  late final _password = TextEditingController(text: _setting('password'));
  late final _alterId = TextEditingController(
    text: _setting('alter_id').isEmpty ? '0' : _setting('alter_id'),
  );
  late final _obfsPassword = TextEditingController(
    text: _original.settings['obfs'] is Map
        ? '${(_original.settings['obfs'] as Map)['password'] ?? ''}'
        : '',
  );

  late final _wgPrivateKey = TextEditingController(
    text: _setting('private_key'),
  );
  late final _wgAddress = TextEditingController(
    text: (_original.settings['address'] as List? ?? const []).join(', '),
  );
  late final _wgPeerKey = TextEditingController(text: _peer('public_key'));
  late final _wgPresharedKey = TextEditingController(
    text: _peer('pre_shared_key'),
  );
  late final _wgMtu = TextEditingController(text: _setting('mtu'));
  late bool _wgObfuscation = WireGuardObfuscation.isEnabled(_original.settings);

  late ServerProtocol _protocol = _original.protocol;
  late String _flow = _setting('flow');
  late String _vmessSecurity = _setting('security').isEmpty
      ? 'auto'
      : _setting('security');
  late String _ssMethod = _setting('method').isEmpty
      ? _ssMethods.first
      : _setting('method');
  late String _congestion = _setting('congestion_control').isEmpty
      ? 'bbr'
      : _setting('congestion_control');

  late TransportType _transportType = _original.transport.type;
  late String _xhttpMode = _original.transport.xhttpMode.isEmpty
      ? 'auto'
      : _original.transport.xhttpMode;
  late bool _tlsEnabled =
      _original.tls.enabled || _original.protocol.isUdpBased;
  late bool _insecure = _original.tls.insecure;
  late UtlsFingerprint _fingerprint = _original.obfuscation.fingerprint;
  late bool _fragment = _original.obfuscation.fragment;
  late bool _recordFragment = _original.obfuscation.recordFragment;
  late bool _reality = _original.obfuscation.reality;
  var _advancedOpen = false;

  bool get _creating => widget.newProtocol != null;

  AppLocalizations get l10n => context.l10n;

  String _setting(String key) => '${_original.settings[key] ?? ''}';

  Map<String, dynamic> get _firstPeer {
    final peers = _original.settings['peers'];
    return peers is List && peers.isNotEmpty && peers.first is Map
        ? Map<String, dynamic>.from(peers.first as Map)
        : <String, dynamic>{};
  }

  String _peer(String key) => '${_firstPeer[key] ?? ''}';

  static const _ssMethods = [
    '2022-blake3-aes-128-gcm',
    '2022-blake3-aes-256-gcm',
    '2022-blake3-chacha20-poly1305',
    'aes-128-gcm',
    'aes-192-gcm',
    'aes-256-gcm',
    'chacha20-ietf-poly1305',
    'xchacha20-ietf-poly1305',
    'none',
  ];
  static const _vmessSecurities = [
    'auto',
    'aes-128-gcm',
    'chacha20-poly1305',
    'none',
    'zero',
  ];
  static const _flows = ['', 'xtls-rprx-vision'];
  static const _congestionControls = ['bbr', 'cubic', 'new_reno'];

  @override
  void initState() {
    super.initState();
    if (widget.newProtocol case final protocol?) {
      _original = Server(
        id: const Uuid().v4(),
        name: '',
        protocol: protocol,
        host: '',
        port: switch (protocol) {
          ServerProtocol.shadowsocks => 8388,
          ServerProtocol.wireguard => 51820,
          _ => 443,
        },
        tls: TlsConfig(enabled: protocol == ServerProtocol.trojan),
      );
    } else {
      // Edits are made against a snapshot; the list may refresh underneath.
      _original = ref.read(serversProvider).value!.byId(widget.serverId!)!;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _host,
      _port,
      _path,
      _hostHeader,
      _sni,
      _alpn,
      _fallbackDelay,
      _realityKey,
      _realityShortId,
      _uuid,
      _password,
      _alterId,
      _obfsPassword,
      _wgPrivateKey,
      _wgAddress,
      _wgPeerKey,
      _wgPresharedKey,
      _wgMtu,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final protocol = _protocol;
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: FrostedAppBar(title: _creating ? l10n.newServer : _original.name),
      body: Form(
        key: _form,
        // Builder: the body's MediaQuery includes the frosted bars' heights;
        // the screen's own context does not.
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page,
                insets.top + AppSpacing.sm,
                AppSpacing.page,
                insets.bottom + AppSpacing.xl,
              ),
              children: [
                _Summary(server: _original, protocol: protocol),
                _Section(
                  title: l10n.sectionServer,
                  children: [
                    if (_creating)
                      _dropdown<ServerProtocol>(
                        label: l10n.fieldProtocol,
                        value: _protocol,
                        items: {
                          for (final p in ServerProtocol.values) p: p.label,
                        },
                        onChanged: (p) => setState(() => _protocol = p),
                      ),
                    _field(_name, l10n.fieldName, validator: _required),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _field(
                            _host,
                            l10n.fieldAddress,
                            validator: _required,
                            keyboard: TextInputType.url,
                          ),
                        ),
                        Container(
                          width: 0.5,
                          height: 56,
                          color: AppColors.of(context).separator,
                        ),
                        Expanded(
                          child: _field(
                            _port,
                            l10n.fieldPort,
                            validator: _validatePort,
                            keyboard: TextInputType.number,
                            digitsOnly: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _Section(
                  title: l10n.sectionAuth,
                  children: _authFields(protocol),
                ),
                if (protocol.supportsTransport)
                  _Section(
                    title: l10n.sectionTransport,
                    children: [
                      _dropdown<TransportType>(
                        label: l10n.fieldType,
                        value: _transportType,
                        items: {
                          for (final t in TransportType.values) t: t.label,
                        },
                        onChanged: (t) => setState(() => _transportType = t),
                      ),
                      if (_transportType != TransportType.tcp)
                        _field(
                          _path,
                          _transportType == TransportType.grpc
                              ? l10n.fieldServiceName
                              : l10n.fieldPath,
                        ),
                      if (_transportType != TransportType.tcp &&
                          _transportType != TransportType.grpc)
                        _field(_hostHeader, l10n.fieldHostHeader),
                      if (_transportType == TransportType.xhttp)
                        _dropdown<String>(
                          label: l10n.fieldXhttpMode,
                          value: _xhttpMode,
                          items: {for (final m in _xhttpModes) m: m},
                          onChanged: (m) => setState(() => _xhttpMode = m),
                        ),
                    ],
                  ),
                if (protocol.supportsTls)
                  _Section(
                    title: l10n.sectionTls,
                    reveal: _Revealed(
                      visible: _tlsEnabled || protocol.isUdpBased,
                      children: [
                        _field(_sni, l10n.fieldSni, hint: l10n.sniHint),
                        _field(_alpn, l10n.fieldAlpn, hint: l10n.alpnHint),
                        _SwitchRow(
                          title: l10n.allowInsecure,
                          subtitle: l10n.allowInsecureHint,
                          value: _insecure,
                          onChanged: (v) => setState(() => _insecure = v),
                        ),
                      ],
                    ),
                    children: [
                      _SwitchRow(
                        title: l10n.useTls,
                        subtitle: protocol.isUdpBased
                            ? l10n.tlsAlwaysOnQuic
                            : null,
                        value: _tlsEnabled || protocol.isUdpBased,
                        onChanged: protocol.isUdpBased
                            ? null
                            : (v) => setState(() => _tlsEnabled = v),
                      ),
                    ],
                  ),
                if (protocol.supportsTls) _advancedSection(),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Frosted(
        hairlineTop: true,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: FilledButton(onPressed: _save, child: Text(l10n.save)),
        ),
      ),
    );
  }

  /// Credentials of [protocol], stored as sing-box outbound fields.
  static const _xhttpModes = ['auto', 'packet-up', 'stream-up', 'stream-one'];

  TransportConfig _transport() {
    final t = _original.transport.copyWith(
      type: _transportType,
      path: _path.text.trim(),
      host: _hostHeader.text.trim(),
    );
    if (_transportType != TransportType.xhttp) return t;
    final extra = Map<String, dynamic>.of(t.extra)..remove('mode');
    if (_xhttpMode != 'auto') extra['mode'] = _xhttpMode;
    return t.copyWith(extra: extra);
  }

  List<Widget> _authFields(ServerProtocol protocol) {
    Widget uuid() => _field(
      _uuid,
      'UUID',
      validator: _required,
      hint: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    );
    Widget password({bool required = true}) => _field(
      _password,
      l10n.fieldPassword,
      validator: required ? _required : null,
    );
    return switch (protocol) {
      ServerProtocol.vless => [
        uuid(),
        _dropdown<String>(
          label: 'Flow',
          value: _flow,
          items: {
            for (final f in _withCurrent(_flows, _flow))
              f: f.isEmpty ? l10n.none : f,
          },
          onChanged: (v) => setState(() => _flow = v),
        ),
      ],
      ServerProtocol.vmess => [
        uuid(),
        _field(
          _alterId,
          'Alter ID',
          keyboard: TextInputType.number,
          digitsOnly: true,
        ),
        _dropdown<String>(
          label: l10n.fieldEncryption,
          value: _vmessSecurity,
          items: {
            for (final m in _withCurrent(_vmessSecurities, _vmessSecurity))
              m: m,
          },
          onChanged: (v) => setState(() => _vmessSecurity = v),
        ),
      ],
      ServerProtocol.trojan => [password()],
      ServerProtocol.shadowsocks => [
        _dropdown<String>(
          label: l10n.fieldEncryption,
          value: _ssMethod,
          items: {for (final m in _withCurrent(_ssMethods, _ssMethod)) m: m},
          onChanged: (v) => setState(() => _ssMethod = v),
        ),
        password(),
      ],
      ServerProtocol.hysteria2 => [
        password(),
        _field(_obfsPassword, l10n.fieldObfsPassword, hint: l10n.optional),
      ],
      ServerProtocol.wireguard => _wireGuardFields(),
      ServerProtocol.tuic => [
        uuid(),
        password(),
        _dropdown<String>(
          label: l10n.fieldCongestion,
          value: _congestion,
          items: {
            for (final c in _withCurrent(_congestionControls, _congestion))
              c: c,
          },
          onChanged: (v) => setState(() => _congestion = v),
        ),
      ],
    };
  }

  List<Widget> _wireGuardFields() {
    // Server-side AWG parameters can't be dropped: the server needs them.
    final amneziaServer = WireGuardObfuscation.needsAmneziaServer(
      _original.settings,
    );
    return [
      _field(_wgPrivateKey, l10n.fieldPrivateKey, validator: _required),
      _field(
        _wgAddress,
        l10n.fieldAddresses,
        hint: '10.0.0.2/32, fd00::2/128',
        validator: _required,
      ),
      _field(_wgPeerKey, l10n.fieldPeerPublicKey, validator: _required),
      _field(_wgPresharedKey, l10n.fieldPresharedKey, hint: l10n.optional),
      _field(
        _wgMtu,
        'MTU',
        hint: l10n.optional,
        keyboard: TextInputType.number,
        digitsOnly: true,
      ),
      _SwitchRow(
        title: l10n.wgObfuscation,
        subtitle: amneziaServer
            ? l10n.wgObfuscationAmneziaServer
            : l10n.wgObfuscationHint,
        value: _wgObfuscation || amneziaServer,
        onChanged: amneziaServer
            ? null
            : (v) => setState(() => _wgObfuscation = v),
      ),
    ];
  }

  Map<String, dynamic> _wireGuardSettings(Map<String, dynamic> base) {
    final psk = _wgPresharedKey.text.trim();
    final peers = _original.settings['peers'] as List? ?? const [];
    final peer = {
      ..._firstPeer,
      'public_key': _wgPeerKey.text.trim(),
      'allowed_ips': _firstPeer['allowed_ips'] ?? const ['0.0.0.0/0', '::/0'],
    }..remove('pre_shared_key');
    final settings = {
      ...base,
      'private_key': _wgPrivateKey.text.trim(),
      'address': [
        for (final a in _wgAddress.text.split(','))
          if (a.trim().isNotEmpty) a.trim(),
      ],
      if (int.tryParse(_wgMtu.text) case final mtu? when mtu > 0) 'mtu': mtu,
      'peers': [
        {...peer, if (psk.isNotEmpty) 'pre_shared_key': psk},
        ...peers.skip(1),
      ],
    };
    return _wgObfuscation
        ? WireGuardObfuscation.enable(settings)
        : WireGuardObfuscation.disable(settings);
  }

  /// [options], plus [current] if an imported profile uses something else.
  static List<String> _withCurrent(List<String> options, String current) =>
      options.contains(current) ? options : [...options, current];

  /// Outbound fields for the chosen protocol. Unmodelled fields of the
  /// original profile are kept when the protocol didn't change.
  Map<String, dynamic> _buildSettings() {
    const credentialKeys = {
      'uuid',
      'password',
      'flow',
      'alter_id',
      'security',
      'method',
      'obfs',
      'congestion_control',
      'private_key',
      'address',
      'mtu',
    };
    final out = <String, dynamic>{
      if (_protocol == _original.protocol)
        for (final e in _original.settings.entries)
          if (!credentialKeys.contains(e.key)) e.key: e.value,
    };
    final uuid = _uuid.text.trim();
    final password = _password.text;
    switch (_protocol) {
      case ServerProtocol.vless:
        out['uuid'] = uuid;
        if (_flow.isNotEmpty) out['flow'] = _flow;
      case ServerProtocol.vmess:
        out['uuid'] = uuid;
        out['alter_id'] = int.tryParse(_alterId.text) ?? 0;
        out['security'] = _vmessSecurity;
      case ServerProtocol.trojan:
        out['password'] = password;
      case ServerProtocol.shadowsocks:
        out['method'] = _ssMethod;
        out['password'] = password;
      case ServerProtocol.hysteria2:
        out['password'] = password;
        final obfs = _obfsPassword.text.trim();
        if (obfs.isNotEmpty) {
          out['obfs'] = {'type': 'salamander', 'password': obfs};
        }
      case ServerProtocol.tuic:
        out['uuid'] = uuid;
        out['password'] = password;
        out['congestion_control'] = _congestion;
      case ServerProtocol.wireguard:
        return _wireGuardSettings(out);
    }
    return out;
  }

  /// Collapsed by default so circumvention options aren't front and centre.
  Widget _advancedSection() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child:
          GroupedCard(
            children: [
              Pressable(
                onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                scale: 1,
                pressedOpacity: 0.6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.advanced,
                              style: theme.textTheme.bodyLarge,
                            ),
                            Text(
                              l10n.advancedHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _advancedOpen ? 0.25 : 0,
                        duration: AppMotion.medium,
                        curve: AppMotion.emphasized,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ).withReveal(
            _Revealed(
              visible: _advancedOpen,
              children: [
                _dropdown<UtlsFingerprint>(
                  label: l10n.utlsFingerprint,
                  value: _fingerprint,
                  items: {for (final f in UtlsFingerprint.values) f: f.label},
                  onChanged: (f) => setState(() => _fingerprint = f),
                ),
                _SwitchRow(
                  title: l10n.tlsFragmentation,
                  subtitle: l10n.tlsFragmentationHint,
                  value: _fragment,
                  onChanged: (v) => setState(() => _fragment = v),
                ),
                _Revealed(
                  visible: _fragment,
                  children: [
                    _SwitchRow(
                      title: l10n.recordFragmentation,
                      subtitle: l10n.recordFragmentationHint,
                      value: _recordFragment,
                      onChanged: (v) => setState(() => _recordFragment = v),
                    ),
                    _field(
                      _fallbackDelay,
                      l10n.fallbackDelay,
                      hint: l10n.fallbackDelayHint,
                      keyboard: TextInputType.number,
                      digitsOnly: true,
                    ),
                  ],
                ),
                _SwitchRow(
                  title: l10n.reality,
                  value: _reality,
                  onChanged: (v) => setState(() => _reality = v),
                ),
                _Revealed(
                  visible: _reality,
                  children: [
                    _field(_realityKey, l10n.publicKey, validator: _required),
                    _field(_realityShortId, l10n.shortId, hint: l10n.optional),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  /// Borderless input sitting directly in a grouped card row.
  static const _bare = InputDecoration(
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
  );

  Widget _dropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      // Keyed by label: rows swap when the protocol changes.
      key: ValueKey(label),
      initialValue: value,
      decoration: _bare.copyWith(labelText: label),
      borderRadius: AppRadius.mdAll,
      dropdownColor: AppColors.of(context).card,
      icon: Icon(
        Icons.unfold_more_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.outline,
      ),
      items: [
        for (final MapEntry(:key, value: text) in items.entries)
          DropdownMenuItem(value: key, child: Text(text)),
      ],
      onChanged: (v) => onChanged(v as T),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    bool digitsOnly = false,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboard,
      autocorrect: false,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
      ),
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: _bare.copyWith(labelText: label, hintText: hint),
      validator: validator,
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? l10n.required : null;

  String? _validatePort(String? v) {
    final port = int.tryParse(v ?? '');
    return port == null || port < 1 || port > 65535 ? l10n.portRange : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_reality && !_tlsEnabled && !_protocol.isUdpBased) {
      _snack(l10n.realityNeedsTls);
      return;
    }
    // Fields in the collapsed Advanced section aren't validated by the form.
    if (_reality && _realityKey.text.trim().isEmpty) {
      _snack(l10n.realityNeedsKey);
      return;
    }
    final tlsEnabled = _tlsEnabled || _protocol.isUdpBased;
    final updated = Server(
      id: _original.id,
      name: _name.text.trim(),
      protocol: _protocol,
      host: _host.text.trim(),
      port: int.parse(_port.text),
      settings: _buildSettings(),
      group: _original.group,
      subscriptionId: _original.subscriptionId,
      transport: _transport(),
      tls: _original.tls.copyWith(
        enabled: tlsEnabled,
        sni: _sni.text.trim(),
        alpn: _alpn.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        insecure: _insecure,
      ),
      obfuscation: ObfuscationConfig(
        fingerprint: _fingerprint,
        fragment: _fragment,
        recordFragment: _fragment && _recordFragment,
        fragmentFallbackDelayMs: _fragment
            ? int.tryParse(_fallbackDelay.text)
            : null,
        reality: _reality,
        realityPublicKey: _reality ? _realityKey.text.trim() : '',
        realityShortId: _reality ? _realityShortId.text.trim() : '',
      ),
      // latencyMs left null: the old measurement no longer applies.
    );
    final controller = ref.read(serversProvider.notifier);
    if (_creating) {
      await controller.addServer(updated);
      if (!mounted) return;
      _snack(l10n.serverAdded);
      Navigator.pop(context);
      return;
    }
    await controller.saveServer(updated);
    if (!mounted) return;
    // The active server changed: apply it to a running tunnel right away.
    if (ref.read(serversProvider).value?.selectedId == updated.id) {
      unawaited(ref.read(vpnProvider.notifier).reconnect(updated));
    }
    _snack(l10n.saved);
    Navigator.pop(context);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Protocol and where the profile comes from, above the form.
class _Summary extends StatelessWidget {
  const _Summary({required this.server, required this.protocol});

  final Server server;
  final ServerProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        0,
      ),
      child: Row(
        children: [
          ProtocolBadge(protocol: protocol, selected: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              server.isFromSubscription
                  ? l10n.fromProvider(server.group ?? '')
                  : l10n.addedManually,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings-style section: small caps label over a grouped card. [reveal]
/// rows animate in below [children].
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.reveal});

  final String title;
  final List<Widget> children;
  final _Revealed? reveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = GroupedCard(children: children);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              6,
            ),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (reveal == null) card else card.withReveal(reveal!),
        ],
      ),
    );
  }
}

/// Rows that slide open under the row that controls them.
class _Revealed extends StatelessWidget {
  const _Revealed({required this.visible, required this.children});

  final bool visible;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      visible: visible,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children) ...[
            if (child is! _Revealed) const CardSeparator(),
            child,
          ],
        ],
      ),
    );
  }
}

extension on GroupedCard {
  /// Same card with [reveal] appended as its last, animated row.
  GroupedCard withReveal(_Revealed reveal) => GroupedCard(
    separatorIndent: separatorIndent,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...children.expandIndexed(separatorIndent), reveal],
      ),
    ],
  );
}

extension on List<Widget> {
  Iterable<Widget> expandIndexed(double indent) sync* {
    for (var i = 0; i < length; i++) {
      if (i > 0) yield CardSeparator(indent: indent);
      yield this[i];
    }
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      activeTrackColor: theme.colorScheme.primary,
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}
