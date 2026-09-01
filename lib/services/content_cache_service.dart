// lib/services/content_cache_service.dart
// Generic list-cache-aside helper, same pattern/reasoning as
// message_cache_service.dart and app_user_cache_service.dart: paint the
// last-known JSON list instantly from disk, and — critically — keep
// showing it if a live connection can't be established (offline, flaky
// reconnect) instead of the screen going blank. Repository-agnostic:
// any repository whose rows are plain JSON maps can use this directly
// instead of hand-rolling its own SharedPreferences read/write.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ContentCacheService {
  ContentCacheService._();
  static final ContentCacheService instance = ContentCacheService._();

  static const _prefix = 'content_cache_';

  /// In-session mirror so repeated reads within one app run don't hit
  /// disk-backed storage every time.
  final Map<String, List<Map<String, dynamic>>> _memory = {};

  Future<List<Map<String, dynamic>>?> getList(String key) async {
    final mem = _memory[key];
    if (mem != null) return mem;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null || raw.isEmpty) return null;
      final list = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _memory[key] = list;
      return list;
    } catch (_) {
      // A corrupt/unreadable cache entry should never block the UI --
      // the live fetch is the source of truth either way.
      return null;
    }
  }

  Future<void> putList(String key, List<Map<String, dynamic>> rows) async {
    _memory[key] = rows;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(rows));
    } catch (_) {
      // Best-effort -- worst case next cold start has nothing to paint
      // until the live fetch/stream succeeds.
    }
  }
}
