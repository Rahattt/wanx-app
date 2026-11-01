import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../theme/app_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../theme/motion.dart';
import '../../domain/country.dart';
import '../../domain/server.dart';

/// Server row: swipe right to test latency, swipe left to edit or delete.
/// Lives inside a [GroupedCard]; the selected row's name is in the accent.
class ServerTile extends StatelessWidget {
  const ServerTile({
    super.key,
    required this.server,
    required this.selected,
    required this.testing,
    required this.onTap,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  final Server server;
  final bool selected;
  final bool testing;
  final VoidCallback onTap;
  final VoidCallback onTest;

  /// Null hides editing: sealed servers can't be viewed or changed.
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  static const _inset = 4.0;

  /// Where the separator starts: past the flag, like iOS inset lists.
  static const separatorIndent = AppSpacing.lg + ServerFlag.width + 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    return Slidable(
      key: ValueKey(server.id),
      groupTag: 'servers',
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.24,
        children: [
          _SwipeAction(
            color: colors.accent,
            foreground: colors.onAccent,
            icon: Icons.speed_rounded,
            label: context.l10n.swipeTest,
            onPressed: onTest,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: onEdit == null ? 0.24 : 0.46,
        children: [
          if (onEdit case final onEdit?)
            _SwipeAction(
              color: colors.neutralAction,
              foreground: Colors.white,
              icon: Icons.edit_rounded,
              label: context.l10n.swipeEdit,
              onPressed: onEdit,
            ),
          _SwipeAction(
            color: colors.danger,
            foreground: Colors.white,
            icon: Icons.delete_rounded,
            label: context.l10n.delete,
            onPressed: onDelete,
          ),
        ],
      ),
      child: ColoredBox(
        color: colors.card,
        child: Pressable(
          onTap: onTap,
          // The selected row sits in an inset, accent-outlined capsule; the
          // margin comes out of the padding so row height is unchanged.
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.standard,
            margin: const EdgeInsets.all(_inset),
            decoration: BoxDecoration(
              color: selected
                  ? colors.accent.withValues(alpha: 0.10)
                  : colors.accent.withValues(alpha: 0),
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: selected
                    ? colors.accent.withValues(alpha: 0.45)
                    : colors.accent.withValues(alpha: 0),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg - _inset - 1,
              AppSpacing.sm - _inset - 1,
              AppSpacing.sm - _inset - 1,
              AppSpacing.sm - _inset - 1,
            ),
            child: Row(
              children: [
                ServerFlag(server: server, selected: selected),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: AppMotion.medium,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: selected ? colors.accent : scheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        child: Text(
                          CountryFlag.stripFlags(server.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                LatencyBadge(latencyMs: server.latencyMs, testing: testing),
                if (onEdit != null)
                  IconButton(
                    tooltip: context.l10n.serverDetails,
                    // Compact so it doesn't set the row height.
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.info_outline_rounded, size: 22),
                    color: scheme.outline,
                    onPressed: onEdit,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-height iOS swipe action: solid colour, icon over a short label.
class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: color,
      foregroundColor: foreground,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Flag emoji taken from the server's name. Names without one get a
/// monogram tile (first letter or digit) so every row has a leading mark.
class ServerFlag extends StatelessWidget {
  const ServerFlag({super.key, required this.server, this.selected = false});

  final Server server;
  final bool selected;

  static const width = 40.0;

  static final _firstChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

  @override
  Widget build(BuildContext context) {
    final code = CountryFlag.codeFromName(server.name);
    final flag = CountryFlag.emoji(code);
    if (flag != null) {
      return SizedBox(
        width: width,
        height: 32,
        child: Center(
          child: Text(
            flag,
            semanticsLabel: code,
            style: const TextStyle(fontSize: 24, height: 1),
          ),
        ),
      );
    }
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final letter = _firstChar
        .firstMatch(CountryFlag.stripFlags(server.name))
        ?.group(0)
        ?.toUpperCase();
    final foreground = selected
        ? colors.accent
        : theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      width: width,
      height: 32,
      child: Center(
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.standard,
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.fill,
            borderRadius: AppRadius.smAll,
          ),
          child: letter == null
              ? Icon(Icons.public_rounded, size: 17, color: foreground)
              : Text(
                  letter,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Fixed-width protocol label so rows line up regardless of protocol.
/// Filled with the accent for the selected server.
class ProtocolBadge extends StatelessWidget {
  const ProtocolBadge({
    super.key,
    required this.protocol,
    this.selected = false,
  });

  final ServerProtocol protocol;
  final bool selected;

  static const width = 52.0;

  static String shortLabel(ServerProtocol p) => switch (p) {
    ServerProtocol.vless => 'VLESS',
    ServerProtocol.vmess => 'VMESS',
    ServerProtocol.trojan => 'TROJAN',
    ServerProtocol.shadowsocks => 'SS',
    ServerProtocol.hysteria2 => 'HY2',
    ServerProtocol.tuic => 'TUIC',
    ServerProtocol.wireguard => 'WG',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      width: width,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.accent : colors.fill,
        borderRadius: AppRadius.smAll,
      ),
      child: AnimatedDefaultTextStyle(
        duration: AppMotion.medium,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: selected ? colors.onAccent : scheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
        child: Text(shortLabel(protocol)),
      ),
    );
  }
}

/// Delay in ms as a bare number in green; red when failed, grey untested.
class LatencyBadge extends StatelessWidget {
  const LatencyBadge({
    super.key,
    required this.latencyMs,
    required this.testing,
  });

  final int? latencyMs;
  final bool testing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final ms = latencyMs;
    final (text, color) = switch (ms) {
      null => ('—', theme.colorScheme.outline),
      < 0 => (context.l10n.latencyFailed, colors.latencyBad),
      _ => ('$ms', colors.latencyGood),
    };
    final Widget child = testing
        ? const Padding(
            key: ValueKey('testing'),
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                strokeCap: StrokeCap.round,
              ),
            ),
          )
        : Padding(
            key: ValueKey(text),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.standard,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
