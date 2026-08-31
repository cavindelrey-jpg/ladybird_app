// lib/repositories/daily_learning_repository.dart
// Course/lesson content is static app data (see data/etymology_course.dart
// for why) -- this repository's real job is per-user PROGRESS, which is
// genuine Supabase-backed state: which lessons a user has completed per
// course, and awarding real XP through the same capped/logged ledger
// every other XP source in this app uses (XpRepository.awardXp).
//
// Supabase: public.daily_learning_progress (user_id, course_id) primary key.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_learning.dart';
import '../models/xp_transaction.dart';
import '../data/etymology_course.dart';
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
  Stream<Set<String>> watchProgress(String userId, String courseId) {
    if (userId.isEmpty) return Stream.value(const <String>{});
    return _progress
        .stream(primaryKey: ['user_id', 'course_id'])
        .eq('user_id', userId)
        .map((rows) {
      final mine = rows.where((r) => r['course_id'] == courseId);
      if (mine.isEmpty) return const <String>{};
      return Set<String>.from(mine.first['completed_lesson_ids'] ?? const []);
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

    if (correctCount <= 0) return 0;
    final rawAmount = correctCount * XpSource.dailyLearning.baseXp;
    // refId is a uuid column (test_attempts.id for quiz sources) --
    // course/lesson ids here are plain strings, not uuids, so this earn
    // isn't tied to a ref row. The ledger's `source` (dailyLearning) is
    // enough to identify where the XP came from.
    final result = await XpRepository.instance.awardXp(
      userId,
      XpSource.dailyLearning,
      rawAmount,
    );
    return result is Success<int> ? result.value : 0;
  }
}
