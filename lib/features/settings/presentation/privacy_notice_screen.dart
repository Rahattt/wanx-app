import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_theme.dart';
import '../application/settings_controller.dart';

const privacyPolicyUrl = 'https://wanx.dev/privacy/';
const termsUrl = 'https://wanx.dev/terms/';
const websiteUrl = 'https://wanx.dev/';
const supportEmail = 'support@wanx.dev';

Future<void> openLegal(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// First launch: what data the app sends and where, before any VPN use
/// (App Store guideline 5.4; Google Play's prominent disclosure for the
/// device ID).
class PrivacyNoticeScreen extends ConsumerWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final points = [
      (Icons.vpn_lock_rounded, l10n.noticeTraffic),
      (Icons.phone_iphone_rounded, l10n.noticeLocal),
      (Icons.fingerprint_rounded, l10n.noticeHwid),
      (Icons.link_rounded, l10n.noticeLinks),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xl,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                children: [
                  Text(l10n.noticeTitle, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.noticeIntro,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final (icon, text) in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: colors.accent),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              text,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      TextButton(
                        onPressed: () => openLegal(privacyPolicyUrl),
                        child: Text(l10n.privacyPolicy),
                      ),
                      TextButton(
                        onPressed: () => openLegal(termsUrl),
                        child: Text(l10n.termsOfService),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              child: FilledButton(
                onPressed: () => ref
                    .read(settingsProvider.notifier)
                    .change((s) => s.copyWith(privacyAccepted: true)),
                child: Text(l10n.noticeAgree),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
