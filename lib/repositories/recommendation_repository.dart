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
import '../models/test.dart';
import '../repositories/academic_content_repository.dart';
import '../repositories/magazine_repository.dart';
import '../repositories/public_course_repository.dart';
import '../repositories/test_repository.dart';

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

  /// production_plan.md §5's own worked example — "Mathematics + Physics
  /// → ... → frequently completes Physics quizzes" — says usage should
  /// outrank a favorite subject the user only starred and never actually
  /// engages with. Pure/stateless (no Firestore call in here — callers
  /// derive [completionCounts] separately, e.g.
  /// TestRepository.subjectCompletionCountsOnce()) so it's directly unit-
  /// testable; see test/recommendation_ranking_test.dart.
  ///
  /// Returns [favoriteSubjects] reordered by descending completion count.
  /// Subjects tied on count (most commonly: everyone at 0, i.e. no usage
  /// signal yet) keep their ORIGINAL relative order — Dart's `List.sort`
  /// is not guaranteed stable, so ties are broken explicitly by original
  /// index rather than left to chance. This is what makes "no usage data"
  /// a true no-op: with an all-zero [completionCounts] map, this returns
  /// [favoriteSubjects] unchanged.
  static List<String> rankSubjectsByUsage(
    List<String> favoriteSubjects,
    Map<String, int> completionCounts,
  ) {
    final indexed = favoriteSubjects.asMap().entries.toList()
      ..sort((a, b) {
        final byCount = (completionCounts[b.value] ?? 0)
            .compareTo(completionCounts[a.value] ?? 0);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  /// Re-sorts [items] so the subject the user completes most often
  /// (per [rankedSubjects], already usage-ranked) comes first, WITHOUT
  /// disturbing the relative order of items that share a subject — those
  /// keep whatever order the caller's pool was already in (typically
  /// recency). Implemented as an explicit index tie-break rather than
  /// relying on `List.sort`'s stability, for the same reason
  /// [rankSubjectsByUsage] does.
  static List<T> _sortBySubjectRank<T>(
    List<T> items,
    List<String> rankedSubjects,
    String Function(T) subjectOf,
  ) {
    final rankIndex = {for (var i = 0; i < rankedSubjects.length; i++) rankedSubjects[i]: i};
    final indexed = items.asMap().entries.toList()
      ..sort((a, b) {
        final byRank = (rankIndex[subjectOf(a.value)] ?? rankedSubjects.length)
            .compareTo(rankIndex[subjectOf(b.value)] ?? rankedSubjects.length);
        if (byRank != 0) return byRank;
        return a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  /// Library recommendations: favorite-subject content first (round-robin
  /// across subjects so one subject doesn't crowd out the rest), falling
  /// back to recent content site-wide for users with no favorites set yet
  /// (new/guest users still see something real, never an empty rail).
  ///
  /// [subjectUsageCounts], when supplied (TestRepository
  /// .subjectCompletionCountsOnce()), reorders which favorite subject
  /// gets the round-robin's first pick — see [rankSubjectsByUsage].
  /// Defaults to empty, which is a no-op (identical to the pre-§5-usage
  /// behavior), so every existing caller keeps working unchanged.
  Future<List<AcademicContent>> forLibrary({
    required List<String> favoriteSubjects,
    Map<String, int> subjectUsageCounts = const {},
    String? institutionId,
    int limit = 8,
  }) async {
    final repo = AcademicContentRepository.instance;
    if (favoriteSubjects.isNotEmpty) {
      final rankedSubjects = rankSubjectsByUsage(favoriteSubjects, subjectUsageCounts);
      final results = <AcademicContent>[];
      final seenIds = <String>{};
      // Round-robin one pass per subject rather than draining the first
      // subject's whole quota first, so a student with 3 favorites sees
      // a mix, not just their first pick. Subject ORDER here is the
      // usage-ranked order, so the subject actually completed most often
      // gets the earliest picks in each round.
      final perSubject = await Future.wait(rankedSubjects.map((s) => repo
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
  ///
  /// [subjectUsageCounts] (optional, see [forLibrary]'s matching doc)
  /// re-sorts the matched courses so ones in a subject the user actually
  /// completes quizzes in surface before ones in a subject they merely
  /// starred — recency within a subject is preserved either way.
  Future<List<PublicCourse>> forCourses({
    required List<String> favoriteSubjects,
    Map<String, int> subjectUsageCounts = const {},
    int limit = 8,
  }) async {
    final repo = PublicCourseRepository.instance;
    final pool = await repo.watchLatest(limit: 60).first
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
    if (favoriteSubjects.isNotEmpty) {
      final favSet = favoriteSubjects.toSet();
      final rankedSubjects = rankSubjectsByUsage(favoriteSubjects, subjectUsageCounts);
      final matched = pool.where((c) => favSet.contains(c.subject)).toList();
      final ranked = _sortBySubjectRank(matched, rankedSubjects, (c) => c.subject);
      final result = ranked.take(limit).toList();
      if (result.isNotEmpty) return result;
    }
    return pool.take(limit).toList();
  }

  /// Quiz recommendations: same favorite-subject-first, usage-weighted,
  /// recent-fallback shape as [forCourses]. `tests` has a real per-
  /// subject query (TestRepository.watchTestsBySubject), but subscribing
  /// to one live stream per favorite subject just for a bounded
  /// recommendation rail is disproportionate — reuses the same "one
  /// bounded recent pool, filter+rank client-side" shape [forCourses]
  /// already uses for exactly that reason.
  ///
  /// [institutionId] mirrors TestRepository.watchTestsBySubject's own
  /// visibility rule: a test with a null institutionId is open to every
  /// student studying the subject; one with an institutionId is only
  /// shown to that school's own students.
  Future<List<Test>> forQuizzes({
    required List<String> favoriteSubjects,
    Map<String, int> subjectUsageCounts = const {},
    String? institutionId,
    int limit = 8,
  }) async {
    final pool = await TestRepository.instance.recentPublishedOnce(limit: 60);
    final visible = pool
        .where((t) => t.institutionId == null || t.institutionId == institutionId)
        .toList();
    if (favoriteSubjects.isNotEmpty) {
      final favSet = favoriteSubjects.toSet();
      final rankedSubjects = rankSubjectsByUsage(favoriteSubjects, subjectUsageCounts);
      final matched = visible.where((t) => favSet.contains(t.subject)).toList();
      final ranked = _sortBySubjectRank(matched, rankedSubjects, (t) => t.subject);
      final result = ranked.take(limit).toList();
      if (result.isNotEmpty) return result;
    }
    return visible.take(limit).toList();
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
}
