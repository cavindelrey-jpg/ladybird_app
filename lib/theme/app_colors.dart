// lib/theme/app_colors.dart
// Dark-mode-aware color tokens, additive to the existing `C` static
// constants in app_theme.dart — `C` is NOT touched by this file. `C.xxx`
// is a compile-time constant used inside hundreds of `const` widget
// constructors across the app; turning it into something context-aware
// would break every one of those `const` call sites at once, with no
// compiler in this environment to catch which ones broke. So instead:
// `C` stays exactly as it was (the app's existing light-only palette),
// and this new `AppColors` ThemeExtension is where dark-mode-aware
// widgets read their colors from — via `AppColors.of(context)` — no
// `const` allowed at the call site, but nothing existing was touched.
//
// Values mirror the approved Home-page dark mockup exactly (see the
// html mockup shared in chat) — this is not a fresh palette, it's that
// same palette translated into Flutter.
//
// Currently wired into: main.dart (MaterialApp.darkTheme/themeMode via
// ThemeProvider — this is what makes the toggle in Settings actually do
// something), app_background.dart (so the shared page backdrop follows
// the toggle even on pages that haven't converted their own colors yet),
// and universal_home_page.dart (Home — every color reference converted
// from `C.xxx` to `AppColors.of(context)`). Every other screen still
// reads `C.xxx` directly and stays light-only regardless of the toggle
// until it gets the same conversion.

