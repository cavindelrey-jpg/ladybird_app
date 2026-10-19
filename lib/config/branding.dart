// lib/config/branding.dart
// The *look* half of the white-label split (see app_config.dart for the
// *behavior* half). Selected via --dart-define=BRAND_ID=<id> (defaults
// to 'ladybird' in this fork), loaded once at startup from the matching
// assets/branding/<id>.json, and read everywhere via Branding.current.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/analytics_service.dart' show CrashService;

class Branding {
  final String brandId;
  final String appName;
  final String tagline;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String logoAssetPath;
  final String splashAssetPath;

  /// The tenant prefix a school/Academia voucher code must start with to
  /// be accepted by THIS build (2026-08-31 voucher redesign, item 7:
  /// server-side app-context validation). Read from branding.json's
  /// `voucherPrefix` when present; falls back to a hardcoded per-brand
  /// table below for brands whose json predates this field, so a stale
  /// asset never silently disables the tenant check.
  final String voucherPrefix;

  /// The tenant school identifier for this app build (e.g. 'ladybird', 'green_hill').
  /// Null only for the central 'academia' General application.
  final String? schoolId;

  const Branding({
    required this.brandId,
    required this.appName,
    required this.tagline,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.logoAssetPath,
    required this.splashAssetPath,
    required this.voucherPrefix,
    this.schoolId,
  });

  static String _fallbackPrefix(String brandId) {
    switch (brandId) {
      case 'green_hill': return 'GH';
      case 'ladybird':   return 'CF';
      case 'cfpmi':      return 'CF';
      case 'academia':   return 'AC';
      default:           return brandId.toUpperCase();
    }
  }

  static String? _fallbackSchoolId(String brandId) {
    switch (brandId) {
      case 'green_hill': return 'green_hill';
      case 'ladybird':   return 'cfpmi';
      case 'cfpmi':      return 'cfpmi';
      case 'academia':   return null;
      default:           return brandId;
    }
  }

  // CFPMI application brand configuration (domain: cfpmischools.com)
  static const String _envBrandId =
      String.fromEnvironment('BRAND_ID', defaultValue: 'cfpmi');

  /// Hardcoded fallback so every screen has *something* to read even if
  /// asset loading hasn't completed yet (or fails).
  static Branding _current = const Branding(
    brandId: _envBrandId,
    appName: 'CFPMI',
    tagline: 'Professional Training & Academic Excellence',
    primaryColor: const Color(0xFF1E6FEB),
    secondaryColor: const Color(0xFF0B1F4D),
    accentColor: const Color(0xFFF4B400),
    logoAssetPath: 'assets/branding/ladybird_logo.jpg',
    splashAssetPath: 'assets/branding/ladybird_logo.jpg',
    voucherPrefix: 'CF',
    schoolId: 'cfpmi',
  );

  static Branding get current => _current;

  /// Allows test suites to simulate different school brands and environments.
  static void setForTesting(Branding? branding) {
    if (branding != null) {
      _current = branding;
    } else {
      _current = const Branding(
        brandId: _envBrandId,
        appName: 'CFPMI',
        tagline: 'Professional Training & Academic Excellence',
        primaryColor: const Color(0xFF1E6FEB),
        secondaryColor: const Color(0xFF0B1F4D),
        accentColor: const Color(0xFFF4B400),
        logoAssetPath: 'assets/branding/ladybird_logo.jpg',
        splashAssetPath: 'assets/branding/ladybird_logo.jpg',
        voucherPrefix: 'CF',
        schoolId: 'cfpmi',
      );
    }
  }

  /// True only for the central Academia General app.
  bool get isGeneralApp => brandId == 'academia';

  /// True for any school-branded app (e.g. Ladybird, Green Hills, St. Stephen).
  bool get isSchoolApp => !isGeneralApp;

  /// Effective school ID of this application environment.
  String? get effectiveSchoolId => schoolId ?? _fallbackSchoolId(brandId);

  /// True only for the public Academia app. The XP economy (paywalled
  /// past papers, purchases, leaderboards) is an Academia-only mechanic —
  /// per spec: Green Hills and Legitbell (and any other white-label
  /// school build) must have all papers/books auto-unlocked, with no XP
  /// or fiat paywall of any kind. Deliberately an allowlist (only
  /// 'academia' opts in) rather than a denylist of known white-label
  /// ids, so a brand this repo doesn't know about yet (a future
  /// Legitbell-style fork, which per docs/AUTOPILOT_LOG.md gets its own
  /// repo/BRAND_ID the same way this Ladybird fork does) defaults to
  /// "no XP paywall" rather than accidentally inheriting one.
  bool get xpEconomyEnabled => brandId == 'academia';

  static Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  /// Loads `assets/branding/<BRAND_ID>.json` and replaces [current]. Falls
  /// back to the hardcoded Academia defaults above on any error (missing
  /// file, malformed JSON) rather than crashing startup over a branding
  /// file -- matches ConfigService's own "non-blocking, uses defaults if
  /// unavailable" philosophy.
  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/branding/$_envBrandId.json');
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _current = Branding(
        brandId: _envBrandId,
        appName: m['appName'] ?? _current.appName,
        tagline: m['tagline'] ?? _current.tagline,
        primaryColor: _parseColor(m['primaryColor'], _current.primaryColor),
        secondaryColor: _parseColor(m['secondaryColor'], _current.secondaryColor),
        accentColor: _parseColor(m['accentColor'], _current.accentColor),
        logoAssetPath: m['logoAssetPath'] ?? _current.logoAssetPath,
        splashAssetPath: m['splashAssetPath'] ?? _current.splashAssetPath,
        voucherPrefix: m['voucherPrefix'] ?? _fallbackPrefix(_envBrandId),
        schoolId: m['schoolId'] ?? _fallbackSchoolId(_envBrandId),
      );
    } catch (e, st) {
      // Keep the hardcoded Academia fallback -- a missing/broken
      // branding file shouldn't stop the app from starting. Still record
      // it non-fatally: a white-label build silently rendering the wrong
      // logo/colors with zero diagnostic trail is exactly the kind of
      // bug that only surfaces from a support ticket, not a crash report.
      CrashService.instance.recordError(e, st, context: 'Branding.load(brandId: $_envBrandId)');
    }
  }
}
