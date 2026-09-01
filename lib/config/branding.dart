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
  });

  static String _fallbackPrefix(String brandId) {
    switch (brandId) {
      case 'green_hill': return 'GH';
      case 'ladybird':   return 'LB';
      case 'academia':   return 'AC';
      default:           return brandId.toUpperCase();
    }
  }

  // This repo is the Ladybird fork of the Green Hills app (see
  // docs/AUTOPILOT_LOG.md for the fork record) -- it ships as Ladybird
  // only, same reasoning the Green Hills repo already used for defaulting
  // to its own brand: "just run it" (a plain `flutter run`, an IDE launch
  // config, a CI step someone forgets to flag) should render Ladybird,
  // not fall through to Academia's or Green Hills' identity.
  static const String _envBrandId =
      String.fromEnvironment('BRAND_ID', defaultValue: 'ladybird');

  /// Hardcoded fallback so every screen has *something* to read even if
  /// asset loading hasn't completed yet (or fails) -- matches this
  /// codebase's existing "never a blank/broken screen" standard. main()
  /// awaits [load] before runApp, so in practice this is only ever seen
  /// for one frame at worst. Mirrors assets/branding/ladybird.json so
  /// that one frame is Ladybird too. Name/tagline are exact (from
  /// mockups/mockup1.jpg's home-screen header and mockups/mockup2.jpg's
  /// logo); colors are eyeballed from those two images -- no colorpicker
  /// tool available in this sandbox -- close but not pixel-exact. See
  /// docs/AUTOPILOT_LOG.md.
  static Branding _current = const Branding(
    brandId: _envBrandId,
    appName: 'Ladybird Group of Schools',
    tagline: 'High Moral Standards, Academic Excellence',
    primaryColor: const Color(0xFF1E6FEB),
    secondaryColor: const Color(0xFF0B1F4D),
    accentColor: const Color(0xFFF4B400),
    logoAssetPath: 'assets/branding/ladybird_logo.jpg',
    splashAssetPath: 'assets/branding/ladybird_logo.jpg',
    voucherPrefix: 'LB',
  );

  static Branding get current => _current;

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
