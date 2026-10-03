// lib/repositories/streak_repository.dart
// Real daily-activity streak. Each active calendar day is its own row in
// activity_days (user_id, day) — day's presence == active that day, same
// "never a fabricated number" guarantee the Firestore doc-per-day design had.

import 'package:supabase_flutter/supabase_flutter.dart';


class StreakRepository {
  StreakRepository._();
  static final StreakRepository instance = StreakRepository._();

  final SupabaseClient _db = Supabase.instance.client;

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Marks today as an active day for [userId]. Safe to call every time
  /// Home loads — upsert on the (user_id, day) primary key makes this a
  /// no-op on repeat calls the same day. Best-effort: a failed streak
  /// write should never block app usage.
  Future<void> recordActiveToday(String userId) async {
    try {
      await _db.from('activity_days').upsert({
        'user_id': userId, 'day': _dayKey(DateTime.now()),
      }, onConflict: 'user_id,day').timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort
    }
  }

  /// Real consecutive-day streak (ending today or yesterday) plus which
  /// of this week's Mon-Sun days were active, computed from one bounded
  /// read.
  Future<({int streak, List<bool> week})> loadSummary(String userId) async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 60));
    final rows = await _db
        .from('activity_days')
        .select('day')
        .eq('user_id', userId)
        .gte('day', _dayKey(since))
        .timeout(const Duration(seconds: 10));
    final activeKeys = rows.map((r) => r['day'] as String).toSet();

    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    if (!activeKeys.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (activeKeys.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final week = List.generate(
        7, (i) => activeKeys.contains(_dayKey(monday.add(Duration(days: i)))));

    return (streak: streak, week: week);
  }
}
