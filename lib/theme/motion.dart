import 'package:flutter/material.dart';

/// Motion tokens: transitions stay within 160–380 ms and ease out, never
/// linear.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 380);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}

/// iOS-cell style press feedback: shrinks and dims slightly while held.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.98,
    this.pressedOpacity = 0.7,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final double pressedOpacity;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _down = false;

  void _set(bool down) {
    if (mounted && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final duration = _down ? const Duration(milliseconds: 90) : AppMotion.fast;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => _set(true) : null,
      // Hold the pressed look briefly so quick taps still register visually.
      onTapUp: enabled
          ? (_) => Future.delayed(const Duration(milliseconds: 90), () {
              _set(false);
            })
          : null,
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: duration,
        curve: AppMotion.standard,
        child: AnimatedOpacity(
          opacity: _down ? widget.pressedOpacity : 1,
          duration: duration,
          curve: AppMotion.standard,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Expands/collapses [child] vertically with a fade. Once collapsed the
/// child leaves the tree, so hidden form fields are not validated.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
    reverseDuration: AppMotion.fast + const Duration(milliseconds: 40),
    value: widget.visible ? 1 : 0,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.emphasized,
  );

  @override
  void didUpdateWidget(Reveal old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => _controller.isDismissed
          ? const SizedBox(width: double.infinity)
          : SizeTransition(
              sizeFactor: _curve,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: _curve, child: child),
            ),
      child: widget.child,
    );
  }
}
