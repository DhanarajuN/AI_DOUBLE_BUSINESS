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
