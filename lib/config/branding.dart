// lib/config/branding.dart
// The *look* half of the white-label split (see app_config.dart for the
// *behavior* half). Selected via --dart-define=BRAND_ID=<id> (defaults
// to 'academia'), loaded once at startup from the matching
// assets/branding/<id>.json, and read everywhere via Branding.current.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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

  static const String _envBrandId =
      String.fromEnvironment('BRAND_ID', defaultValue: 'academia');

  /// Hardcoded fallback so every screen has *something* to read even if
  /// asset loading hasn't completed yet (or fails) -- matches this
  /// codebase's existing "never a blank/broken screen" standard. main()
  /// awaits [load] before runApp, so in practice this is only ever seen
  /// for one frame at worst.
  static Branding _current = const Branding(
    brandId: _envBrandId,
    appName: 'Academia',
    tagline: 'Your Complete Smart School Platform',
    primaryColor: const Color(0xFF1A56DB),
    secondaryColor: const Color(0xFF0A1F44),
    accentColor: const Color(0xFFC9A227),
    logoAssetPath: 'assets/icon/academia_logo_square.png',
    splashAssetPath: 'assets/icon/academia_logo_square.png',
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
    } catch (_) {
      // Keep the hardcoded Academia fallback -- a missing/broken
      // branding file shouldn't stop the app from starting.
    }
  }
}
