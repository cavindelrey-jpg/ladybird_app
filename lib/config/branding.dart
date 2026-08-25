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

  const Branding({
    required this.brandId,
    required this.appName,
    required this.tagline,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.logoAssetPath,
    required this.splashAssetPath,
  });

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
  /// that one frame is Ladybird too. Colors/name here are PLACEHOLDERS
  /// (no real Ladybird brand reference was supplied) -- see
  /// assets/branding/ladybird.json and docs/AUTOPILOT_LOG.md.
  static Branding _current = const Branding(
    brandId: _envBrandId,
    appName: 'Ladybird School',
    tagline: 'Growing Together, Learning Forever.',
    primaryColor: const Color(0xFFD7263D),
    secondaryColor: const Color(0xFF1A1A1A),
    accentColor: const Color(0xFFFFC93C),
    logoAssetPath: 'assets/branding/ladybird_logo.png',
    splashAssetPath: 'assets/branding/ladybird_logo.png',
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
