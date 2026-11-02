import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../theme/motion.dart';

/// Section header for a subscription group or manual servers,
/// in the bold-title style of Health/Wallet sections.
class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.title,
    required this.count,
    this.subtitle,
    this.onDelete,
    this.onEdit,
    this.onTest,
    this.testing = false,
    this.onRefresh,
    this.refreshing = false,
  });

  final String title;
  final String? subtitle;
  final int count;

  /// Shown as a menu action for subscription groups.
  final VoidCallback? onDelete;

  /// Menu action to rename the group or change its URL; null where the
  /// subscription can't be edited (premium links).
  final VoidCallback? onEdit;

  /// Tests every server in the group.
  final VoidCallback? onTest;
  final bool testing;

  /// Re-downloads the subscription; null for manual servers.
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page + AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$count',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
              ],
            ),
          ),
          if (onTest != null || onRefresh != null)
            _ActionCapsule(
              onTest: onTest,
              testing: testing,
              onRefresh: onRefresh,
              refreshing: refreshing,
            ),
          if (onDelete != null)
            PopupMenuButton<void>(
              tooltip: context.l10n.subscriptionActions,
              icon: Icon(Icons.more_horiz_rounded, color: muted, size: 22),
              itemBuilder: (_) => [
                if (onEdit != null)
                  PopupMenuItem(
                    onTap: onEdit,
                    child: Text(context.l10n.editSubscription),
                  ),
                PopupMenuItem(
                  onTap: onDelete,
                  child: Text(
                    context.l10n.deleteSubscription,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The group's remote: ping and refresh share one graphite capsule. Ping
/// shows signal bars that dance while testing; refresh spins its own arrow
/// instead of turning into a generic spinner.
class _ActionCapsule extends StatelessWidget {
  const _ActionCapsule({
    required this.onTest,
    required this.testing,
    required this.onRefresh,
    required this.refreshing,
  });

  final VoidCallback? onTest;
  final bool testing;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    // Yellow is too light on the light fill; use its darker end there.
    final ink = theme.brightness == Brightness.dark
        ? colors.accent
        : colors.accentStrong;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.fill,
          shape: const StadiumBorder(),
        ),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: StadiumBorder()),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onTest != null)
                  _Segment(
                    tooltip: context.l10n.testServers,
                    busy: testing,
                    onTap: onTest!,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SignalBars(active: testing, color: ink),
                        const SizedBox(width: 6),
                        Text(
                          'ms',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onTest != null && onRefresh != null)
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    indent: 8,
                    endIndent: 8,
                    color: colors.background,
                  ),
                if (onRefresh != null)
                  _Segment(
                    tooltip: context.l10n.refreshSubscription,
                    busy: refreshing,
                    onTap: onRefresh!,
                    child: _SpinningIcon(
                      icon: Icons.sync_rounded,
                      spinning: refreshing,
                      color: ink,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable half of the capsule; glows accent-soft while [busy].
class _Segment extends StatelessWidget {
  const _Segment({
    required this.tooltip,
    required this.busy,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final bool busy;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: !busy,
        label: tooltip,
        excludeSemantics: true,
        child: Pressable(
          scale: 0.94,
          onTap: busy ? null : onTap,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.standard,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.center,
            color: busy ? colors.accentSoft : Colors.transparent,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Three rising signal bars; while [active] they bounce like an equalizer,
/// then ease back to the staircase.
class _SignalBars extends StatefulWidget {
  const _SignalBars({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  State<_SignalBars> createState() => _SignalBarsState();
}

class _SignalBarsState extends State<_SignalBars>
    with SingleTickerProviderStateMixin {
  late final _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _phase.repeat();
  }

  @override
  void didUpdateWidget(_SignalBars old) {
    super.didUpdateWidget(old);
    if (widget.active && !_phase.isAnimating) {
      _phase.repeat();
    } else if (!widget.active && old.active) {
      _phase.stop();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.active ? 1 : 0),
      duration: AppMotion.slow,
      curve: AppMotion.standard,
      builder: (context, intensity, _) => AnimatedBuilder(
        animation: _phase,
        builder: (context, _) => CustomPaint(
          size: const Size(14, 14),
          painter: _BarsPainter(
            phase: _phase.value,
            intensity: intensity,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({
    required this.phase,
    required this.intensity,
    required this.color,
  });

  final double phase;
  final double intensity;
  final Color color;

  static const _rest = [0.4, 0.7, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final width = (size.width - gap * 2) / 3;
    final paint = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      final wave = 0.25 + 0.75 * math.sin((phase + i * 0.22) * math.pi).abs();
      final h = lerpDouble(_rest[i], wave, intensity)! * size.height;
      final x = i * (width + gap);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          size.height - h,
          x + width,
          size.height,
          Radius.circular(width / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.phase != phase || old.intensity != intensity || old.color != color;
}

/// Icon that turns while [spinning] and finishes its last turn when stopped.
class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon({
    required this.icon,
    required this.spinning,
    required this.color,
  });

  final IconData icon;
  final bool spinning;
  final Color color;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _turn.repeat();
  }

  @override
  void didUpdateWidget(_SpinningIcon old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !old.spinning) {
      _turn.repeat();
    } else if (!widget.spinning && old.spinning) {
      _turn.animateTo(1, curve: AppMotion.standard).whenCompleteOrCancel(() {
        if (!widget.spinning) _turn.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _turn,
      child: Icon(widget.icon, size: 18, color: widget.color),
    );
  }
}
