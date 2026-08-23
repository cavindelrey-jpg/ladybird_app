// lib/theme/app_theme.dart
// Green Hills Design System — Material 3, Green × Gold palette.
// All colour tokens are defined once here, used everywhere.
//
// `C.primary`/`navy`/`navy2`/`navy3` were Academia's blue/navy brand
// tokens. This codebase now only ships as Green Hills (codemagic.yaml
// has a single BRAND_ID=green_hill workflow) and ~60 call sites across
// clubs/magazine/admin pages still read these `C.xxx` constants directly
// in `const` constructors rather than the brand-aware AppColors.of()
// (see app_colors.dart's file header for why `C` can't be made
// context-aware without breaking every `const` call site). Repainting
// the constants themselves to Green Hills' green — the same values
// AppColors.greenHillLight already samples from
// assets/branding/green_hill_logo.png's shield — fixes every one of
// those sites at once without the multi-file `const`-removal refactor.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../config/branding.dart';

/// Green Hills Design System colour tokens.
class C {
  C._();

  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color primary   = Color(0xFF16A34A);   // Green Hills green
  static const Color primaryBg = Color(0xFFDCFCE7);   // Very pale green

  static const Color navy  = Color(0xFF0A7A3B);   // Deep green (was navy)
  static const Color navy2 = Color(0xFF0F5C35);   // Mid green (was navy2)
  static const Color navy3 = Color(0xFF1F7A4D);   // Slate green (was navy3)

  static const Color gold  = Color(0xFFC9A227);   // Academy Gold
  static const Color goldp = Color(0xFFFBF3DA);   // Pale gold

  // ── Surfaces ────────────────────────────────────────────────────────────
  static const Color bg    = Color(0xFFF5F7FA);   // App background
  static const Color surf  = Color(0xFFFFFFFF);   // Card surface
  static const Color surf2 = Color(0xFFF8F9FB);   // Secondary surface
  static const Color surf3 = Color(0xFFF1F3F8);   // Tertiary surface (inputs)

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color txt   = Color(0xFF0F172A);   // Primary text
  static const Color txt2  = Color(0xFF475569);   // Secondary text
  static const Color muted = Color(0xFF94A3B8);   // Muted / placeholder

  // ── Borders ────────────────────────────────────────────────────────────
  static const Color bdr   = Color(0xFFE2E8F0);   // Standard border
  static const Color bdr2  = Color(0xFFF1F5F9);   // Subtle border

  // ── Semantic ────────────────────────────────────────────────────────────
  static const Color grn   = Color(0xFF16A34A);
  static const Color grnb  = Color(0xFFDCFCE7);
  static const Color red   = Color(0xFFDC2626);
  static const Color redb  = Color(0xFFFEE2E2);
  static const Color org   = Color(0xFFEA580C);
  static const Color orgb  = Color(0xFFFFEDD5);
  static const Color blu   = Color(0xFF0284C7);
  static const Color blub  = Color(0xFFE0F2FE);
  static const Color pur   = Color(0xFF7C3AED);
  static const Color purb  = Color(0xFFF5F3FF);

  // ── Welcome / Onboarding ────────────────────────────────────────────────
  static const Color welcomeBg = navy;
}

