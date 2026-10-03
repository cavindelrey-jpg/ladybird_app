// lib/repositories/leaderboard_repository.dart
// Spec item 12: school-scoped + global Academia XP leaderboards, backed
// by get_school_leaderboard()/get_global_leaderboard() (see
// supabase/migrations/20260904000007_xp_leaderboards.sql) -- both
// SECURITY DEFINER RPCs, not a raw `.from('users')` read, since
// public.users' own RLS isn't defined in this repo and a narrow RPC
// returning only (id, name, photo, xp, rank) is the safer, least-
// privilege choice regardless (mirrors ParentLinkRepository's
// get_linked_students() reasoning).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/core.dart';

class LeaderboardEntry {
  final String userId;
  final String name;
  final String? photoUrl;
  final int lifetimeXp;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.lifetimeXp,
    required this.rank,
  });

  factory LeaderboardEntry.fromSupabase(Map<String, dynamic> d) => LeaderboardEntry(
        userId: d['user_id']?.toString() ?? '',
        name: d['name']?.toString() ?? 'Student',
        photoUrl: d['photo_url']?.toString(),
        lifetimeXp: (d['lifetime_xp'] as num?)?.toInt() ?? 0,
        rank: (d['rank'] as num?)?.toInt() ?? 0,
      );
}

class LeaderboardRepository {
  LeaderboardRepository._();
  static final LeaderboardRepository instance = LeaderboardRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  final _memoizer = Memoizer();

  Future<List<LeaderboardEntry>> getSchoolLeaderboard(String schoolId, {int limit = 50}) async {
    if (schoolId.isEmpty) return const [];
    return _memoizer.runOnce('getSchoolLeaderboard_${schoolId}_$limit', () async {
      final rows = await _db.rpc('get_school_leaderboard', params: {
        'p_school_id': schoolId, 'p_limit': limit,
      }) as List;
      return rows.map((r) => LeaderboardEntry.fromSupabase(Map<String, dynamic>.from(r as Map))).toList();
    });
  }

  Future<List<LeaderboardEntry>> getGlobalLeaderboard({int limit = 50}) async {
    return _memoizer.runOnce('getGlobalLeaderboard_$limit', () async {
      final rows = await _db.rpc('get_global_leaderboard', params: {'p_limit': limit}) as List;
      return rows.map((r) => LeaderboardEntry.fromSupabase(Map<String, dynamic>.from(r as Map))).toList();
    });
  }
}
