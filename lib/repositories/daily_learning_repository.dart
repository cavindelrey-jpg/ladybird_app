// lib/repositories/daily_learning_repository.dart
// Course/lesson content is static app data (see data/etymology_course.dart
// for why) -- this repository's real job is per-user PROGRESS, which is
// genuine Firestore-backed state: which lessons a user has completed per
// course, and awarding real XP through the same capped/logged ledger
// every other XP source in this app uses (XpRepository.awardXp).
//
// Firestore: users/{uid}/dailyLearningProgress/{courseId}
//   { completedLessonIds: [String], updatedAt: Timestamp }

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';
import '../models/daily_learning.dart';
import '../models/xp_transaction.dart';
import '../data/etymology_course.dart';
import 'xp_repository.dart';

class DailyLearningRepository {
  DailyLearningRepository._();
  static final DailyLearningRepository instance = DailyLearningRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Every Daily Learning course -- currently just Etymology. Static, so
  /// no loading/error state needed at the call site.
  List<DailyLearningCourse> get courses => dailyLearningCourses;

  DailyLearningCourse? courseById(String id) {
    for (final c in dailyLearningCourses) {
      if (c.id == id) return c;
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>> _progressDoc(String userId, String courseId) => _db
      .collection(AppConstants.colUsers)
      .doc(userId)
      .collection('dailyLearningProgress')
      .doc(courseId);

  /// Completed lesson ids for [userId] in [courseId] -- empty set for a
  /// brand-new learner, never an error state (an honest "nothing done
  /// yet" rather than blocking the course page on a permission edge case).
  Stream<Set<String>> watchProgress(String userId, String courseId) {
    if (userId.isEmpty) return Stream.value(const <String>{});
    return _progressDoc(userId, courseId).snapshots().map((doc) {
      final ids = doc.data()?['completedLessonIds'] as List<dynamic>?;
      return ids?.map((e) => e.toString()).toSet() ?? const <String>{};
    });
  }

  /// Records a finished lesson and awards real XP for the questions
  /// answered correctly (same rate as a standard MCQ, XpSource.
  /// dailyLearning). Idempotent on the progress side -- replaying an
  /// already-completed lesson just re-unions the same id into the set --
  /// but XP is awarded again per real doc semantics (no "onlyOnce" here
  /// yet, matching how e.g. quiz retakes already work in this app: every
  /// attempt earns XP again, capped by the shared daily XP ceiling).
  Future<int> completeLesson({
    required String userId,
    required String courseId,
    required String lessonId,
    required int correctCount,
  }) async {
    if (userId.isEmpty) return 0;
    await _progressDoc(userId, courseId).set({
      'completedLessonIds': FieldValue.arrayUnion([lessonId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (correctCount <= 0) return 0;
    final rawAmount = correctCount * XpSource.dailyLearning.baseXp;
    final result = await XpRepository.instance.awardXp(
      userId,
      XpSource.dailyLearning,
      rawAmount,
      refId: '$courseId:$lessonId',
    );
    return result is Success<int> ? result.value : 0;
  }
}