/// Default Academia theme (before institution brand loads).
class AppTheme {
  AppTheme._();

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: C.bg,
    // Seeded from Branding.current rather than the hardcoded C.navy/C.gold
    // so a Green Hill build's default Material components (FAB, default
    // buttons, selection handles, etc.) pick up its color instead of
    // Academia's. Partial coverage, not a full re-theme: the ~69 files
    // that draw with C.primary/C.gold/C.navy directly (same set flagged
    // in the dark-mode audit) still render Academia's fixed palette —
    // making them branding-aware is the same class of mechanical,
    // multi-hour, per-file work as the dark-mode conversion, and out of
    // scope here for the same reason. See docs/AUTOPILOT_LOG.md.
    colorScheme: ColorScheme.fromSeed(
      seedColor: Branding.current.primaryColor,
      primary: Branding.current.primaryColor,
      secondary: Branding.current.accentColor,
      surface: C.surf,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.surf,
      foregroundColor: C.txt,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: C.txt),
    ),
    cardTheme: CardThemeData(
      color: C.surf,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: C.bdr),
      ),
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: C.primary.withValues(alpha: .4),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        overlayColor: Colors.black.withValues(alpha: .08),
        animationDuration: Dur.fast,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.primary,
        side: const BorderSide(color: C.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        overlayColor: C.primary.withValues(alpha: .06),
        animationDuration: Dur.fast,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.primary,
        overlayColor: C.primary.withValues(alpha: .06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xs)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surf3,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.bdr)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.bdr)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.red)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surf,
      indicatorColor: C.primaryBg,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: C.primary, size: 22);
        }
        return const IconThemeData(color: C.muted, size: 22);
      }),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: C.surf3,
      selectedColor: C.primaryBg,
      labelStyle: const TextStyle(fontSize: 12),
      side: const BorderSide(color: C.bdr),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: C.bdr,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: C.gold,
      foregroundColor: C.navy,
      elevation: 2,
    ),
    extensions: const [AppColors.light],
  );

  // ── Dark ──────────────────────────────────────────────────────────────
  // Mirrors `light` field-for-field but sourced from `AppColors.dark`
  // instead of the hardcoded `C.xxx` constants — `C` itself stays a
  // light-only compile-time constant (see app_colors.dart's file comment
  // for why), so this is built from the dark token set directly rather
  // than trying to make `C` context-aware.
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.dark.bg,
    // Same branding seed as the light theme above — see that comment for
    // the partial-coverage tradeoff.
    colorScheme: ColorScheme.fromSeed(
      seedColor: Branding.current.primaryColor,
      primary: Branding.current.primaryColor,
      secondary: Branding.current.accentColor,
      surface: AppColors.dark.surf,
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.dark.surf,
      foregroundColor: AppColors.dark.txt,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: AppColors.dark.txt),
    ),
    cardTheme: CardThemeData(
      color: AppColors.dark.surf,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.dark.bdr),
      ),
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.dark.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.dark.primary.withValues(alpha: .4),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        overlayColor: Colors.white.withValues(alpha: .08),
        animationDuration: Dur.fast,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.dark.primary,
        side: BorderSide(color: AppColors.dark.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        overlayColor: AppColors.dark.primary.withValues(alpha: .1),
        animationDuration: Dur.fast,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.dark.primary,
        overlayColor: AppColors.dark.primary.withValues(alpha: .1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.xs)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.dark.surf3,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dark.bdr)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dark.bdr)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dark.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dark.red)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: AppColors.dark.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.dark.surf,
      indicatorColor: AppColors.dark.primaryBg,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: AppColors.dark.primary, size: 22);
        }
        return IconThemeData(color: AppColors.dark.muted, size: 22);
      }),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.dark.surf3,
      selectedColor: AppColors.dark.primaryBg,
      labelStyle: const TextStyle(fontSize: 12),
      side: BorderSide(color: AppColors.dark.bdr),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: AppColors.dark.bdr,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.dark.gold,
      foregroundColor: AppColors.dark.navy,
      elevation: 2,
    ),
    extensions: const [AppColors.dark],
  );
}

// ── Design tokens ─────────────────────────────────────────────────────────────

/// Consistent border radius values used across the app.
class Rad {
  static const double xs  = 8;
  static const double sm  = 12;
  static const double md  = 16;
  static const double lg  = 20;
  static const double xl  = 24;
  static const double xxl = 32;
}

