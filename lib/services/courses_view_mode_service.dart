// lib/services/courses_view_mode_service.dart
// Grid/list preference for the Courses browse screens (Subject/Topic/
// Course/Lesson lists) — persisted the same way ThemeProvider persists
// light/dark, but kept as a plain static service rather than a
// ChangeNotifier since nothing needs to react live to a change made on a
// different, already-pushed page; each screen just reads the current
// value when it builds.

import 'package:shared_preferences/shared_preferences.dart';

class CoursesViewModeService {
  CoursesViewModeService._();

  static const _prefsKey = 'courses_view_mode_grid';
  static bool _grid = true;
  static bool _loaded = false;

  static bool get isGrid => _grid;

  /// Loads the saved preference once per app run; safe to call from every
  /// browse screen's initState — cheap no-op after the first call.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _grid = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      // Prefs unavailable — stay on the grid default.
    }
  }

  static Future<void> setGrid(bool grid) async {
    _grid = grid;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, grid);
    } catch (_) {
      // Best-effort — the toggle already applied for this session.
    }
  }
}
