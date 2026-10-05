import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../services/app_user_cache_service.dart';

class UserProfileRepository {
  UserProfileRepository._();
  static final UserProfileRepository instance = UserProfileRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Returns a stream that emits the cached profile instantly (if any),
  /// then fetches fresh data from Supabase, updates the cache, and emits the fresh data.
  /// This avoids the overhead of a persistent Realtime subscription while keeping data fresh.
  Stream<AppUser?> watchUserProfile(String userId) async* {
    final cached = await AppUserCacheService.instance.getUser(userId);
    if (cached != null) {
      yield cached;
    }

    try {
      final row = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (row == null) {
        if (cached != null) yield null;
        return;
      }
      
      final fresh = AppUser.fromSupabase(row);
      await AppUserCacheService.instance.putUser(fresh);
      yield fresh;
    } catch (_) {
      // On network error, we just rely on the cached value we already yielded.
    }
  }

  Future<AppUser?> getUserProfile(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await AppUserCacheService.instance.getUser(userId);
      if (cached != null) return cached;
    }

    try {
      final row = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      
      final user = AppUser.fromSupabase(row);
      await AppUserCacheService.instance.putUser(user);
      return user;
    } catch (_) {
      return null;
    }
  }
}
