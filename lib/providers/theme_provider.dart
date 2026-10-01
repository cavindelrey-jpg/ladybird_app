// lib/providers/theme_provider.dart
// Global ChangeNotifier for light/dark/system theme mode. Persists the
// user's choice the same way InstitutionProvider persists its state.
//
// Usage:
//   context.read<ThemeProvider>().toggle()
//   context.watch<ThemeProvider>().mode

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  Future<void> restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'dark') {
        _mode = ThemeMode.dark;
      } else if (saved == 'system') {
        _mode = ThemeMode.system;
      } else {
        _mode = ThemeMode.light;
      }
      notifyListeners();
    } catch (_) {
      // Prefs unavailable — stay on the light-mode default.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Best-effort — the toggle already applied for this session.
    }
  }

  Future<void> toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);
}
