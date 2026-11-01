import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/vpn_channel.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components.dart';
import '../../../theme/motion.dart';
import '../../vpn/application/vpn_controller.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';

final _installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>(
  (ref) => ref.read(vpnChannelProvider).installedApps(),
);

/// Android per-app VPN: route only some apps through the tunnel, or let
/// some bypass it. Applies on the next connect, like other connection
/// settings.
class SplitTunnelScreen extends ConsumerStatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  ConsumerState<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends ConsumerState<SplitTunnelScreen> {
  String _query = '';

  /// Selection when the screen opened: listed first. Not the live
  /// selection, so a row doesn't jump away from under the finger.
  late final Set<String> _pinned = {
    ...?ref.read(settingsProvider).value?.splitApps,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final controller = ref.read(settingsProvider.notifier);
    final apps = ref.watch(_installedAppsProvider);
    final selected = settings.splitApps.toSet();
    final enabled = settings.splitMode != SplitTunnelMode.off;

    void toggle(String package) {
      final next = {...selected};
      if (!next.remove(package)) next.add(package);
      controller.change((s) => s.copyWith(splitApps: next.toList()..sort()));
    }

    final q = _query.trim().toLowerCase();
    final visible =
        [
            for (final a in apps.value ?? const <InstalledApp>[])
              if (q.isEmpty ||
                  a.label.toLowerCase().contains(q) ||
                  a.package.toLowerCase().contains(q))
                a,
          ]
          // Previously selected apps first, so the choice is visible at a
          // glance.
          ..sort(
            (a, b) => (_pinned.contains(a.package) ? 0 : 1).compareTo(
              _pinned.contains(b.package) ? 0 : 1,
            ),
          );

    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final hint = switch (settings.splitMode) {
      SplitTunnelMode.off => l10n.splitHintOff,
      SplitTunnelMode.only when selected.isEmpty => l10n.splitEmptyOnly,
      SplitTunnelMode.only => l10n.splitHintOnly,
      SplitTunnelMode.bypass => l10n.splitHintBypass,
    };

    final header = [
      const SizedBox(height: AppSpacing.lg),
      GroupedCard(
        children: [
          for (final (mode, label) in [
            (SplitTunnelMode.off, l10n.splitAll),
            (SplitTunnelMode.only, l10n.splitOnly),
            (SplitTunnelMode.bypass, l10n.splitBypass),
          ])
            Pressable(
              onTap: () =>
                  controller.change((s) => s.copyWith(splitMode: mode)),
              scale: 1,
              pressedOpacity: 0.6,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodyLarge),
                    ),
                    if (settings.splitMode == mode)
                      Icon(Icons.check_rounded, size: 22, color: colors.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 6, AppSpacing.lg, 0),
        child: Text('$hint ${l10n.connectionSettingsNote}', style: muted),
      ),
      const SizedBox(height: AppSpacing.xl),
      TextField(
        enabled: enabled,
        decoration: InputDecoration(
          hintText: l10n.searchApps,
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      const SizedBox(height: AppSpacing.md),
    ];

    final Widget body = switch (apps) {
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('$error', style: muted),
      ),
      AsyncData() when visible.isEmpty => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(l10n.noApps, style: muted, textAlign: TextAlign.center),
      ),
      AsyncData() => const SizedBox.shrink(),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
    final rows = apps.hasValue ? visible : const <InstalledApp>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.splitTunnel)),
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: header.length + 1 + rows.length,
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          if (i == header.length) return body;
          final app = rows[i - header.length - 1];
          return _AppRow(
            app: app,
            selected: selected.contains(app.package),
            enabled: enabled,
            onTap: () => toggle(app.package),
          );
        },
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final InstalledApp app;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = app.icon;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: icon == null
                    ? Icon(
                        Icons.android_rounded,
                        color: theme.colorScheme.outline,
                      )
                    : Image.memory(icon, gaplessPlayback: true),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      app.package,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox.adaptive(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
