// lib/services/config_service.dart
// Runtime configuration management. No Postgres table exists for
// app_config yet — it had zero real Firestore documents at migration
// time, so every session was already running purely on _defaults below
// in practice. initialize()/refresh() are now no-ops rather than
// pointing at a table that doesn't exist; add a real `app_config` table
// and wire these back up if remote-configurable values are ever needed.

import 'package:flutter/foundation.dart';

/// Well-known configuration keys. Never use raw strings in feature code.
class ConfigKey {
  ConfigKey._();

  // Feature availability overrides
  static const String aiTutorEnabled      = 'ai_tutor_enabled';
  static const String chatEnabled         = 'chat_enabled';
  static const String paymentsEnabled     = 'payments_enabled';

  // Content limits
  static const String maxUploadMb         = 'max_upload_mb';
  static const String maxLibraryItemsFree = 'max_library_items_free';

  // Behaviour tuning
  static const String searchDebounceMs    = 'search_debounce_ms';
  static const String paginationPageSize  = 'pagination_page_size';

  // Maintenance
  static const String maintenanceMode     = 'maintenance_mode';
  static const String maintenanceMessage  = 'maintenance_message';

  // Pricing (displayed in-app, not authoritative for billing)
  static const String basicMonthlyFcfa    = 'basic_monthly_fcfa';
  static const String proMonthlyFcfa      = 'pro_monthly_fcfa';
}

class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  final Map<String, dynamic> _cache = {};

  // ── Default values (app works offline or before Firestore responds) ──────
  static const Map<String, dynamic> _defaults = {
    ConfigKey.aiTutorEnabled:      true,
    ConfigKey.chatEnabled:         false,
    ConfigKey.paymentsEnabled:     false,
    ConfigKey.maxUploadMb:         50,
    ConfigKey.maxLibraryItemsFree: 20,
    ConfigKey.searchDebounceMs:    300,
    ConfigKey.paginationPageSize:  20,
    ConfigKey.maintenanceMode:     false,
    ConfigKey.maintenanceMessage:  '',
    ConfigKey.basicMonthlyFcfa:    5000,
    ConfigKey.proMonthlyFcfa:      15000,
  };

  /// No-op — see file header. Kept as a method (rather than removed) so
  /// main.dart's call site doesn't need to change.
  Future<void> initialize() async {
    debugPrint('[Config] No app_config table yet — using defaults');
  }

  /// Get a typed bool config value.
  bool getBool(String key, {bool? fallback}) =>
      (_cache[key] ?? _defaults[key] ?? fallback ?? false) as bool;

  /// Get a typed int config value.
  int getInt(String key, {int? fallback}) =>
      ((_cache[key] ?? _defaults[key] ?? fallback ?? 0) as num).toInt();

  /// Get a typed String config value.
  String getString(String key, {String fallback = ''}) =>
      (_cache[key] ?? _defaults[key] ?? fallback).toString();

  /// Force-refresh from Firestore (e.g. after admin changes a value).
  Future<void> refresh() async {
    _cache.clear();
    await initialize();
  }

  bool get isMaintenanceMode => getBool(ConfigKey.maintenanceMode);
  String get maintenanceMessage => getString(ConfigKey.maintenanceMessage,
      fallback: 'CFPMI is undergoing scheduled maintenance. Please try again shortly.');
  int get maxUploadMb => getInt(ConfigKey.maxUploadMb, fallback: 50);
  int get pageSize    => getInt(ConfigKey.paginationPageSize, fallback: 20);
  bool get aiTutorEnabled   => getBool(ConfigKey.aiTutorEnabled, fallback: true);
  bool get paymentsEnabled  => getBool(ConfigKey.paymentsEnabled);
}
