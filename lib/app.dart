import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/servers/presentation/servers_screen.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/domain/app_settings.dart';
import 'features/settings/presentation/privacy_notice_screen.dart';
import 'l10n/l10n.dart';
import 'theme/app_theme.dart';

class WanXApp extends ConsumerWidget {
  const WanXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(settingsProvider).value;
    final settings = loaded ?? const AppSettings();
    return MaterialApp(
      title: 'WanX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      // null = follow the system language among the supported ones.
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The data disclosure comes before anything else, once.
      home: loaded == null
          ? const SizedBox.shrink()
          : settings.privacyAccepted
          ? const ServersScreen()
          : const PrivacyNoticeScreen(),
    );
  }
}