import 'package:flutter/material.dart';
import '../config/branding.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color bg, surf, surf2, surf3;
  final Color txt, txt2, muted;
  final Color bdr, bdr2;
  final Color primary, primaryBg;
  final Color navy, navy2;
  final Color gold, goldBg;
  final Color grn, grnBg;
  final Color red, redBg;
  final Color org, orgBg;
  final Color pur, purBg, purDark, purLight;
  final Color blu, bluBg;
  final Color shadow;

  const AppColors({
    required this.bg, required this.surf, required this.surf2, required this.surf3,
    required this.txt, required this.txt2, required this.muted,
    required this.bdr, required this.bdr2,
    required this.primary, required this.primaryBg,
    required this.navy, required this.navy2,
    required this.gold, required this.goldBg,
    required this.grn, required this.grnBg,
    required this.red, required this.redBg,
    required this.org, required this.orgBg,
    required this.pur, required this.purBg, required this.purDark, required this.purLight,
    required this.blu, required this.bluBg,
    required this.shadow,
  });

  /// Checks Branding.current BEFORE consulting the ThemeExtension registered
  /// on the current Theme. That order matters: AppTheme.light/.dark both
  /// register a brand-specific AppColors object under `extensions:` (see
  /// `_brandColors()` in app_theme.dart -- it mirrors this same switch), so
  /// `Theme.of(context).extension<AppColors>()` always finds something and
  /// the final `?? (isDark ? dark : light)` fallback is mostly a belt-and-
  /// suspenders default for a brand with no dedicated palette. Checking
  /// brand first here too means this keeps resolving correctly even if
  /// that registration ever drifts out of sync again (as it previously
  /// did: AppTheme unconditionally registered Green Hill's palette for
  /// every brand, so Ladybird silently rendered Green Hill's green).
  static AppColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (Branding.current.brandId) {
      case 'green_hill':
        return isDark ? greenHillDark : greenHillLight;
      case 'ladybird':
      case 'cfpmi':
        return isDark ? ladybirdDark : ladybirdLight;
      default:
        return Theme.of(context).extension<AppColors>() ?? (isDark ? dark : light);
    }
  }

  // ── Light — identical values to `C` in app_theme.dart ───────────────────
  static const AppColors light = AppColors(
    bg: Color(0xFFF5F7FA), surf: Color(0xFFFFFFFF), surf2: Color(0xFFF8F9FB), surf3: Color(0xFFF1F3F8),
    txt: Color(0xFF0F172A), txt2: Color(0xFF475569), muted: Color(0xFF94A3B8),
    bdr: Color(0xFFE2E8F0), bdr2: Color(0xFFF1F5F9),
    primary: Color(0xFF1A56DB), primaryBg: Color(0xFFEEF4FF),
    navy: Color(0xFF0A1F44), navy2: Color(0xFF152D5E),
    gold: Color(0xFFC9A227), goldBg: Color(0xFFFBF3DA),
    grn: Color(0xFF16A34A), grnBg: Color(0xFFDCFCE7),
    red: Color(0xFFDC2626), redBg: Color(0xFFFEE2E2),
    org: Color(0xFFEA580C), orgBg: Color(0xFFFFEDD5),
    pur: Color(0xFF7C3AED), purBg: Color(0xFFF5F3FF), purDark: Color(0xFF6D28D9), purLight: Color(0xFF8B5CF6),
    blu: Color(0xFF0284C7), bluBg: Color(0xFFE0F2FE),
    shadow: Color(0x0D0A1432), // rgba(10,20,50,.05)
  );

  // ── Dark — matches the approved Home dark-mode mockup ───────────────────
  static const AppColors dark = AppColors(
    bg: Color(0xFF0D1117), surf: Color(0xFF161B22), surf2: Color(0xFF1E2633), surf3: Color(0xFF242C3D),
    txt: Color(0xFFF5F5F5), txt2: Color(0xFFB8BCC8), muted: Color(0xFF6B7280),
    bdr: Color(0xFF1E2633), bdr2: Color(0xFF1A2230),
    primary: Color(0xFF4F8CFF), primaryBg: Color(0x1A4F8CFF), // rgba(79,140,255,.10)
    navy: Color(0xFF060B14), navy2: Color(0xFF0D1117),
    gold: Color(0xFFFBBF24), goldBg: Color(0x1AFBBF24),
    grn: Color(0xFF22C55E), grnBg: Color(0x1A22C55E),
    red: Color(0xFFEF4444), redBg: Color(0x1AEF4444),
    org: Color(0xFFFB923C), orgBg: Color(0x1AFB923C),
    pur: Color(0xFF8B5CF6), purBg: Color(0x1A8B5CF6), purDark: Color(0xFFA78BFA), purLight: Color(0xFF8B5CF6),
    blu: Color(0xFF4F8CFF), bluBg: Color(0x1A4F8CFF),
    shadow: Color(0x73000000), // rgba(0,0,0,.45)
  );

  // ── Green Hill — brand/header colors only (primary, navy) swapped to
  // the crest's green; every functional/status color (gold "Gold" tier
  // badge, red, org, pur, blu, grn success-state) stays IDENTICAL to the
  // Academia palette -- those represent app state, not brand identity,
  // and repainting them green would collide with e.g. the entitlement
  // system's own "Gold tier" badge or a success/error indicator.
  // primary/navy values sampled from assets/branding/green_hill_logo.png's
  // shield (medium green fill, darker green outline).
  static const AppColors greenHillLight = AppColors(
    bg: Color(0xFFF5F7FA), surf: Color(0xFFFFFFFF), surf2: Color(0xFFF8F9FB), surf3: Color(0xFFF1F3F8),
    txt: Color(0xFF0F172A), txt2: Color(0xFF475569), muted: Color(0xFF94A3B8),
    bdr: Color(0xFFE2E8F0), bdr2: Color(0xFFF1F5F9),
    primary: Color(0xFF16A34A), primaryBg: Color(0xFFDCFCE7),
    navy: Color(0xFF0A7A3B), navy2: Color(0xFF0F5C35),
    gold: Color(0xFFC9A227), goldBg: Color(0xFFFBF3DA),
    grn: Color(0xFF16A34A), grnBg: Color(0xFFDCFCE7),
    red: Color(0xFFDC2626), redBg: Color(0xFFFEE2E2),
    org: Color(0xFFEA580C), orgBg: Color(0xFFFFEDD5),
    pur: Color(0xFF7C3AED), purBg: Color(0xFFF5F3FF), purDark: Color(0xFF6D28D9), purLight: Color(0xFF8B5CF6),
    blu: Color(0xFF0284C7), bluBg: Color(0xFFE0F2FE),
    shadow: Color(0x0D0A1432),
  );

  static const AppColors greenHillDark = AppColors(
    bg: Color(0xFF0D1117), surf: Color(0xFF161B22), surf2: Color(0xFF1E2633), surf3: Color(0xFF242C3D),
    txt: Color(0xFFF5F5F5), txt2: Color(0xFFB8BCC8), muted: Color(0xFF6B7280),
    bdr: Color(0xFF1E2633), bdr2: Color(0xFF1A2230),
    primary: Color(0xFF22C55E), primaryBg: Color(0x1A22C55E),
    navy: Color(0xFF06140D), navy2: Color(0xFF0D1F17),
    gold: Color(0xFFFBBF24), goldBg: Color(0x1AFBBF24),
    grn: Color(0xFF22C55E), grnBg: Color(0x1A22C55E),
    red: Color(0xFFEF4444), redBg: Color(0x1AEF4444),
    org: Color(0xFFFB923C), orgBg: Color(0x1AFB923C),
    pur: Color(0xFF8B5CF6), purBg: Color(0x1A8B5CF6), purDark: Color(0xFFA78BFA), purLight: Color(0xFF8B5CF6),
    blu: Color(0xFF4F8CFF), bluBg: Color(0x1A4F8CFF),
    shadow: Color(0x73000000),
  );

  // ── Ladybird — brand/header colors (primary, navy, gold) all sourced
  // from the real brand palette (assets/branding/ladybird.json /
  // lib/config/branding.dart's primaryColor #1E6FEB, secondaryColor
  // #0B1F4D, accentColor #F4B400 -- taken from mockups/ladybird_homescreen
  // .jpg and the crest in mockups/ladybird_signin.jpg). Unlike Green
  // Hill's split, gold IS a brand color here (the crest's stars), not
  // just a functional tier-badge color, so it's swapped too -- it still
  // reads fine in the "Gold tier" badge role since both meanings are
  // "gold". Every other functional/status color (red, org, pur, blu, grn
  // success-state) stays identical to the base Academia palette -- those
  // represent app state, not brand identity.
  static const AppColors ladybirdLight = AppColors(
    bg: Color(0xFFF5F7FA), surf: Color(0xFFFFFFFF), surf2: Color(0xFFF8F9FB), surf3: Color(0xFFF1F3F8),
    txt: Color(0xFF0F172A), txt2: Color(0xFF475569), muted: Color(0xFF94A3B8),
    bdr: Color(0xFFE2E8F0), bdr2: Color(0xFFF1F5F9),
    primary: Color(0xFF1E6FEB), primaryBg: Color(0xFFEAF2FE),
    navy: Color(0xFF0B1F4D), navy2: Color(0xFF15479C),
    gold: Color(0xFFF4B400), goldBg: Color(0xFFFFF4D6),
    grn: Color(0xFF16A34A), grnBg: Color(0xFFDCFCE7),
    red: Color(0xFFDC2626), redBg: Color(0xFFFEE2E2),
    org: Color(0xFFEA580C), orgBg: Color(0xFFFFEDD5),
    pur: Color(0xFF7C3AED), purBg: Color(0xFFF5F3FF), purDark: Color(0xFF6D28D9), purLight: Color(0xFF8B5CF6),
    blu: Color(0xFF0284C7), bluBg: Color(0xFFE0F2FE),
    shadow: Color(0x0D0A1432),
  );

  // Dark gold kept as the same amber (#FBBF24) the base `dark`/
  // `greenHillDark` palettes already use rather than the brand's exact
  // #F4B400 -- consistent with how primary/navy get lightened for dark-bg
  // legibility below, and keeps the "gold tier badge" color identical
  // across brands in dark mode, same reasoning as Green Hill's split.
  static const AppColors ladybirdDark = AppColors(
    bg: Color(0xFF0D1117), surf: Color(0xFF161B22), surf2: Color(0xFF1E2633), surf3: Color(0xFF242C3D),
    txt: Color(0xFFF5F5F5), txt2: Color(0xFFB8BCC8), muted: Color(0xFF6B7280),
    bdr: Color(0xFF1E2633), bdr2: Color(0xFF1A2230),
    primary: Color(0xFF4F8CFF), primaryBg: Color(0x1A4F8CFF),
    navy: Color(0xFF0B1A38), navy2: Color(0xFF13294F),
    gold: Color(0xFFFBBF24), goldBg: Color(0x1AFBBF24),
    grn: Color(0xFF22C55E), grnBg: Color(0x1A22C55E),
    red: Color(0xFFEF4444), redBg: Color(0x1AEF4444),
    org: Color(0xFFFB923C), orgBg: Color(0x1AFB923C),
    pur: Color(0xFF8B5CF6), purBg: Color(0x1A8B5CF6), purDark: Color(0xFFA78BFA), purLight: Color(0xFF8B5CF6),
    blu: Color(0xFF4F8CFF), bluBg: Color(0x1A4F8CFF),
    shadow: Color(0x73000000),
  );

  @override
  AppColors copyWith({
    Color? bg, Color? surf, Color? surf2, Color? surf3,
    Color? txt, Color? txt2, Color? muted,
    Color? bdr, Color? bdr2,
    Color? primary, Color? primaryBg,
    Color? navy, Color? navy2,
    Color? gold, Color? goldBg,
    Color? grn, Color? grnBg,
    Color? red, Color? redBg,
    Color? org, Color? orgBg,
    Color? pur, Color? purBg, Color? purDark, Color? purLight,
    Color? blu, Color? bluBg,
    Color? shadow,
  }) {
    return AppColors(
      bg: bg ?? this.bg, surf: surf ?? this.surf, surf2: surf2 ?? this.surf2, surf3: surf3 ?? this.surf3,
      txt: txt ?? this.txt, txt2: txt2 ?? this.txt2, muted: muted ?? this.muted,
      bdr: bdr ?? this.bdr, bdr2: bdr2 ?? this.bdr2,
      primary: primary ?? this.primary, primaryBg: primaryBg ?? this.primaryBg,
      navy: navy ?? this.navy, navy2: navy2 ?? this.navy2,
      gold: gold ?? this.gold, goldBg: goldBg ?? this.goldBg,
      grn: grn ?? this.grn, grnBg: grnBg ?? this.grnBg,
      red: red ?? this.red, redBg: redBg ?? this.redBg,
      org: org ?? this.org, orgBg: orgBg ?? this.orgBg,
      pur: pur ?? this.pur, purBg: purBg ?? this.purBg, purDark: purDark ?? this.purDark, purLight: purLight ?? this.purLight,
      blu: blu ?? this.blu, bluBg: bluBg ?? this.bluBg,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg), surf: l(surf, other.surf), surf2: l(surf2, other.surf2), surf3: l(surf3, other.surf3),
      txt: l(txt, other.txt), txt2: l(txt2, other.txt2), muted: l(muted, other.muted),
      bdr: l(bdr, other.bdr), bdr2: l(bdr2, other.bdr2),
      primary: l(primary, other.primary), primaryBg: l(primaryBg, other.primaryBg),
      navy: l(navy, other.navy), navy2: l(navy2, other.navy2),
      gold: l(gold, other.gold), goldBg: l(goldBg, other.goldBg),
      grn: l(grn, other.grn), grnBg: l(grnBg, other.grnBg),
      red: l(red, other.red), redBg: l(redBg, other.redBg),
      org: l(org, other.org), orgBg: l(orgBg, other.orgBg),
      pur: l(pur, other.pur), purBg: l(purBg, other.purBg), purDark: l(purDark, other.purDark), purLight: l(purLight, other.purLight),
      blu: l(blu, other.blu), bluBg: l(bluBg, other.bluBg),
      shadow: l(shadow, other.shadow),
    );
  }
}
