import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Spacing scale used everywhere; don't introduce ad-hoc values.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page padding.
  static const double page = lg;
}

/// Corner radii: small badges, controls/fields, grouped cards, sheets.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

/// The full palette, Binance-inspired: signature yellow on graphite, with
/// exchange green/red for good/bad. Connected state *is* the accent.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.onAccent,
    required this.danger,
    required this.dangerSoft,
    required this.background,
    required this.card,
    required this.fill,
    required this.separator,
    required this.cardBorder,
    required this.neutralAction,
    required this.latencyGood,
    required this.latencyMedium,
    required this.latencyBad,
    required this.cardShadow,
  });

  /// Brand accent: primary actions, selection, progress, "connected".
  final Color accent;

  /// Darker end of accent gradients and pressed states.
  final Color accentStrong;

  /// Tinted background for accent-coloured content.
  final Color accentSoft;
  final Color onAccent;

  final Color danger;
  final Color dangerSoft;

  /// Grouped page background (never pure white/black).
  final Color background;

  /// Grouped cells and cards, one step above [background].
  final Color card;

  /// Neutral fill for badges, inputs and segmented controls.
  final Color fill;
  final Color separator;

  /// Hairline around cards; shadows don't read in dark mode.
  final Color cardBorder;

  /// Secondary swipe actions (edit).
  final Color neutralAction;

  final Color latencyGood;
  final Color latencyMedium;
  final Color latencyBad;

  /// Layered soft shadow for cards and the idle connect button.
  final List<BoxShadow> cardShadow;

  Color get connected => accent;
  Color get onConnected => onAccent;

  // Flat graphite surfaces separated by hairlines, no shadows; yellow is
  // kept for what is active. Yellow needs dark text on top of it.
  static const light = AppColors(
    accent: Color(0xFFF0B90B),
    accentStrong: Color(0xFFB88A00),
    accentSoft: Color(0xFFFEF6D8),
    onAccent: Color(0xFF181A20),
    danger: Color(0xFFCF304A),
    dangerSoft: Color(0xFFFDECEE),
    background: Colors.white,
    card: Color(0xFFF5F5F5),
    fill: Color(0xFFEAECEF),
    separator: Color(0xFFEAECEF),
    cardBorder: Color(0xFFEAECEF),
    neutralAction: Color(0xFFB7BDC6),
    latencyGood: Color(0xFF03A66D),
    latencyMedium: Color(0xFFD9822B),
    latencyBad: Color(0xFFCF304A),
    cardShadow: [],
  );

  static const dark = AppColors(
    accent: Color(0xFFF0B90B),
    accentStrong: Color(0xFFD0980B),
    accentSoft: Color(0xFF2A2410),
    onAccent: Color(0xFF181A20),
    danger: Color(0xFFF6465D),
    dangerSoft: Color(0xFF2D1A1F),
    background: Color(0xFF0B0E11),
    card: Color(0xFF181A20),
    fill: Color(0xFF2B3139),
    separator: Color(0xFF2B3139),
    cardBorder: Color(0xFF2B3139),
    neutralAction: Color(0xFF474D57),
    latencyGood: Color(0xFF0ECB81),
    latencyMedium: Color(0xFFF8A13F),
    latencyBad: Color(0xFFF6465D),
    cardShadow: [],
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({Color? accent, Color? danger}) => AppColors(
    accent: accent ?? this.accent,
    accentStrong: accentStrong,
    accentSoft: accentSoft,
    onAccent: onAccent,
    danger: danger ?? this.danger,
    dangerSoft: dangerSoft,
    background: background,
    card: card,
    fill: fill,
    separator: separator,
    cardBorder: cardBorder,
    neutralAction: neutralAction,
    latencyGood: latencyGood,
    latencyMedium: latencyMedium,
    latencyBad: latencyBad,
    cardShadow: cardShadow,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      accent: c(accent, other.accent),
      accentStrong: c(accentStrong, other.accentStrong),
      accentSoft: c(accentSoft, other.accentSoft),
      onAccent: c(onAccent, other.onAccent),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      background: c(background, other.background),
      card: c(card, other.card),
      fill: c(fill, other.fill),
      separator: c(separator, other.separator),
      cardBorder: c(cardBorder, other.cardBorder),
      neutralAction: c(neutralAction, other.neutralAction),
      latencyGood: c(latencyGood, other.latencyGood),
      latencyMedium: c(latencyMedium, other.latencyMedium),
      latencyBad: c(latencyBad, other.latencyBad),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  /// iOS text styles (Large Title, Title 2/3, Headline, Body, Subheadline,
  /// Footnote, Caption) with SF tracking. Families come from the platform
  /// typography: SF Pro on iOS, Roboto elsewhere.
  static const _text = TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.37,
      height: 1.2,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.35,
      height: 1.27,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.38,
      height: 1.25,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.41,
      height: 1.29,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.24,
      height: 1.33,
    ),
    bodyLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.41,
      height: 1.29,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.24,
      height: 1.33,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      height: 1.38,
    ),
    labelLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.41,
      height: 1.29,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.08,
      height: 1.38,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.07,
      height: 1.18,
    ),
  );

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final dark = brightness == Brightness.dark;
    final label = dark ? const Color(0xFFEAECEF) : const Color(0xFF1E2329);
    final secondary = dark ? const Color(0xFF848E9C) : const Color(0xFF707A8A);
    final tertiary = dark ? const Color(0xFF5E6673) : const Color(0xFFB7BDC6);
    // Yellow is too light for glyphs on white; light mode uses ink instead.
    final chrome = dark ? colors.accent : label;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: colors.onAccent,
          primaryContainer: colors.accentSoft,
          onPrimaryContainer: dark ? colors.accent : colors.accentStrong,
          secondaryContainer: colors.accentSoft,
          onSecondaryContainer: dark ? colors.accent : colors.accentStrong,
          error: colors.danger,
          onError: Colors.white,
          errorContainer: colors.dangerSoft,
          onErrorContainer: colors.danger,
          surface: colors.background,
          onSurface: label,
          onSurfaceVariant: secondary,
          outline: tertiary,
          outlineVariant: colors.separator,
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: colors.card,
          surfaceContainerLow: colors.card,
          surfaceContainer: colors.card,
          surfaceContainerHigh: colors.card,
          surfaceContainerHighest: colors.fill,
        );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: _text,
      splashFactory: NoSplash.splashFactory,
      highlightColor: label.withValues(alpha: 0.06),
    );
    const controlShape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);
    const controlSize = Size(64, 52);
    const noBorder = OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide.none,
    );

    return base.copyWith(
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final p in TargetPlatform.values)
            p: const CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: chrome,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: _text.titleMedium?.copyWith(color: label),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: chrome),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.fill,
        hintStyle: TextStyle(color: tertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        border: noBorder,
        enabledBorder: noBorder,
        disabledBorder: noBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: controlSize,
          shape: controlShape,
          textStyle: _text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          shape: controlShape,
          textStyle: _text.labelLarge,
          backgroundColor: colors.fill,
          side: BorderSide.none,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          textStyle: _text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        modalBackgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: tertiary.withValues(alpha: 0.5),
        dragHandleSize: const Size(36, 5),
        modalBarrierColor: Colors.black.withValues(alpha: dark ? 0.6 : 0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: dark
            ? const Color(0xFF2B3139)
            : const Color(0xFF1E2329),
        contentTextStyle: _text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.dark.accent,
        shape: controlShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: controlShape,
        color: colors.card,
        elevation: 8,
        shadowColor: Colors.black26,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      switchTheme: SwitchThemeData(
        // Hide the thumb icon noise; state is clear from track color.
        thumbIcon: WidgetStateProperty.all(null),
      ),
      dividerTheme: DividerThemeData(
        color: colors.separator,
        space: 1,
        thickness: 0.5,
      ),
    );
  }
}
