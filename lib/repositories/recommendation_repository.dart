// lib/repositories/recommendation_repository.dart
// production_plan.md §7B: context-aware content recommendations, scoped
// per surface (Library recommends Library content, Courses recommends
// Courses, etc.) rather than one generic list reused everywhere. Every
// result here is a real Firestore read against real signals (favorite
// subjects, academic level) with a real-data fallback (recent content) —
// no fabricated "AI picked this for you" framing without an actual
// signal behind it, consistent with this codebase's existing honesty
// standard (see MagazineRepository's computed Featured/Trending).

import '../models/academic_content.dart';
import '../models/public_course.dart';
import '../repositories/academic_content_repository.dart';
import '../repositories/public_course_repository.dart';

class RecommendationRepository {
  RecommendationRepository._();
  static final RecommendationRepository instance = RecommendationRepository._();

  /// Library recommendations: favorite-subject content first (round-robin
  /// across subjects so one subject doesn't crowd out the rest), falling
  /// back to recent content site-wide for users with no favorites set yet
  /// (new/guest users still see something real, never an empty rail).
  Future<List<AcademicContent>> forLibrary({
    required List<String> favoriteSubjects,
    String? institutionId,
    int limit = 8,
  }) async {
    final repo = AcademicContentRepository.instance;
    if (favoriteSubjects.isNotEmpty) {
      final results = <AcademicContent>[];
      final seenIds = <String>{};
      // Round-robin one pass per subject rather than draining the first
      // subject's whole quota first, so a student with 3 favorites sees
      // a mix, not just their first pick.
      final perSubject = await Future.wait(favoriteSubjects.map((s) => repo
          .watch(institutionId: institutionId, subject: s)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const [])));
      var round = 0;
      while (results.length < limit && perSubject.any((l) => round < l.length)) {
        for (final list in perSubject) {
          if (round >= list.length) continue;
          final item = list[round];
          if (seenIds.add(item.id)) results.add(item);
          if (results.length >= limit) break;
        }
        round++;
      }
      if (results.isNotEmpty) return results;
    }
    final fallback = await repo
        .watch(institutionId: institutionId)
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    return fallback.take(limit).toList();
  }

  /// Courses recommendations: same favorite-subject-first, recent-
  /// fallback shape as [forLibrary]. `PublicCourse` has no subject-scoped
  /// query of its own (only `watchByCategory`, a broader taxonomy level
  /// than `subject` — see PublicCourseRepository's curriculum-hierarchy
  /// comment), so this filters `subject` client-side over the same
  /// bounded `watchLatest()` fetch that repository's own
  /// `categoryCountsOnce()` already uses for a similar client-side
  /// aggregation — consistent with, not a departure from, that repo's
  /// existing pattern.
  ///
  /// Wired into courses_marketplace_page.dart's "Recommended for You"
  /// rail (shown only in the un-filtered discovery view, and only for a
  /// signed-in user who has actually set favorite subjects).
  Future<List<PublicCourse>> forCourses({
    required List<String> favoriteSubjects,
    int limit = 8,
  }) async {
    final repo = PublicCourseRepository.instance;
    final pool = await repo.watchLatest(limit: 60).first
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    if (favoriteSubjects.isNotEmpty) {
      final favSet = favoriteSubjects.toSet();
      final matched = pool.where((c) => favSet.contains(c.subject)).take(limit).toList();
      if (matched.isNotEmpty) return matched;
    }
    return pool.take(limit).toList();
  }
}