/// Standard elevation shadows.
///
/// Each level is two stacked shadows rather than one: a tight, low-alpha
/// "contact" shadow close to the surface, plus a soft, wider "ambient"
/// shadow further out. A single flat blur reads like a CSS default; two
/// layered shadows at different spreads is what makes elevation look
/// physical instead of pasted-on — the same trick real design systems
/// (Material's own elevation tokens, Apple's HIG shadows) use.
class Shad {
  static List<BoxShadow> get sm => [
    BoxShadow(color: Colors.black.withValues(alpha: .05),
        blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(color: Colors.black.withValues(alpha: .04),
        blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get md => [
    BoxShadow(color: Colors.black.withValues(alpha: .05),
        blurRadius: 4, offset: const Offset(0, 1)),
    BoxShadow(color: Colors.black.withValues(alpha: .07),
        blurRadius: 20, offset: const Offset(0, 6)),
  ];
  static List<BoxShadow> get lg => [
    BoxShadow(color: Colors.black.withValues(alpha: .06),
        blurRadius: 6, offset: const Offset(0, 2)),
    BoxShadow(color: Colors.black.withValues(alpha: .11),
        blurRadius: 32, offset: const Offset(0, 12)),
  ];
}

/// Motion tokens — every animated transition in the app should reach for
/// one of these instead of a bespoke `Duration(milliseconds: ...)`, so
/// interactions feel like one consistent hand rather than whatever felt
/// right on each individual screen.
class Dur {
  Dur._();
  static const Duration fast = Duration(milliseconds: 150);   // taps, toggles
  static const Duration med  = Duration(milliseconds: 280);   // entrances, sheets
  static const Duration slow = Duration(milliseconds: 450);   // full-screen transitions
  static const Curve curve   = Curves.easeOutCubic;
}

/// Semantic colour helpers by role.
class RoleColors {
  static Color bg(String role) {
    switch (role) {
      case 'superAdmin':     return C.purb;
      case 'schoolAdmin':    return C.primaryBg;
      case 'departmentAdmin':return C.blub;
      case 'lecturer':       return C.goldp;
      case 'student':        return C.grnb;
      default:               return C.surf3;
    }
  }

  static Color fg(String role) {
    switch (role) {
      case 'superAdmin':     return C.pur;
      case 'schoolAdmin':    return C.primary;
      case 'departmentAdmin':return C.blu;
      case 'lecturer':       return C.gold;
      case 'student':        return C.grn;
      default:               return C.muted;
    }
  }
}

// ── Type scale ──────────────────────────────────────────────────────────
// Named text roles instead of ad-hoc `fontSize: 13` scattered per screen.
// Sora for anything that needs to command attention (headers, titles,
// numbers people should notice); Inter for anything meant to be read at
// length (body copy, captions). Line-height is set deliberately per role
// — tight for headers, generous (1.5–1.6) for reading text, since a lot
// of "feels cramped" is line-height fighting the text, not the font size.
//
// Color is intentionally NOT baked in (except caption/label, which are
// almost always muted) — call `.copyWith(color: ...)` at the use site for
// anything that needs to sit on a dark background or change with state.
class AppText {
  AppText._();

  static TextStyle get display => GoogleFonts.sora(
      fontSize: 30, fontWeight: FontWeight.w800, height: 1.15,
      letterSpacing: -0.5, color: C.txt);

  static TextStyle get h1 => GoogleFonts.sora(
      fontSize: 23, fontWeight: FontWeight.w800, height: 1.2,
      letterSpacing: -0.4, color: C.txt);

  static TextStyle get h2 => GoogleFonts.sora(
      fontSize: 18, fontWeight: FontWeight.w700, height: 1.3,
      letterSpacing: -0.2, color: C.txt);

  /// Card titles, list-item primary text, section headers.
  static TextStyle get title => GoogleFonts.sora(
      fontSize: 15, fontWeight: FontWeight.w700, height: 1.35, color: C.txt);

  /// Secondary line under a title — byline, role, metadata row.
  static TextStyle get subtitle => GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w600, height: 1.4, color: C.txt2);

  /// Long-form reading text — article bodies, descriptions.
  static TextStyle get body => GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w400, height: 1.65, color: C.txt);

  /// Compact body text — comments, list secondary text.
  static TextStyle get bodySm => GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w400, height: 1.5, color: C.txt2);

  /// Timestamps, counts, fine print.
  static TextStyle get caption => GoogleFonts.inter(
      fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.4, color: C.muted);

  /// Badges, overline tags, all-caps labels.
  static TextStyle get label => GoogleFonts.inter(
      fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.2,
      letterSpacing: 0.6, color: C.muted);

  /// Button label text.
  static TextStyle get button => GoogleFonts.sora(
      fontSize: 15, fontWeight: FontWeight.w700, height: 1.2, color: Colors.white);
}
