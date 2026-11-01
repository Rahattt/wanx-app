import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/platform/app_foreground.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/motion.dart';
import '../../../../core/platform/vpn_channel.dart';
import '../../../../core/util/format.dart';
import '../../../../l10n/l10n.dart';
import '../../../vpn/domain/vpn_status.dart';
import '../../domain/server.dart';

/// Connection state and the connect/disconnect button — the focal point of
/// the main screen.
///
/// Motion: waves ripple outward while connecting (inward, faster, while
/// disconnecting); the button fills with the accent and pops on connect;
/// it shakes on failure. Each transition also gives a light haptic.
class ConnectionCard extends StatefulWidget {
  const ConnectionCard({
    super.key,
    required this.vpn,
    required this.server,
    required this.onToggle,
    this.traffic,
    this.onCheck,
  });

  final VpnState vpn;
  final Server? server;
  final VoidCallback onToggle;

  /// Live throughput while connected.
  final TrafficStats? traffic;

  /// Tapping the traffic tiles sends a real request through the tunnel;
  /// returns the round trip in ms, or null when the server didn't answer.
  final Future<int?> Function()? onCheck;

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard>
    with TickerProviderStateMixin {
  static const _buttonSize = 128.0;
  static const _waveReach = 40.0;

  /// Vertical room around the button; waves and glow overflow into the
  /// neighbouring space instead of pushing the layout down.
  static const _halo = 16.0;

  late final _waves = AnimationController(vsync: this);
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// 1 → 1.08 → 1: a soft pop rather than a bounce.
  late final _popScale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.08,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 60,
    ),
  ]).animate(_pop);

  VpnStatus get _status => widget.vpn.status;

  /// Recent per-second rates for the sparklines, oldest first.
  static const _historyLength = 30;
  final _upHistory = <int>[];
  final _downHistory = <int>[];

  void _record(TrafficStats? t) {
    if (t == null) return;
    for (final (list, v) in [
      (_upHistory, t.uplink),
      (_downHistory, t.downlink),
    ]) {
      list.add(v);
      if (list.length > _historyLength) list.removeAt(0);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncWaves();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _syncProbe();
  }

  @override
  void didUpdateWidget(ConnectionCard old) {
    super.didUpdateWidget(old);
    if (_status != VpnStatus.connected) {
      _upHistory.clear();
      _downHistory.clear();
    } else if (!identical(old.traffic, widget.traffic)) {
      _record(widget.traffic);
    }
    final from = old.vpn.status;
    final to = _status;
    if (from == to) return;
    _syncWaves();
    _syncProbe();
    switch (to) {
      case VpnStatus.connected:
        _pop.forward(from: 0);
        HapticFeedback.mediumImpact();
      case VpnStatus.error:
        _shake.forward(from: 0);
        HapticFeedback.heavyImpact();
      case VpnStatus.disconnected when from == VpnStatus.disconnecting:
        HapticFeedback.lightImpact();
      default:
        break;
    }
  }

  void _syncWaves() {
    if (_status.isBusy) {
      _waves.duration = _status == VpnStatus.connecting
          ? const Duration(milliseconds: 1800)
          : const Duration(milliseconds: 1200);
      _waves.repeat();
    } else {
      _waves.stop();
      _waves.value = 0;
    }
  }

  /// The tunnel is up but nothing gets through: the heartbeat flatlines.
  var _flatline = false;
  Timer? _probe;

  /// Bumped on every reschedule so a check still in flight from an older
  /// session doesn't start a second chain.
  var _probeRun = 0;

  /// Checks are for the person looking at the screen; in the background
  /// (Android keeps the process alive for the VPN) they only cost battery.
  late final AppLifecycleListener _lifecycle;
  var _visible = AppForeground.isVisible(
    WidgetsBinding.instance.lifecycleState,
  );

  void _onLifecycle(AppLifecycleState state) {
    final visible = AppForeground.isVisible(state);
    if (visible == _visible) return;
    _visible = visible;
    // Back on screen: re-check soon rather than show a stale pulse.
    _syncProbe();
  }

  /// While connected, quietly check that traffic really flows: soon after
  /// connecting, then every so often — more often while flatlined, so the
  /// pulse comes back as soon as the server does.
  void _syncProbe() {
    _probe?.cancel();
    _probeRun++;
    if (_status == VpnStatus.connected) {
      if (!_visible) return;
      _probe = Timer(const Duration(seconds: 2), _runProbe);
    } else if (_flatline) {
      setState(() => _flatline = false);
    }
  }

  Future<void> _runProbe() async {
    final check = widget.onCheck;
    if (check == null) return;
    final run = _probeRun;
    final ms = await check();
    if (!mounted || run != _probeRun) return;
    _setFlatline(ms == null);
    _probe = Timer(Duration(seconds: _flatline ? 8 : 30), _runProbe);
  }

  void _setFlatline(bool flat) {
    if (flat == _flatline) return;
    if (flat) HapticFeedback.heavyImpact();
    setState(() => _flatline = flat);
  }

  @override
  void dispose() {
    _probe?.cancel();
    _lifecycle.dispose();
    _checkReset?.cancel();
    _waves.dispose();
    _pop.dispose();
    _shake.dispose();
    super.dispose();
  }

  /// null = no result shown; (ms: null) = checking; -1 = failed.
  ({int? ms})? _check;
  Timer? _checkReset;

  Future<void> _runCheck() async {
    final check = widget.onCheck;
    // Ignore taps while a check is already running.
    if (check == null || (_check != null && _check!.ms == null)) return;
    _checkReset?.cancel();
    HapticFeedback.selectionClick();
    setState(() => _check = (ms: null));
    final ms = await check();
    if (!mounted) return;
    ms == null ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    if (_status == VpnStatus.connected) setState(() => _flatline = ms == null);
    setState(() => _check = (ms: ms ?? -1));
    _checkReset = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _check = null);
    });
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final status = _status;
    final connected = status == VpnStatus.connected;
    final enabled = !status.isBusy && (widget.server != null || connected);
    final traffic = widget.traffic ?? const TrafficStats();

    // Faster on the way down, like the system toggles.
    final duration = connected || status == VpnStatus.connecting
        ? AppMotion.slow
        : AppMotion.medium;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        0,
      ),
      child: Column(
        children: [
          // Outgoing on the left, incoming on the right, flanking the
          // button so the traffic takes no vertical room.
          // Bottom-aligned so the settings button above-left stays clear.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _TrafficSide(
                  visible: connected,
                  from: const Offset(0.3, 0),
                  delay: Duration.zero,
                  onTap: widget.onCheck == null ? null : _runCheck,
                  child: _TrafficTile(
                    upward: true,
                    color: _uplinkColor(colors.accent),
                    label: context.l10n.upload,
                    rate: traffic.uplink,
                    total: traffic.uplinkTotal,
                    history: _upHistory,
                  ),
                ),
              ),
              _button(status, enabled, duration, colors),
              Expanded(
                child: _TrafficSide(
                  visible: connected,
                  from: const Offset(-0.3, 0),
                  delay: const Duration(milliseconds: 90),
                  onTap: widget.onCheck == null ? null : _runCheck,
                  child: _TrafficTile(
                    upward: false,
                    color: colors.accent,
                    label: context.l10n.download,
                    rate: traffic.downlink,
                    total: traffic.downlinkTotal,
                    history: _downHistory,
                  ),
                ),
              ),
            ],
          ),
          // Check result while connected, the reason while failed.
          AnimatedSize(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              child: switch (status) {
                VpnStatus.connected when _check != null => Padding(
                  key: const ValueKey('check'),
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _CheckResult(ms: _check!.ms),
                ),
                _ when widget.vpn.error != null => Padding(
                  key: const ValueKey('error'),
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    widget.vpn.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.danger,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _ => const SizedBox(width: double.infinity),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(
    VpnStatus status,
    bool enabled,
    Duration duration,
    AppColors colors,
  ) {
    return SizedBox.square(
      dimension: _buttonSize + _halo * 2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ambient glow that brightens with the connection.
          Positioned.fill(
            left: _halo - _waveReach,
            right: _halo - _waveReach,
            top: _halo - _waveReach,
            bottom: _halo - _waveReach,
            child: AnimatedOpacity(
              opacity: switch (status) {
                VpnStatus.connected => 1,
                VpnStatus.connecting || VpnStatus.disconnecting => 0.5,
                _ => 0,
              },
              duration: duration,
              curve: AppMotion.standard,
              // Two thin rings instead of a glow.
              child: Padding(
                padding: EdgeInsets.all(_waveReach - _halo),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (status.isBusy)
            Positioned.fill(
              left: _halo - _waveReach,
              right: _halo - _waveReach,
              top: _halo - _waveReach,
              bottom: _halo - _waveReach,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _WavesPainter(
                    progress: _waves,
                    color: colors.accent,
                    innerRadius: _buttonSize / 2,
                    reach: _waveReach,
                    inward: status == VpnStatus.disconnecting,
                  ),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: Listenable.merge([_pop, _shake]),
            builder: (context, child) {
              final t = _shake.value;
              final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(scale: _popScale.value, child: child),
              );
            },
            child: _PowerButton(
              status: status,
              enabled: enabled,
              size: _buttonSize,
              duration: duration,
              flatline: _flatline,
              onTap: enabled ? _onTap : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.status,
    required this.enabled,
    required this.size,
    required this.duration,
    required this.flatline,
    required this.onTap,
  });

  final VpnStatus status;
  final bool enabled;
  final double size;
  final Duration duration;

  /// Connected but nothing gets through; see [_Heartbeat.flat].
  final bool flatline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final connected = status == VpnStatus.connected;

    // Outlined ring on a dark core; the ring carries the state colour.
    final (fill, ring, iconColor, glow) = switch (status) {
      VpnStatus.connected => (
        colors.accentSoft,
        colors.accent,
        colors.accent,
        colors.accent.withValues(alpha: 0.08),
      ),
      VpnStatus.connecting || VpnStatus.disconnecting => (
        colors.accentSoft,
        colors.accent.withValues(alpha: 0.5),
        colors.accent.withValues(alpha: 0.8),
        Colors.transparent,
      ),
      VpnStatus.error => (
        colors.dangerSoft,
        colors.danger,
        colors.danger,
        colors.danger.withValues(alpha: 0.08),
      ),
      _ => (
        colors.card,
        colors.fill,
        enabled ? colors.accent : scheme.outline,
        Colors.transparent,
      ),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: status == VpnStatus.connected
          ? context.l10n.disconnect
          : context.l10n.connect,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        pressedOpacity: 0.9,
        child: _Heartbeat(
          active: connected,
          flat: flatline,
          flatColor: colors.danger,
          color: Theme.of(context).brightness == Brightness.dark
              ? colors.accent
              : colors.accentStrong,
          size: size,
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.standard,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: ring, width: 3),
              boxShadow: [BoxShadow(color: glow, spreadRadius: 6)],
            ),
            // Connected: the icon steps up and shrinks to make room for
            // the heartbeat trace below it.
            child: AnimatedAlign(
              duration: duration,
              curve: AppMotion.emphasized,
              alignment: connected
                  ? const Alignment(0, -0.42)
                  : Alignment.center,
              child: AnimatedScale(
                duration: duration,
                curve: AppMotion.emphasized,
                scale: connected ? 0.6 : 1,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: iconColor),
                  duration: duration,
                  curve: AppMotion.standard,
                  builder: (context, color, _) => Icon(
                    Icons.power_settings_new_rounded,
                    size: 48,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A heart monitor inside the connected button: a pen sweeps an ECG trace
/// left to right, leaving a fading tail, and the button gives a double
/// "lub-dub" as the spike passes the centre. Fades in on connect, out on
/// disconnect; a still trace when the system asks for reduced motion.
class _Heartbeat extends StatefulWidget {
  const _Heartbeat({
    required this.active,
    required this.flat,
    required this.color,
    required this.flatColor,
    required this.size,
    required this.child,
  });

  final bool active;

  /// No pulse: the trace levels out into a red line and the button stops
  /// beating, while the pen keeps sweeping like a monitor that is still on.
  final bool flat;
  final Color color;
  final Color flatColor;
  final double size;
  final Widget child;

  @override
  State<_Heartbeat> createState() => _HeartbeatState();
}

class _HeartbeatState extends State<_Heartbeat>
    with SingleTickerProviderStateMixin {
  // ~50 bpm: calm, "all is well" rather than alarm.
  late final _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Heartbeat old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  bool get _still => MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (widget.active && !_still) {
      if (!_beat.isAnimating) _beat.repeat();
    } else {
      _beat.stop();
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  /// Button scale offset: a strong beat then a softer echo, both short.
  static double _pump(double t) {
    double bump(double at, double width) {
      final d = (t - at) / width;
      return math.exp(-d * d);
    }

    return 0.035 * bump(0.36, 0.035) + 0.018 * bump(0.5, 0.04);
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.active ? 1 : 0),
      duration: AppMotion.slow,
      curve: AppMotion.standard,
      child: widget.child,
      builder: (context, presence, button) => TweenAnimationBuilder<double>(
        tween: Tween(end: widget.flat ? 0 : 1),
        duration: const Duration(milliseconds: 700),
        curve: AppMotion.emphasized,
        child: button,
        builder: (context, pulse, button) => AnimatedBuilder(
          animation: _beat,
          child: button,
          builder: (context, button) {
            final t = still ? 1.0 : _beat.value;
            return Transform.scale(
              scale: 1 + presence * pulse * _pump(t),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The beat only scales the button; keep its own painting.
                  RepaintBoundary(child: button),
                  if (presence > 0)
                    Positioned(
                      left: widget.size * 0.2,
                      right: widget.size * 0.2,
                      top: widget.size * 0.5,
                      height: widget.size * 0.28,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _EcgPainter(
                            head: t,
                            presence: presence,
                            pulse: pulse,
                            color: Color.lerp(
                              widget.flatColor,
                              widget.color,
                              pulse,
                            )!,
                            still: still,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One ECG cycle across the width, written by a pen at [head] (0..1).
/// Behind the pen the line fades with age; just ahead of it is a blank gap,
/// like a monitor overwriting its last sweep.
class _EcgPainter extends CustomPainter {
  const _EcgPainter({
    required this.head,
    required this.presence,
    required this.pulse,
    required this.color,
    required this.still,
  });

  final double head;
  final double presence;

  /// Wave height: 1 = beating, 0 = flat line.
  final double pulse;
  final Color color;
  final bool still;

  /// Height of the trace at [u] (0..1), baseline 0, peak 1: P, QRS, T.
  static double _wave(double u) {
    double bump(double at, double width) {
      final d = (u - at) / width;
      return math.exp(-d * d);
    }

    return 0.12 * bump(0.18, 0.04) -
        0.12 * bump(0.32, 0.012) +
        1.0 * bump(0.36, 0.014) -
        0.28 * bump(0.4, 0.014) +
        0.24 * bump(0.6, 0.05);
  }

  static const _steps = 120;

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height * 0.78;
    final amp = size.height * 0.78;
    Offset at(double u) =>
        Offset(u * size.width, base - _wave(u) * amp * pulse);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _steps; i++) {
      final u0 = i / _steps;
      final u1 = (i + 1) / _steps;
      // How long ago the pen passed here, as a fraction of a sweep.
      final age = still ? 0.0 : (head - u1) % 1.0;
      if (age > 0.82) continue;
      final fade = math.pow(1 - age / 0.82, 1.6).toDouble();
      // Soften the ends so the trace dissolves into the button.
      final edge = math.min(1.0, math.min(u0, 1 - u1) * 8);
      line.color = color.withValues(alpha: presence * fade * edge);
      canvas.drawLine(at(u0), at(u1), line);
    }

    if (still) return;
    final pen = at(head);
    final edge = math.min(1.0, math.min(head, 1 - head) * 8);
    canvas
      ..drawCircle(
        pen,
        6,
        Paint()
          ..color = color.withValues(alpha: 0.35 * presence * edge)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(
        pen,
        2.6,
        Paint()..color = color.withValues(alpha: presence * edge),
      );
  }

  @override
  bool shouldRepaint(_EcgPainter old) =>
      old.head != head ||
      old.presence != presence ||
      old.pulse != pulse ||
      old.color != color ||
      old.still != still;
}

/// Two rings travelling between the button edge and [reach] beyond it,
/// fading as they go. Outward while connecting, inward while disconnecting.
class _WavesPainter extends CustomPainter {
  _WavesPainter({
    required this.progress,
    required this.color,
    required this.innerRadius,
    required this.reach,
    required this.inward,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final double innerRadius;
  final double reach;
  final bool inward;

  static const _rings = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < _rings; i++) {
      final raw = (progress.value + i / _rings) % 1.0;
      final t = Curves.easeOut.transform(inward ? 1 - raw : raw);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 6 * (1 - t)
        ..color = color.withValues(alpha: 0.28 * (1 - t));
      canvas.drawCircle(center, innerRadius + reach * t, paint);
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) =>
      old.color != color || old.inward != inward;
}

/// Connection state as a tinted pill, centred in the top bar between the
/// app name and the actions.
class ConnectionStatusTitle extends StatelessWidget {
  const ConnectionStatusTitle({super.key, required this.status});

  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final (label, color) = switch (status) {
      VpnStatus.connected => (l10n.statusConnected, colors.accent),
      VpnStatus.connecting => (l10n.statusConnecting, colors.accent),
      VpnStatus.disconnecting => (l10n.statusDisconnecting, colors.accent),
      VpnStatus.error => (l10n.statusFailed, colors.danger),
      VpnStatus.disconnected => (
        l10n.statusDisconnected,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return Center(
      child: _FadeSwitch(
        child: Container(
          key: ValueKey(label),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: const BorderRadius.all(Radius.circular(99)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cross-fade with a small upward slide for status text.
class _FadeSwitch extends StatelessWidget {
  const _FadeSwitch({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.standard,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Uplink gets the accent shifted towards amber, so the two directions read
/// apart at a glance while staying in the brand's family.
Color _uplinkColor(Color accent) {
  final hsl = HSLColor.fromColor(accent);
  return hsl.withHue((hsl.hue - 18) % 360).toColor();
}

/// Fades a traffic tile in beside the button, sliding out from under it.
class _TrafficSide extends StatefulWidget {
  const _TrafficSide({
    required this.visible,
    required this.from,
    required this.delay,
    required this.onTap,
    required this.child,
  });

  final bool visible;

  /// Where the tile starts relative to its resting place, as a fraction of
  /// its size — towards the button.
  final Offset from;

  /// Stagger so the two tiles don't land in lockstep.
  final Duration delay;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_TrafficSide> createState() => _TrafficSideState();
}

class _TrafficSideState extends State<_TrafficSide>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: widget.visible ? 1 : 0,
  );
  Timer? _delay;

  @override
  void didUpdateWidget(_TrafficSide old) {
    super.didUpdateWidget(old);
    if (old.visible == widget.visible) return;
    _delay?.cancel();
    if (widget.visible) {
      _delay = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = CurvedAnimation(
      parent: _c,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    return IgnorePointer(
      ignoring: !widget.visible,
      child: Padding(
        // Level with the bottom of the button rather than its halo.
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Opacity(
            opacity: Curves.easeOut.transform(_c.value),
            child: FractionalTranslation(
              translation: Offset.lerp(widget.from, Offset.zero, move.value)!,
              child: Transform.scale(
                scale: 0.85 + 0.15 * move.value,
                child: child,
              ),
            ),
          ),
          child: Center(
            child: Pressable(
              onTap: widget.onTap,
              scale: 0.95,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// One direction of traffic: an animated arrow, the rate counting smoothly
/// to its latest value, the session total, and a live sparkline behind.
class _TrafficTile extends StatelessWidget {
  const _TrafficTile({
    required this.upward,
    required this.color,
    required this.label,
    required this.rate,
    required this.total,
    required this.history,
  });

  final bool upward;
  final Color color;
  final String label;
  final int rate;
  final int total;
  final List<int> history;

  /// Below this the line is effectively idle (keep-alives, DNS).
  static const _activeRate = 1024;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    const tabular = [FontFeature.tabularFigures()];
    final active = rate >= _activeRate;
    return Semantics(
      label: '$label ${context.l10n.perSecond(formatBytes(rate))}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.standard,
        constraints: const BoxConstraints(maxWidth: 104),
        decoration: BoxDecoration(
          color: colors.card,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(color.withValues(alpha: 0.10), colors.card),
              colors.card,
            ],
          ),
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: color.withValues(alpha: active ? 0.45 : 0.18),
          ),
          boxShadow: [
            ...colors.cardShadow,
            BoxShadow(
              color: color.withValues(alpha: active ? 0.22 : 0),
              blurRadius: 18,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: CustomPaint(
            painter: _SparklinePainter(history: history, color: color),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm + 2,
                AppSpacing.sm,
                AppSpacing.sm + 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FlowingArrow(upward: upward, color: color, active: active),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: rate.toDouble()),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.l10n.perSecond(formatBytes(v.round())),
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: tabular,
                        ),
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatBytes(total),
                      maxLines: 1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Arrow in a tinted badge; while data flows it streams continuously in
/// its direction, otherwise it rests.
class _FlowingArrow extends StatefulWidget {
  const _FlowingArrow({
    required this.upward,
    required this.color,
    required this.active,
  });

  final bool upward;
  final Color color;
  final bool active;

  @override
  State<_FlowingArrow> createState() => _FlowingArrowState();
}

class _FlowingArrowState extends State<_FlowingArrow>
    with SingleTickerProviderStateMixin {
  static const _size = 28.0;

  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_FlowingArrow old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _c.repeat();
    } else {
      _c.animateTo(0, duration: AppMotion.medium);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.upward
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final dir = widget.upward ? -1.0 : 1.0;
    return AnimatedContainer(
      duration: AppMotion.medium,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: widget.active ? 0.22 : 0.12),
      ),
      child: ClipOval(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_c.value);
            // Two copies one badge apart: one leaves as the next arrives.
            return Stack(
              alignment: Alignment.center,
              children: [
                for (final shift in [0.0, -1.0])
                  Transform.translate(
                    offset: Offset(0, dir * (t + shift) * _size),
                    child: Icon(icon, size: 16, color: widget.color),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Rate history as a soft filled curve along the bottom of a tile, scaled
/// to its own peak so even slow links show shape.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required List<int> history, required this.color})
    : history = List.of(history);

  final List<int> history;
  final Color color;

  /// Share of the tile height the curve may climb to.
  static const _height = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final peak = history.reduce(math.max);
    if (peak <= 0) return;
    final step = size.width / (_ConnectionCardState._historyLength - 1);
    final x0 = size.width - step * (history.length - 1);
    final points = [
      for (var i = 0; i < history.length; i++)
        Offset(
          x0 + step * i,
          size.height - size.height * _height * history[i] / peak,
        ),
    ];
    // Smooth through midpoints.
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final mid = Offset.lerp(points[i - 1], points[i], 0.5)!;
      line.quadraticBezierTo(
        points[i - 1].dx,
        points[i - 1].dy,
        mid.dx,
        mid.dy,
      );
    }
    line.lineTo(points.last.dx, points.last.dy);
    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    final top = size.height * (1 - _height);
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTRB(0, top, size.width, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || !listEquals(old.history, history);
}

/// Outcome of a tap-to-check: spinner, round trip, or no response.
class _CheckResult extends StatelessWidget {
  const _CheckResult({required this.ms});

  /// null while checking, -1 when the server didn't answer.
  final int? ms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final ms = this.ms;
    final (Widget icon, String text, Color color) = switch (ms) {
      null => (
        const SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            strokeCap: StrokeCap.round,
          ),
        ),
        context.l10n.checkRunning,
        theme.colorScheme.onSurfaceVariant,
      ),
      < 0 => (
        Icon(Icons.close_rounded, size: 14, color: colors.danger),
        context.l10n.checkFailed,
        colors.danger,
      ),
      _ => (
        Icon(Icons.check_rounded, size: 14, color: colors.latencyGood),
        context.l10n.checkOk(ms),
        colors.latencyGood,
      ),
    };
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(99)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
