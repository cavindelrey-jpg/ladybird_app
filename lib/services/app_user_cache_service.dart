// lib/services/app_user_cache_service.dart
// Local cache-aside layer for the signed-in AppUser row, same pattern
// and reasoning as message_cache_service.dart: paint the last-known
// profile instantly from disk on cold start, and — critically — keep
// showing it if a live connection can't be established (offline, flaky
// reconnect) instead of the app having nothing to show. This is what
// makes AuthService.currentAppUserStream() safe to use as the gate
// between the sign-out and signed-in screens without a network hiccup
// being misread as "this account doesn't exist."

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

class AppUserCacheService {
  AppUserCacheService._();
  static final AppUserCacheService instance = AppUserCacheService._();

  static const _prefix = 'app_user_cache_';

  /// In-session mirror so repeated reads within one app run don't hit
  /// disk-backed storage every time.
  final Map<String, AppUser> _memory = {};

  /// Synchronous in-memory lookup for instant paints and initialData.
  AppUser? getCachedInMemory(String userId) => _memory[userId];

  Future<AppUser?> getUser(String userId) async {
    final mem = _memory[userId];
    if (mem != null) return mem;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$userId');
      if (raw == null || raw.isEmpty) return null;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final user = AppUser.fromSupabase(map);
      _memory[userId] = user;
      return user;
    } catch (_) {
      // A corrupt/unreadable cache entry should never block sign-in --
      // the live fetch is the source of truth either way.
      return null;
    }
  }

  Future<void> putUser(AppUser user) async {
    _memory[user.id] = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {'id': user.id, ...user.toSupabase()};
      await prefs.setString('$_prefix${user.id}', jsonEncode(map));
    } catch (_) {
      // Best-effort -- worst case, next cold start has nothing to paint
      // until the live fetch/stream succeeds.
    }
  }

  /// Called from AuthService.signOut() so the next person to use the
  /// device doesn't briefly see the previous account's cached profile.
  Future<void> clear(String userId) async {
    _memory.remove(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$userId');
    } catch (_) {
      // Best-effort, see putUser.
    }
  }
}
