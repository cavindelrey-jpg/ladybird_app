// lib/repositories/streak_repository.dart
// Real daily-activity streak — did NOT exist anywhere in the codebase
// before this (only a code comment mentioned it as a future idea). Each
// active calendar day is its own doc at users/{userId}/activityDays/{
// yyyy-MM-dd} (doc existence == active that day), so both "how many
// consecutive days" and "which of Mon-Sun this week" are computed from
// the same real records — never a fabricated number.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class StreakRepository {
  StreakRepository._();
  static final StreakRepository instance = StreakRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _days(String userId) => _db
      .collection(AppConstants.colUsers)
      .doc(userId)
      .collection(AppConstants.colActivityDays);

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Marks today as an active day for [userId]. Safe to call every time
  /// Home loads — the deterministic yyyy-MM-dd doc id makes this a no-op
  /// write (same doc, merge) rather than creating duplicate records.
  /// Best-effort: a failed streak write should never block app usage.
  Future<void> recordActiveToday(String userId) async {
    try {
      await _days(userId).doc(_dayKey(DateTime.now())).set({
        'date': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort
    }
  }

  /// Real consecutive-day streak (ending today or yesterday — a user who
  /// hasn't opened the app yet today still has yesterday's streak intact
  /// until the day fully lapses) plus which of this week's Mon-Sun days
  /// were active, computed from one bounded read.
  Future<({int streak, List<bool> week})> loadSummary(String userId) async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 60));
    final snap = await _days(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get()
        .timeout(const Duration(seconds: 10));
    final activeKeys = snap.docs.map((d) => d.id).toSet();

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
