// lib/repositories/daily_learning_repository.dart
// Course/lesson content is static app data (see data/etymology_course.dart
// for why) -- this repository's real job is per-user PROGRESS, which is
// genuine Supabase-backed state: which lessons a user has completed per
// course, and awarding real XP through the same capped/logged ledger
// every other XP source in this app uses (XpRepository.awardXp).
//
// Supabase: public.daily_learning_progress (user_id, course_id) primary key.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local_database.dart';
import '../services/connectivity_service.dart';

import '../models/daily_learning.dart';
import "../models/daily_learning_streak.dart";
import '../models/xp_transaction.dart';
import '../data/daily_learning_courses.dart';
import '../core/result.dart';
import 'xp_repository.dart';

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

  /// Completed lesson ids for [userId] in [courseId] -- empty set for a
  /// brand-new learner, never an error state.
  Stream<(Set<String>, DateTime?)> watchProgress(String userId, String courseId) {
    if (userId.isEmpty) return Stream.value((const <String>{}, null));
    return _progress
        .stream(primaryKey: ['user_id', 'course_id'])
        .eq('user_id', userId)
        .map((rows) {
      final mine = rows.where((r) => r['course_id'] == courseId);
      if (mine.isEmpty) return (const <String>{}, null);
      final completed = Set<String>.from(mine.first['completed_lesson_ids'] ?? const []);
      final updatedStr = mine.first['updated_at'] as String?;
      DateTime? updated;
      if (updatedStr != null) updated = DateTime.tryParse(updatedStr);
      return (completed, updated);
    });
  }

  /// Records a finished lesson and awards real XP for the questions
  /// answered correctly (same rate as a standard MCQ, XpSource.
  /// dailyLearning). Idempotent on the progress side -- replaying an
  /// already-completed lesson just re-unions the same id into the set --
  /// but XP is awarded again per real row semantics (every attempt earns
  /// XP again, capped by the shared daily XP ceiling, same as quiz retakes).
  Future<int> completeLesson({
    required String userId,
    required String courseId,
    required String lessonId,
    required int correctCount,
  }) async {
    if (userId.isEmpty) return 0;
    final existing = await _progress
        .select('completed_lesson_ids')
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .maybeSingle();
    final ids = {...Set<String>.from(existing?['completed_lesson_ids'] ?? const []), lessonId}.toList();
    await _progress.upsert({
      'user_id': userId,
      'course_id': courseId,
      'completed_lesson_ids': ids,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,course_id');
    
    await _updateStreak(userId);

    if (correctCount <= 0) return 0;
    final rawAmount = correctCount * XpSource.dailyLearning.baseXp;
    final result = await XpRepository.instance.awardXp(
      userId,
      XpSource.dailyLearning,
      rawAmount,
    );
    return result is Success<int> ? result.value : 0;
  }

  Future<void> _updateStreak(String userId) async {
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
  }

  Stream<DailyLearningStreak?> watchStreak(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return _db
        .from('daily_learning_streaks')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
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
