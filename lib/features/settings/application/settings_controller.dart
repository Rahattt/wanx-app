import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/app_settings.dart';

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SharedPrefsSettingsStore(),
);

final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Strings in the app's language, for code outside the widget tree
/// (notifications, errors raised by controllers).
AppLocalizations appL10n(Ref ref) {
  final code =
      ref.read(settingsProvider).value?.languageCode ??
      PlatformDispatcher.instance.locale.languageCode;
  return lookupAppLocalizations(
    Locale(supportedLanguages.containsKey(code) ? code : 'en'),
  );
}

abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class SharedPrefsSettingsStore implements SettingsStore {
  static const _key = 'settings';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<AppSettings> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) =>
      _prefs.setString(_key, jsonEncode(settings.toJson()));
}

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsStoreProvider).load();

  /// Applies [change] and persists it; the UI updates immediately.
  Future<void> change(AppSettings Function(AppSettings) change) async {
    final next = change(state.value ?? const AppSettings());
    state = AsyncData(next);
    await ref.read(settingsStoreProvider).save(next);
  }
}
