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
import '../models/magazine_article.dart';
import '../models/public_course.dart';
import '../repositories/academic_content_repository.dart';
import '../repositories/magazine_repository.dart';
import '../repositories/public_course_repository.dart';

class RecommendationRepository {
  RecommendationRepository._();
  static final RecommendationRepository instance = RecommendationRepository._();

  /// Magazine articles are tagged with an *editorial* category
  /// (`kArticleCategories` — Academics/Sports/Arts & Culture/Science &
  /// Tech/Opinion/Campus Life/Careers/Other), which is deliberately a
  /// different vocabulary from the *academic* subjects the rest of the
  /// personalization system speaks (`kAcademicSubjects` — Mathematics/
  /// Science/Languages/...). There is no shared key between them, so
  /// favorite-subject → article matching needs an explicit bridge; this
  /// is it.
  ///
  /// Kept deliberately coarse and conservative: only mappings that are
  /// actually defensible are listed. 'Other' is intentionally absent —
  /// it carries no signal, and mapping it to the 'Other' article
  /// category would surface unrelated posts under a "Recommended for
  /// You" label, which is exactly the kind of fake-personalization this
  /// codebase avoids elsewhere. A subject with no mapping simply
  /// contributes nothing rather than matching everything.
  static const Map<String, List<String>> _subjectToArticleCategories = {
    'Mathematics':       ['Academics'],
    'Science':           ['Science & Tech'],
    'Languages':         ['Academics'],
    'Social Studies':    ['Academics'],
    'Computer Science':  ['Science & Tech'],
    'Arts & Literature': ['Arts & Culture'],
    'Business':          ['Careers'],
  };

  /// Bridges [AppUser.educationLevel] (the free-pick Cameroon-form
  /// vocabulary in `EducationLevels.all`, app_user.dart) to
  /// [AcademicContent.level] (`kAcademicLevels`, academic_content.dart) —
  /// two different enums for the same underlying idea, same reason
  /// [_subjectToArticleCategories] exists below. Only defensible 1:1
  /// mappings are listed; 'Professional / Working Adult', 'Independent
  /// Learner' and 'Other' have no matching content level and are
  /// deliberately left unmapped rather than guessed at — same "no
  /// signal, no match" principle as the subject bridge.
  static const Map<String, String> _educationLevelToContentLevel = {
    'Form 1': 'Form 1',
    'Form 2': 'Form 2',
    'Form 3': 'Form 3',
    'Form 4': 'Form 4',
    'Form 5': 'Form 5',
    'Lower Sixth Arts': 'Lower Sixth',
    'Lower Sixth Science': 'Lower Sixth',
    'Upper Sixth Arts': 'Upper Sixth',
    'Upper Sixth Science': 'Upper Sixth',
    'University': 'Undergraduate',
  };

  /// Library recommendations: favorite-subject content first (round-robin
  /// across subjects so one subject doesn't crowd out the rest), falling
  /// back to recent content site-wide for users with no favorites set yet
  /// (new/guest users still see something real, never an empty rail).
  ///
  /// [educationLevel] is a real, optional secondary signal (§7B's
  /// "Academic level") — when it maps to a known [AcademicContent.level]
  /// via [_educationLevelToContentLevel], results are additionally scoped
  /// to that level. Cheap to support here because `AcademicContentRepository
  /// .watch()` already takes a `level` param for exactly this filtering.
  Future<List<AcademicContent>> forLibrary({
    required List<String> favoriteSubjects,
    String? institutionId,
    String? educationLevel,
    int limit = 8,
  }) async {
    final repo = AcademicContentRepository.instance;
    final mappedLevel = _educationLevelToContentLevel[educationLevel];
    if (favoriteSubjects.isNotEmpty) {
      final results = <AcademicContent>[];
      final seenIds = <String>{};
      // Round-robin one pass per subject rather than draining the first
      // subject's whole quota first, so a student with 3 favorites sees
      // a mix, not just their first pick.
      final perSubject = await Future.wait(favoriteSubjects.map((s) => repo
          .watch(institutionId: institutionId, subject: s, level: mappedLevel)
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

  /// Magazine recommendations: favorite subjects are translated to
  /// article categories via [_subjectToArticleCategories], then matched
  /// against the article's own `category` field, falling back to recent
  /// published articles when the user has no favorites, none of their
  /// favorites map to a category, or nothing in the recent pool matches.
  ///
  /// Filters a bounded recent pool client-side rather than adding a
  /// `where('category', whereIn: ...)` query, for the same reason
  /// [forCourses] does and `MagazineRepository.watchTrendingOnce()`
  /// already does: combining a category equality/`whereIn` with the
  /// existing `published` equality and `createdAt` ordering needs a new
  /// composite index, and a missing index surfaces as a silent-looking
  /// empty list (see CLAUDE.md's FAILED_PRECONDITION note). Reusing the
  /// already-indexed `watchFeed` query keeps this deployable without a
  /// firestore.indexes.json change.
  Future<List<MagazineArticle>> forMagazine({
    required List<String> favoriteSubjects,
    int limit = 6,
  }) async {
    final pool = await MagazineRepository.instance
        .watchFeed(limit: 60)
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    final wanted = <String>{
      for (final s in favoriteSubjects) ...?_subjectToArticleCategories[s],
    };
    if (wanted.isNotEmpty) {
      final matched =
          pool.where((a) => wanted.contains(a.category)).take(limit).toList();
      if (matched.isNotEmpty) return matched;
    }
    return pool.take(limit).toList();
  }

  /// Past Papers recommendations: production_plan.md §7B's "Past Papers →
  /// recommends relevant Past Papers" — the one contextual rail the spec
  /// names explicitly that didn't exist yet. Same favorite-subject-first,
  /// round-robin, recent-fallback shape as [forLibrary] (past papers ARE
  /// `AcademicContent` with `contentType == ContentType.pastPaper`, so
  /// this reuses the exact same repository/query surface, just always
  /// scoped to that one content type).
  ///
  /// [educationLevel] is real here too, and arguably more load-bearing
  /// than for [forLibrary]: a Form 3 student has little use for a Form 5
  /// GCE paper even within a favorite subject, so when the level maps via
  /// [_educationLevelToContentLevel], the fallback tier tries a
  /// level-scoped "recent" pass before falling back further to a fully
  /// generic one — an honest "recent for your level" beats a fully
  /// generic list, which itself beats nothing.
  Future<List<AcademicContent>> forPastPapers({
    required List<String> favoriteSubjects,
    String? institutionId,
    String? educationLevel,
    int limit = 8,
  }) async {
    final repo = AcademicContentRepository.instance;
    final mappedLevel = _educationLevelToContentLevel[educationLevel];
    if (favoriteSubjects.isNotEmpty) {
      final results = <AcademicContent>[];
      final seenIds = <String>{};
      final perSubject = await Future.wait(favoriteSubjects.map((s) => repo
          .watch(
            institutionId: institutionId,
            contentType: ContentType.pastPaper,
            subject: s,
            level: mappedLevel,
          )
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
    if (mappedLevel != null) {
      final levelScoped = await repo
          .watch(
            institutionId: institutionId,
            contentType: ContentType.pastPaper,
            level: mappedLevel,
          )
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => const []);
      if (levelScoped.isNotEmpty) return levelScoped.take(limit).toList();
    }
    final fallback = await repo
        .watch(institutionId: institutionId, contentType: ContentType.pastPaper)
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    return fallback.take(limit).toList();
  }
}
