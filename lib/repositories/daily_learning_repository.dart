// lib/repositories/daily_learning_repository.dart
// Course/lesson content is static app data (see data/etymology_course.dart
// for why) -- this repository's real job is per-user PROGRESS, which is
// genuine Supabase-backed state: which lessons a user has completed per
// course, and awarding real XP through the same capped/logged ledger
// every other XP source in this app uses (XpRepository.awardXp).
//
// Supabase: public.daily_learning_progress (user_id, course_id) primary key.

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_learning.dart';
import "../models/daily_learning_streak.dart";
import '../models/xp_transaction.dart';
import '../data/daily_learning_courses.dart';
import '../core/result.dart';
import 'xp_repository.dart';
import '../core/realtime_tolerant.dart';

class DailyLearningRepository {
  DailyLearningRepository._();
  static final DailyLearningRepository instance = DailyLearningRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _progress => _db.from('daily_learning_progress');

  /// Every Daily Learning course -- currently just Etymology. Static, so
  /// no loading/error state needed at the call site.
  List<DailyLearningCourse> get courses => dailyLearningCourses;

  DailyLearningCourse? courseById(String id) {
    for (final c in dailyLearningCourses) {
      if (c.id == id) return c;
    }
    return null;
  }

  final StreamController<void> _localNotifier = StreamController<void>.broadcast();

  static String _localProgressKey(String userId, String courseId) =>
      'local_daily_learning_progress_${userId}_$courseId';

  /// Completed lesson ids for [userId] in [courseId] -- empty set for a
  /// brand-new learner, never an error state. Integrates local device cache
  /// so lessons immediately show as completed even if offline or before sync.
  Stream<(Set<String>, DateTime?)> watchProgress(String userId, String courseId) async* {
    if (userId.isEmpty) {
      yield (const <String>{}, null);
      return;
    }

    Future<(Set<String>, DateTime?)> readLocal() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_localProgressKey(userId, courseId));
        if (raw != null && raw.isNotEmpty) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final ids = Set<String>.from(data['ids'] ?? const []);
          final updated = data['updated_at'] != null ? DateTime.tryParse(data['updated_at'] as String) : null;
          return (ids, updated);
        }
      } catch (_) {}
      return (const <String>{}, null);
    }

    // Yield local cache first for instant UI response
    var current = await readLocal();
    yield current;

    final remoteStream = _progress
        .stream(primaryKey: ['user_id', 'course_id'])
        .eq('user_id', userId)
        .realtimeTolerant()
        .map((rows) {
      final mine = rows.where((r) => r['course_id'] == courseId);
      if (mine.isEmpty) return current;
      final completed = Set<String>.from(mine.first['completed_lesson_ids'] ?? const []);
      final updatedStr = mine.first['updated_at'] as String?;
      DateTime? updated;
      if (updatedStr != null) updated = DateTime.tryParse(updatedStr);
      // Merge local with remote
      final merged = {...current.$1, ...completed};
      return (merged, updated ?? current.$2);
    });

    yield* remoteStream;
  }

  /// Records a finished lesson and awards real XP for the questions
  /// answered correctly. Never hangs or throws: immediately writes to
  /// local device storage so progress is saved instantly, then syncs with
  /// Supabase and awards XP with bounded timeouts.
  Future<int?> completeLesson({
    required String userId,
    required String courseId,
    required String lessonId,
    required int correctCount,
  }) async {
    if (userId.isEmpty) return 0;

    // 1. Immediately persist to local device cache
    Set<String> allCompleted = {lessonId};
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localProgressKey(userId, courseId);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        allCompleted = {...Set<String>.from(data['ids'] ?? const []), lessonId};
      }
      await prefs.setString(key, jsonEncode({
        'ids': allCompleted.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }));
      _localNotifier.add(null);
    } catch (e) {
      // Local storage failed non-fatally
    }

    // 2. Fetch remote existing to verify if this is a replay for XP
    bool wasAlreadyDoneRemotely = false;
    try {
      final existing = await _progress
          .select('completed_lesson_ids')
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      final done = Set<String>.from(existing?['completed_lesson_ids'] ?? const []);
      wasAlreadyDoneRemotely = done.contains(lessonId);
      allCompleted = {...done, ...allCompleted};
    } catch (_) {
      // Offline fallback: rely on local state
    }

    if (wasAlreadyDoneRemotely) {
      return null; // Practice round
    }

    // 3. Upsert to Supabase with timeout
    try {
      await _progress.upsert({
        'user_id': userId,
        'course_id': courseId,
        'completed_lesson_ids': allCompleted.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,course_id').timeout(const Duration(seconds: 5));
    } catch (e) {
      // Supabase write failed or timed out; will sync on next reconnect
    }

    // 4. Update daily streak safely with try/catch and timeout
    try {
      await _updateStreak(userId).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // 5. Award XP safely
    if (correctCount <= 0) return 0;
    final rawAmount = correctCount * XpSource.dailyLearning.baseXp;
    try {
      final result = await XpRepository.instance.awardXp(
        userId,
        XpSource.dailyLearning,
        rawAmount,
      ).timeout(const Duration(seconds: 4));
      return result is Success<int> ? result.value : rawAmount;
    } catch (_) {
      return rawAmount;
    }
  }

  Future<void> _updateStreak(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final row = await _db.from('daily_learning_streaks').select().eq('user_id', userId).maybeSingle();
      
      int current = 0;
      int longest = 0;
      DateTime? lastDate;
      
      if (row != null) {
        current = (row['current_streak'] as num?)?.toInt() ?? 0;
        longest = (row['longest_streak'] as num?)?.toInt() ?? 0;
        final dateStr = row['last_completed_date'] as String?;
        if (dateStr != null) lastDate = DateTime.tryParse(dateStr);
      }
      
      if (lastDate != null && lastDate.year == today.year && lastDate.month == today.month && lastDate.day == today.day) {
        return; // Already completed today
      }
      
      if (lastDate != null && today.difference(lastDate).inDays == 1) {
        current += 1;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      
      await _db.from('daily_learning_streaks').upsert({
        'user_id': userId,
        'current_streak': current,
        'longest_streak': longest,
        'last_completed_date': "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}",
      });
    } catch (_) {}
  }

  Stream<DailyLearningStreak?> watchStreak(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return _db
        .from('daily_learning_streaks')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .realtimeTolerant()
        .map((rows) {
      if (rows.isEmpty) return DailyLearningStreak(userId: userId, currentStreak: 0, longestStreak: 0);
      final streak = DailyLearningStreak.fromSupabase(rows.first);
      // If they missed yesterday, show current streak as 0 in UI immediately
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (streak.lastCompletedDate != null && today.difference(streak.lastCompletedDate!).inDays > 1) {
        return DailyLearningStreak(
          userId: userId, 
          currentStreak: 0, 
          longestStreak: streak.longestStreak, 
          lastCompletedDate: streak.lastCompletedDate
        );
      }
      return streak;
    });
  }
}
