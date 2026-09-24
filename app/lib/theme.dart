import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shuddham brand palette (matches the design canvas and admin panel).
class AppColors {
  static const primary = Color(0xFF1553B8);
  static const primaryPressed = Color(0xFF0F3F8F);
  static const navy = Color(0xFF0F2A5C);
  static const muted = Color(0xFF56627A);
  static const bg = Color(0xFFF4F7FB);
  static const card = Colors.white;
  static const border = Color(0xFFD5DEEB);
  static const line = Color(0xFFE9EEF5);
  static const tint = Color(0xFFE3EDFB);
  static const lightBlue = Color(0xFF5BB8F5);
  static const onDarkMuted = Color(0xFFB8C7E0);
  static const warn = Color(0xFFD97706);
  static const warnText = Color(0xFF9A4A0B);
  static const warnBg = Color(0xFFFDF1E2);
  static const bad = Color(0xFFB42318);
  static const badBg = Color(0xFFFDECEA);
}

TextStyle display(double size, {Color color = AppColors.navy, FontWeight weight = FontWeight.w700}) {
  try {
    return GoogleFonts.getFont('Bricolage Grotesque', fontSize: size, fontWeight: weight, color: color, height: 1.15);
  } catch (_) {
    return TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.15);
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.bg,
      error: AppColors.bad,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  final text = GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
    bodyColor: AppColors.navy,
    displayColor: AppColors.navy,
  );
  final radius = BorderRadius.circular(14);
  return base.copyWith(
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.bad)),
      hintStyle: const TextStyle(color: AppColors.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.tint,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
    ),
  );
}
