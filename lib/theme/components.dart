import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Frosted translucent backdrop, like iOS bars. [opacity] fades both the
/// tint and the hairline so it can appear gradually on scroll.
class Frosted extends StatelessWidget {
  const Frosted({
    super.key,
    required this.child,
    this.opacity = 1,
    this.hairlineTop = false,
  });

  final Widget child;
  final double opacity;
  final bool hairlineTop;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hairline = BorderSide(
      color: colors.separator.withValues(alpha: opacity),
      width: 0.5,
    );
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.78 * opacity),
        border: hairlineTop ? Border(top: hairline) : Border(bottom: hairline),
      ),
      child: child,
    );
    if (opacity == 0) return content;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24 * opacity, sigmaY: 24 * opacity),
        child: content,
      ),
    );
  }
}

/// App bar with a frosted background, for pushed screens whose body
/// scrolls underneath (use with `extendBodyBehindAppBar`).
class FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FrostedAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: const Frosted(child: SizedBox.expand()),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Inset grouped card (iOS grouped list section) with layered shadow.
/// Children are separated by inset hairlines.
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.children,
    this.separatorIndent = AppSpacing.lg,
  });

  final List<Widget> children;
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: AppRadius.lgAll,
        boxShadow: colors.cardShadow,
        border: Border.all(color: colors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) CardSeparator(indent: separatorIndent),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CardSeparator extends StatelessWidget {
  const CardSeparator({super.key, this.indent = AppSpacing.lg});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 0.5, color: AppColors.of(context).separator),
    );
  }
}
