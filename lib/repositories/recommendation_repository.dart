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

import '../models/app_user.dart';
import '../models/club.dart';
import '../models/magazine_article.dart';
import '../models/public_course.dart';
import '../models/test.dart';
import '../core/club_scope.dart';
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

  /// Bridges a favorite subject (`kAcademicSubjects`) to a `Club.category`
  /// (`_kClubCategories` in create_club_page.dart/club_settings_page.dart:
  /// General/Academic/Debate/Sports/Arts/Tech/Language/Volunteering) — same
  /// "two vocabularies for the same idea" problem [_subjectToArticleCategories]
  /// solves for Magazine. Deliberately coarse: several subjects legitimately
  /// share 'Academic', and a subject with no defensible pairing (Business,
  /// Other) is left unmapped rather than guessed at.
  static const Map<String, String> _subjectToClubCategory = {
    'Mathematics':       'Academic',
    'Science':           'Academic',
    'Social Studies':    'Academic',
    'Computer Science':  'Tech',
    'Languages':         'Language',
    'Arts & Literature': 'Arts',
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
  /// [educationLevel] is a real, optional secondary signal (§7B's
  /// "Academic level") — when it maps to a known [AcademicContent.level]
  /// via [_educationLevelToContentLevel], results are additionally scoped
  /// to that level. Cheap to support here because `AcademicContentRepository
  /// .watch()` already takes a `level` param for exactly this filtering.
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
    String? educationLevel,
    int limit = 8,
  }) async {
    final repo = AcademicContentRepository.instance;
    final mappedLevel = _educationLevelToContentLevel[educationLevel];
    if (favoriteSubjects.isNotEmpty) {
      final rankedSubjects = rankSubjectsByUsage(favoriteSubjects, subjectUsageCounts);
      final results = <AcademicContent>[];
      final seenIds = <String>{};
      // Round-robin one pass per subject rather than draining the first
      // subject's whole quota first, so a student with 3 favorites sees
      // a mix, not just their first pick. Subject ORDER here is the
      // usage-ranked order, so the subject actually completed most often
      // gets the earliest picks in each round. [mappedLevel] additionally
      // scopes every subject's query to the student's own academic level
      // when known.
      final perSubject = await Future.wait(rankedSubjects.map((s) => repo
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

  /// Clubs recommendations: production_plan.md §7B's "contextual
  /// recommendations should exist throughout Academia," replacing the
  /// removed Clubs banner. Unlike every other `forX` method here, this is
  /// synchronous and takes an already-fetched [pool] rather than issuing
  /// its own Firestore read -- ClubsPage already holds the full,
  /// school-scoped club list live via its own `watchClubs` stream, and
  /// clubs is a small enough collection per school that a second read
  /// would be pure duplication, not a new signal. Matched via
  /// [_subjectToClubCategory]; a favorite subject with no mapping
  /// contributes nothing, same "no signal, no match" rule as every other
  /// bridge map in this file. Returns an empty list (never the whole
  /// pool) when nothing matches -- the caller hides the section entirely
  /// rather than fall back to a generic list, since [pool] is already
  /// fully visible to the user one scroll away in Discover Clubs.
  List<Club> forClubs({
    required List<Club> pool,
    required List<String> favoriteSubjects,
    AppUser? user,
    int limit = 6,
  }) {
    final scopedPool = pool.where((c) => ClubScope.canAccessClub(c, user: user)).toList();
    final wanted = <String>{
      for (final s in favoriteSubjects)
        if (_subjectToClubCategory[s] != null) _subjectToClubCategory[s]!,
    };
    if (wanted.isEmpty) return const [];
    return scopedPool.where((c) => wanted.contains(c.category)).take(limit).toList();
  }
}
