import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeMode { system, light, dark }

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

List<int> _rgb(Color c) => [c.red, c.green, c.blue];

Color _mix(Color a, Color b, double t) {
  final ar = _rgb(a), br = _rgb(b);
  return Color.fromARGB(
    255,
    (ar[0] + (br[0] - ar[0]) * t).round(),
    (ar[1] + (br[1] - ar[1]) * t).round(),
    (ar[2] + (br[2] - ar[2]) * t).round(),
  );
}

class AppColors {
  AppColors._();

  static Color _accent = const Color(0xFF1D4ED8);
  static Brightness _brightness = Brightness.light;

  static void configure({required String accentHex, required Brightness brightness}) {
    _accent = _hexToColor(accentHex);
    _brightness = brightness;
  }

  static bool get isDark => _brightness == Brightness.dark;

  static Color get paper => isDark ? const Color(0xFF0A101C) : const Color(0xFFF8FAFC);
  static Color get paper2 => isDark ? const Color(0xFF0E1626) : const Color(0xFFEEF2F7);
  static Color get card => isDark ? const Color(0xFF131D30) : const Color(0xFFFFFFFF);
  static Color get ink => isDark ? const Color(0xFFE8ECF3) : const Color(0xFF0F1B2E);
  static Color get ink2 => isDark ? const Color(0xFF9AA7BD) : const Color(0xFF48586C);
  static Color get ink3 => isDark ? const Color(0xFF6B7A93) : const Color(0xFF8797AB);
  static Color get line => isDark ? const Color(0xFF1E2A40) : const Color(0xFFE5EAF1);
  static Color get line2 => isDark ? const Color(0xFF2A3850) : const Color(0xFFD1DAE6);

  static Color get accent => _accent;
  static Color get accent2 => _mix(_accent, Colors.white, isDark ? 0.18 : 0.28);
  static Color get accentSoft => isDark ? _mix(_accent, Colors.black, 0.7) : _mix(_accent, Colors.white, 0.9);

  static const warm = Color(0xFFB45309);
  static Color get ok => isDark ? const Color(0xFF34D399) : const Color(0xFF0E8A5F);
  static const amber = Color(0xFFB45309);
  static const danger = Color(0xFFDC2626);

  static const chrome = Color(0xFF0C1B31);
  static const chrome2 = Color(0xFF16294A);
  static const chromeLine = Color(0x24E2E8F0);
  static const chromeTx = Color(0xCCE2E8F0);

  static const onAccent = Colors.white;

  static const LinearGradient chromeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C1B31), Color(0xFF16294A)],
  );
}

class AppFonts {
  static TextStyle display({
    double size = 19,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.3,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink,
        letterSpacing: letterSpacing,
        height: 1.16,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? AppColors.ink2, height: 1.4);

  static TextStyle mono({
    double size = 11,
    Color? color,
    double letterSpacing = 0.4,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink3,
        letterSpacing: letterSpacing,
      );
}

ThemeData buildAppTheme() {
  final dark = AppColors.isDark;
  return ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AppColors.paper2,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.card,
      error: AppColors.danger,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.chrome,
      contentTextStyle: AppFonts.body(size: 13.5, color: Colors.white),
      actionTextColor: AppColors.accent2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.chromeLine),
      ),
    ),
  );
}

ThemeData pickerAppTheme(BuildContext context) {
  final base = Theme.of(context);
  Color onDay(Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) return Colors.white;
    if (states.contains(WidgetState.disabled)) return AppColors.ink3.withOpacity(0.4);
    return AppColors.ink;
  }

  Color? dayBg(Set<WidgetState> states) => states.contains(WidgetState.selected) ? AppColors.accent : null;

  final confirmButtonStyle = TextButton.styleFrom(
    foregroundColor: AppColors.accent,
    textStyle: AppFonts.body(size: 13.5, weight: FontWeight.w600),
  );
  final cancelButtonStyle = TextButton.styleFrom(
    foregroundColor: AppColors.ink2,
    textStyle: AppFonts.body(size: 13.5, weight: FontWeight.w600),
  );

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.ink3,
      outline: AppColors.line2,
      surfaceContainerHigh: AppColors.paper2,
    ),
    textTheme: base.textTheme.apply(fontFamily: AppFonts.body().fontFamily),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      headerBackgroundColor: AppColors.accent,
      headerForegroundColor: Colors.white,
      headerHeadlineStyle: AppFonts.display(size: 22, color: Colors.white),
      headerHelpStyle: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: Colors.white.withOpacity(0.85)),
      weekdayStyle: AppFonts.body(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
      dayStyle: AppFonts.body(size: 13.5, color: AppColors.ink),
      dayForegroundColor: WidgetStateProperty.resolveWith(onDay),
      dayBackgroundColor: WidgetStateProperty.resolveWith(dayBg),
      dayOverlayColor: WidgetStateProperty.all(AppColors.accent.withOpacity(0.08)),
      todayForegroundColor: WidgetStateProperty.all(AppColors.accent),
      todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
      todayBorder: BorderSide(color: AppColors.accent, width: 1.2),
      rangePickerBackgroundColor: AppColors.card,
      rangePickerHeaderBackgroundColor: AppColors.accent,
      rangePickerHeaderForegroundColor: Colors.white,
      rangePickerHeaderHeadlineStyle: AppFonts.display(size: 20, color: Colors.white),
      rangePickerHeaderHelpStyle: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: Colors.white.withOpacity(0.85)),
      rangeSelectionBackgroundColor: AppColors.accentSoft,
      rangeSelectionOverlayColor: WidgetStateProperty.all(AppColors.accent.withOpacity(0.1)),
      dividerColor: AppColors.line,
      cancelButtonStyle: cancelButtonStyle,
      confirmButtonStyle: confirmButtonStyle,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      helpTextStyle: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
      dialBackgroundColor: AppColors.paper2,
      dialHandColor: AppColors.accent,
      dialTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.ink),
      hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.paper2),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.ink),
      hourMinuteTextStyle: AppFonts.display(size: 32),
      dayPeriodColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.paper2),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.ink2),
      dayPeriodBorderSide: BorderSide(color: AppColors.line2),
      entryModeIconColor: AppColors.accent,
      cancelButtonStyle: cancelButtonStyle,
      confirmButtonStyle: confirmButtonStyle,
    ),
  );
}
