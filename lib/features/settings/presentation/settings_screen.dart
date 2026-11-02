import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components.dart';
import '../../../theme/motion.dart';
import '../../vpn/application/vpn_controller.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';
import 'privacy_notice_screen.dart';
import 'split_tunnel_screen.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Section(
            title: l10n.sectionAppearance,
            children: [
              _ChoiceRow<String?>(
                title: l10n.language,
                value: settings.languageCode,
                options: {null: l10n.languageSystem, ...supportedLanguages},
                onChanged: (code) => controller.change(
                  (s) => s.copyWith(languageCode: () => code),
                ),
              ),
              _ChoiceRow<ThemeMode>(
                title: l10n.theme,
                value: settings.themeMode,
                options: {
                  ThemeMode.system: l10n.themeSystem,
                  ThemeMode.light: l10n.themeLight,
                  ThemeMode.dark: l10n.themeDark,
                },
                onChanged: (mode) =>
                    controller.change((s) => s.copyWith(themeMode: mode)),
              ),
            ],
          ),
          _Section(
            title: l10n.sectionConnection,
            footer: l10n.connectionSettingsNote,
            children: [
              _ChoiceRow<DnsPreset>(
                title: l10n.dnsServer,
                value: settings.dns,
                options: {
                  for (final d in DnsPreset.values)
                    d: d == DnsPreset.adguard ? l10n.dnsAdguard : d.label,
                },
                // Short label in the row, the long one in the picker.
                valueLabel: settings.dns.label,
                onChanged: (dns) =>
                    controller.change((s) => s.copyWith(dns: dns)),
              ),
              _ChoiceRow<IpMode>(
                title: l10n.ipMode,
                value: settings.ipMode,
                options: {
                  IpMode.ipv4: l10n.ipModeV4,
                  IpMode.dual: l10n.ipModeDual,
                  IpMode.ipv6: l10n.ipModeV6,
                },
                note: l10n.ipModeHint,
                onChanged: (mode) =>
                    controller.change((s) => s.copyWith(ipMode: mode)),
              ),
              if (Platform.isAndroid)
                _NavRow(
                  title: l10n.splitTunnel,
                  value: switch (settings.splitMode) {
                    SplitTunnelMode.off => l10n.splitValueAll,
                    SplitTunnelMode.only => l10n.splitValueOnly(
                      settings.splitApps.length,
                    ),
                    SplitTunnelMode.bypass => l10n.splitValueBypass(
                      settings.splitApps.length,
                    ),
                  },
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const SplitTunnelScreen(),
                    ),
                  ),
                ),
              _SwitchRow(
                title: l10n.bypassLan,
                subtitle: l10n.bypassLanHint,
                value: settings.bypassLan,
                onChanged: (v) =>
                    controller.change((s) => s.copyWith(bypassLan: v)),
              ),
              _SwitchRow(
                title: l10n.autoConnect,
                subtitle: l10n.autoConnectHint,
                value: settings.autoConnect,
                onChanged: (v) =>
                    controller.change((s) => s.copyWith(autoConnect: v)),
              ),
            ],
          ),
          _Section(
            title: l10n.sectionSubscriptions,
            children: [
              _SwitchRow(
                title: l10n.updateOnLaunch,
                subtitle: l10n.updateOnLaunchHint,
                value: settings.updateSubscriptionsOnLaunch,
                onChanged: (v) => controller.change(
                  (s) => s.copyWith(updateSubscriptionsOnLaunch: v),
                ),
              ),
              _SwitchRow(
                title: l10n.sendHwid,
                subtitle: l10n.sendHwidHint,
                value: settings.sendHwid,
                onChanged: (v) =>
                    controller.change((s) => s.copyWith(sendHwid: v)),
              ),
              _HwidRow(
                hwid: ref.watch(deviceIdentityProvider).value?.hwid ?? '—',
              ),
            ],
          ),
          _Section(
            title: l10n.sectionAbout,
            children: [
              _NavRow(
                title: l10n.aboutApp,
                value: ref.watch(_appVersionProvider).value ?? '',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// About WanX: version, contact, legal pages and open-source licenses.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final version = ref.watch(_appVersionProvider).value ?? '';
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sectionAbout)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.lg,
          AppSpacing.page,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/branding/app_icon.png',
                width: 96,
                height: 96,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'WanX',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.versionLabel(version),
            textAlign: TextAlign.center,
            style: muted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.aboutText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          _Section(
            title: l10n.sectionSupport,
            children: [
              _NavRow(
                title: l10n.contactSupport,
                value: supportEmail,
                onTap: () => openLegal('mailto:$supportEmail'),
              ),
              _NavRow(
                title: l10n.website,
                value: 'wanx.dev',
                onTap: () => openLegal(websiteUrl),
              ),
            ],
          ),
          _Section(
            title: l10n.sectionLegal,
            footer: l10n.licenseNotice(supportEmail),
            children: [
              _NavRow(
                title: l10n.privacyPolicy,
                value: '',
                onTap: () => openLegal(privacyPolicyUrl),
              ),
              _NavRow(
                title: l10n.termsOfService,
                value: '',
                onTap: () => openLegal(termsUrl),
              ),
              _NavRow(
                title: l10n.openSourceLicenses,
                value: '',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'WanX',
                  applicationVersion: version,
                  applicationLegalese: '© 2026 RayCentral LLC',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '© 2026 RayCentral LLC',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ],
      ),
    );
  }
}

/// Settings-style section: small caps label, grouped card, optional footer.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.footer});

  final String title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
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
              style: muted?.copyWith(letterSpacing: 0.4),
            ),
          ),
          GroupedCard(children: children),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                6,
                AppSpacing.lg,
                0,
              ),
              child: Text(footer!, style: muted),
            ),
        ],
      ),
    );
  }
}

/// Row showing the current choice; tapping opens a sheet with all options.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.valueLabel,
    this.note,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final String? valueLabel;

  /// Shown under the options in the picker.
  final String? note;

  Future<void> _pick(BuildContext context) async {
    final colors = AppColors.of(context);
    final picked = await showModalBottomSheet<({T value})>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              GroupedCard(
                children: [
                  for (final MapEntry(:key, value: label) in options.entries)
                    Pressable(
                      onTap: () => Navigator.pop(context, (value: key)),
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
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            if (key == value)
                              Icon(
                                Icons.check_rounded,
                                size: 22,
                                color: colors.accent,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Text(
                    note!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked.value != value) onChanged(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Pressable(
      onTap: () => _pick(context),
      scale: 1,
      pressedOpacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          14,
          AppSpacing.sm,
          14,
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
            Text(
              valueLabel ?? options[value] ?? '',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

/// Row that opens another screen, with the current value on the right.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Pressable(
      onTap: onTap,
      scale: 1,
      pressedOpacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          14,
          AppSpacing.sm,
          14,
        ),
        child: Row(
          children: [
            Text(title, style: theme.textTheme.bodyLarge),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      activeTrackColor: theme.colorScheme.primary,
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Device ID; tap to copy it for the provider's support.
class _HwidRow extends StatelessWidget {
  const _HwidRow({required this.hwid});

  final String hwid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: hwid));
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.hwidCopied)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          children: [
            Text('HWID', style: theme.textTheme.bodyLarge),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                hwid,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.copy_rounded,
              size: 18,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
