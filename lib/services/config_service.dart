// lib/services/config_service.dart
// Runtime configuration management via Firestore remote config.
// Provides feature flags, app-wide toggles, and environment-specific values
// without requiring an app update.
//
// Structure: Firestore collection 'app_config/{key}' documents.

import 'package:cloud_firestore/cloud_firestore.dart';
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

  final _db = FirebaseFirestore.instance;
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

  /// Fetch and cache all config values from Firestore.
  /// Call once at app start; uses cached values for the session.
  Future<void> initialize() async {
    try {
      final snap = await _db.collection('app_config').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        _cache[doc.id] = data['value'] ?? data;
      }
      debugPrint('[Config] Loaded ${_cache.length} config keys');
    } catch (e) {
      debugPrint('[Config] Using defaults — Firestore error: $e');
    }
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
      fallback: 'Ladybird Group of Schools is undergoing scheduled maintenance. Please try again shortly.');
  int get maxUploadMb => getInt(ConfigKey.maxUploadMb, fallback: 50);
  int get pageSize    => getInt(ConfigKey.paginationPageSize, fallback: 20);
  bool get aiTutorEnabled   => getBool(ConfigKey.aiTutorEnabled, fallback: true);
  bool get paymentsEnabled  => getBool(ConfigKey.paymentsEnabled);
}
