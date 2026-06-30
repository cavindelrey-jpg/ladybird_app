// lib/theme/institution_theme_engine.dart
// Generates a full Flutter ThemeData from an Institution's brand config.
// Call InstitutionThemeEngine.build(institution) and feed it into MaterialApp.theme.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/institution.dart';

class InstitutionThemeEngine {
  InstitutionThemeEngine._();

  /// Build a ThemeData that reflects the institution's brand identity.
  static ThemeData build(Institution institution) {
    final primary = institution.primary;
    final secondary = institution.secondary;
    final accent = institution.accent;

    final textTheme = _buildTextTheme(institution.fontFamily, primary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FB),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: _titleStyle(institution.fontFamily, primary),
        iconTheme: IconThemeData(color: primary),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: GoogleFonts.getFont(
            institution.fontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.getFont(
            institution.fontFamily, fontSize: 10),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.getFont(institution.fontFamily,
              fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: _withAlpha(primary, 0.15),
        labelStyle: GoogleFonts.getFont(institution.fontFamily, fontSize: 12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: _withAlpha(primary, 0.12),
        labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.getFont(institution.fontFamily, fontSize: 11, fontWeight: FontWeight.w600)),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      textTheme: textTheme,
      dividerColor: const Color(0xFFE2E8F0),
    );
  }

  static TextTheme _buildTextTheme(String fontFamily, Color primary) {
    try {
      final baseTheme = GoogleFonts.getTextTheme(fontFamily);
      return baseTheme.copyWith(
        displayLarge: _safeGetFont(fontFamily,
            fontSize: 32, fontWeight: FontWeight.w800),
        titleLarge: _safeGetFont(fontFamily,
            fontSize: 18, fontWeight: FontWeight.w700),
        bodyLarge: _safeGetFont(fontFamily, fontSize: 16),
        bodyMedium: _safeGetFont(fontFamily, fontSize: 14),
        labelSmall: _safeGetFont(fontFamily, fontSize: 11),
      );
    } catch (_) {
      // Fall back to Inter if the font name is invalid
      return GoogleFonts.interTextTheme();
    }
  }

  static TextStyle _safeGetFont(String fontFamily, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) {
    try {
      return GoogleFonts.getFont(fontFamily,
          fontSize: fontSize, fontWeight: fontWeight, color: color);
    } catch (_) {
      return GoogleFonts.inter(
          fontSize: fontSize, fontWeight: fontWeight, color: color);
    }
  }

  static TextStyle _titleStyle(String fontFamily, Color color) {
    return _safeGetFont(fontFamily,
        fontSize: 17, fontWeight: FontWeight.w700, color: color);
  }

  static Color _withAlpha(Color c, double alpha) =>
      c.withValues(alpha: alpha.clamp(0.0, 1.0));
}
