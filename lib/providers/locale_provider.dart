// lib/providers/locale_provider.dart
// Global ChangeNotifier for app language preference:
// System Default (null -> follows device/system language), English ('en'), or French ('fr').
// Persisted in SharedPreferences under 'app_language'.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { system, english, french }

class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_language';

  AppLanguage _language = AppLanguage.system;
  AppLanguage get language => _language;

  Locale? get locale => switch (_language) {
    AppLanguage.system => null, // null follows system/device locale
    AppLanguage.english => const Locale('en'),
    AppLanguage.french => const Locale('fr'),
  };

  String get languageCode => switch (_language) {
    AppLanguage.system => 'system',
    AppLanguage.english => 'en',
    AppLanguage.french => 'fr',
  };

  Future<void> restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'en' || saved == 'english') {
        _language = AppLanguage.english;
      } else if (saved == 'fr' || saved == 'french') {
        _language = AppLanguage.french;
      } else {
        _language = AppLanguage.system;
      }
      notifyListeners();
    } catch (_) {
      // Prefs unavailable — stay on system default.
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _language.name);
    } catch (_) {
      // Best-effort
    }
  }
}
