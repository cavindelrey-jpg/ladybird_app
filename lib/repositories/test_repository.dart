// lib/repositories/test_repository.dart
// All reads/writes for the Testing & Quiz system: tests and test_attempts
// (shared Supabase tables — see models/test.dart and
// models/test_attempt.dart for the schema rationale).
//
// Grading framework:
//   - MCQ questions are graded the instant an attempt is submitted.
//   - Essay (longForm) questions are auto-scored at submit time against
//     the question's essential key points by core/essay_matching.dart —
//     offline, in-process, no external service. They only enter the human
//     queue when that matcher is explicitly undecided about one or more
//     key points, and the human then confirms/rejects just those points
//     rather than grading the answer from scratch.
//   - Structured questions (production_plan.md §3 Quiz Type 2) follow the
//     SAME rule when the author defined expected answer/key points
//     (TestQuestion.expectedPoints): auto-scored at submit time by the
//     identical core/essay_matching.dart matcher, with only genuinely-
//     uncertain points routed to the human queue. A Structured question
//     authored with NO expected points starts ungraded and is graded via
//     gradeResponse() — today, called by a lecturer/admin from the
//     grading queue (watchPendingGradingQueue). That single method is the
//     seam a future AI grader would call into instead of a human.
//   - XP for every graded question flows through XpRepository.awardXp
//     (capped, logged) using the rates in core/xp_rules.dart.
//
// gradeResponse() (manual-override escape hatch) runs as a plain
// read-then-write, not a formal transaction — a rare, human-paced action
// on a single specific response, same simplification academia-cameroon's
// own Supabase rewrite made for this exact method.

import 'dart:async';

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/core.dart';
import '../core/essay_matching.dart';
import '../core/result.dart';
import '../core/xp_rules.dart';
import '../models/public_course.dart' show CurriculumIcon;
import '../models/test.dart';
import '../core/content_quality.dart';
import '../models/test_attempt.dart';
import '../models/xp_transaction.dart';
import '../services/content_cache_service.dart';
import 'academic_section_repository.dart';
import 'xp_repository.dart';
import '../core/realtime_tolerant.dart';

class TestRepository {
  TestRepository._();
  static final TestRepository instance = TestRepository._();

  static const String _bucket = 'app-content';
  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _tests => _db.from('tests');
  SupabaseQueryBuilder get _attempts => _db.from('test_attempts');
  // Reuses the SAME lookup table PublicCourseRepository writes
  // Subject/Level/Topic looks into (see that file's "Curriculum node
  // icons" section) — it's a generic key->{emoji,imageUrl} store, not
  // Course-specific. The `quizSubject::`/`quizTopic::` key prefixes below
  // keep this feature's entries from ever colliding with a Course's
  // `subject::`/`level::`/`topic::` ones in the same table.
  SupabaseQueryBuilder get _nodeIcons => _db.from('curriculum_icons');

  final _memoizer = Memoizer();
  final _streamCache = StreamCache();

  // ── Reading tests ────────────────────────────────────────────────────

  /// Live list of published tests for one subject. [institutionId] null
  /// means "show only the open-to-everyone tests"; pass the student's own
  /// institutionId to ALSO include their school's restricted tests.
  /// [category]/[topic] are optional extra filters on top of [subject] —
  /// callers that pre-date the Category/Topic tiers simply don't pass
  /// them and see every test in the subject, unfiltered. Passing
  /// [kUncategorizedQuizBucket]/[kGeneralQuizTopicBucket] matches tests
  /// saved before this hierarchy existed (blank category/topic), same
  /// bucketing as [topicTestCountsOnce]/[categoryTestCountsOnce].
  Stream<List<Test>> watchTestsBySubject(String subject,
      {String? institutionId, String? category, String? topic}) {
    final key = 'watchTestsBySubject_${subject}_${institutionId}_${category}_$topic';
    return _streamCache.watch(key, () => _tests
        .stream(primaryKey: ['id'])
        .eq('subject', subject)
        .order('created_at', ascending: false)
        .realtimeTolerant()
        .map((rows) {
      // Machine-generated filler ("This is question 1", options "Option
      // A..D") is never shown to students -- see core/content_quality.dart.
      final all = rows
          .where((r) => r['published'] == true)
          .map(Test.fromSupabase)
          .where((t) => !isPlaceholderQuiz(t))
          .toList();
      return all.where((t) {
        if (t.institutionId != null && t.institutionId != institutionId) return false;
        if (category != null && category.isNotEmpty) {
          final tCat = t.category.isEmpty ? kUncategorizedQuizBucket : t.category;
          if (tCat != category) return false;
        }
        if (topic != null && topic.isNotEmpty) {
          final tTopic = t.topic.isEmpty ? kGeneralQuizTopicBucket : t.topic;
          if (tTopic != topic) return false;
        }
        return true;
      }).toList();
    }));
  }

  /// A teacher's own tests, published or not -- powers the quiz picker
  /// when assigning a quiz as homework (spec item 4B): a teacher sends an
  /// EXISTING quiz they authored, rather than authoring a new one inline
  /// from the homework form.
  Stream<List<Test>> watchTestsByCreator(String creatorId) {
    if (creatorId.isEmpty) return Stream.value(const []);
    return _streamCache.watch('watchTestsByCreator_$creatorId', () => _tests
        .stream(primaryKey: ['id'])
        .eq('created_by', creatorId)
        .order('created_at', ascending: false)
        .realtimeTolerant()
        .map((rows) => rows.map(Test.fromSupabase).toList()));
  }

  Stream<Test?> watchTest(String testId) => _streamCache.watch('watchTest_$testId', () => _tests
      .stream(primaryKey: ['id'])
      .eq('id', testId)
      .realtimeTolerant()
      .map((rows) => rows.isNotEmpty ? Test.fromSupabase(rows.first) : null));

  /// Distinct subjects that currently have at least one published test.
  /// [category] optionally scopes this to one education level; omitted
  /// keeps the old whole-catalogue behavior.
  Future<List<String>> distinctSubjectsOnce({String? category}) async {
    return _memoizer.runOnce('distinctSubjectsOnce_$category', () async {
      final rows = await _tests.select('subject,category').eq('published', true);
      final subjects = rows
          .where((r) => category == null || category.isEmpty ||
              ((r['category'] as String? ?? '').isEmpty
                  ? kUncategorizedQuizBucket
                  : r['category']) == category)
          .map((r) => (r['subject'] as String?) ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return subjects;
    });
  }

  /// Real per-subject test counts. [category] optionally scopes this to
  /// one education level (see [distinctSubjectsOnce]).
  Future<Map<String, int>> subjectTestCountsOnce({String? category}) async {
    return _memoizer.runOnce('subjectTestCountsOnce_$category', () async {
      // Full rows (not just subject,category): the count must match the
      // list the student sees, so placeholder/filler quizzes are excluded
      // via isPlaceholderQuiz -- which needs the questions column.
      final rows = await _tests.select().eq('published', true);
      final counts = <String, int>{};
      for (final row in rows) {
        if (category != null && category.isNotEmpty) {
          final rowCategory = (row['category'] as String? ?? '').isEmpty
              ? kUncategorizedQuizBucket
              : row['category'] as String;
          if (rowCategory != category) continue;
        }
        final subject = (row['subject'] as String?) ?? '';
        if (subject.isEmpty) continue;
        if (isPlaceholderQuiz(Test.fromSupabase(row))) continue;
        counts[subject] = (counts[subject] ?? 0) + 1;
      }
      return counts;
    });
  }

  static const String _categoryCountsCacheKey = 'test_category_counts';

  /// Real per-category test counts — drives the top-level Quiz page's
  /// category grid ("42 quizzes" per tile). Tests saved before the
  /// Category tier existed (blank [Test.category]) are bucketed under
  /// [kUncategorizedQuizBucket] rather than dropped.
  ///
  /// Falls back to the last cached row set on a network failure (offline,
  /// flaky reconnect) instead of throwing straight out — same reasoning
  /// as AcademicSectionRepository.sectionsOnce().
  Future<Map<String, int>> categoryTestCountsOnce() async {
    List<Map<String, dynamic>> rawRows;
    try {
      final rows = await _tests.select().eq('published', true);
      rawRows = List<Map<String, dynamic>>.from(rows);
      unawaited(ContentCacheService.instance.putList(_categoryCountsCacheKey, rawRows));
    } catch (e) {
      final cached = await ContentCacheService.instance.getList(_categoryCountsCacheKey);
      if (cached == null) rethrow;
      rawRows = cached;
    }
    final counts = <String, int>{};
    for (final row in rawRows) {
      if (isPlaceholderQuiz(Test.fromSupabase(row))) continue;
      final raw = (row['category'] as String?) ?? '';
      final category = raw.isEmpty ? kUncategorizedQuizBucket : raw;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  /// Real per-topic test counts within one category+subject — drives
  /// TestsTopicPickerPage. Blank [Test.topic] is bucketed under
  /// [kGeneralQuizTopicBucket], same honesty as [categoryTestCountsOnce].
  Future<Map<String, int>> topicTestCountsOnce({
    required String category,
    required String subject,
  }) async {
    return _memoizer.runOnce('topicTestCountsOnce_${category}_$subject', () async {
      final rows = await _tests.select().eq('subject', subject).eq('published', true);
      final counts = <String, int>{};
      for (final row in rows) {
        final rowCategory = (row['category'] as String? ?? '').isEmpty
            ? kUncategorizedQuizBucket
            : row['category'] as String;
        if (rowCategory != category) continue;
        if (isPlaceholderQuiz(Test.fromSupabase(row))) continue;
        final raw = (row['topic'] as String?) ?? '';
        final topic = raw.isEmpty ? kGeneralQuizTopicBucket : raw;
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ── Quiz categories (education-level tree top tier) ─────────────────
  // A thin Quiz-flavored wrapper around AcademicSectionRepository — the
  // same section list also drives Course Navigation and the Library.
  // Kept as delegating methods, not removed, so every existing Quiz call
  // site (QuizCategoriesPage, TestComposerPage, ...) keeps working
  // unchanged.

  Future<List<QuizCategory>> quizCategoriesOnce() =>
      AcademicSectionRepository.instance.sectionsOnce();

  /// Adds a brand-new category (the Quiz page's "+ New section", e.g.
  /// "Nursery"/"Master's"). Sorts to the end by passing the current
  /// list's length * 100 as [order].
  Future<Result<String>> addQuizCategory({
    required String name,
    required double order,
    String emoji = '',
    String imageUrl = '',
  }) =>
      AcademicSectionRepository.instance.addSection(name: name, order: order, emoji: emoji, imageUrl: imageUrl);

  /// Changes an existing category's look. Passing both empty clears it
  /// back to the letter-avatar fallback.
  Future<Result<void>> updateQuizCategoryIcon(String id, {String emoji = '', String imageUrl = ''}) =>
      AcademicSectionRepository.instance.updateSectionIcon(id, emoji: emoji, imageUrl: imageUrl);

  Future<Result<String>> uploadQuizCategoryImage({required String categoryId, required File imageFile}) =>
      AcademicSectionRepository.instance.uploadSectionImage(sectionId: categoryId, imageFile: imageFile);

  // ── Subject/Topic node icons ─────────────────────────────────────────
  // Subject/Topic aren't rows of their own — same reasoning as
  // PublicCourseRepository's identical section: they're free-text values
  // on Test rows, so a picked look lives in the shared `curriculum_icons`
  // table instead, keyed by its place in THIS tree (category-scoped, so
  // "History" under Senior Secondary and "History" under Undergraduate
  // can have different looks).

  static String quizSubjectIconKey(String category, String subject) =>
      'quizSubject::$category::$subject';
  static String quizTopicIconKey(String category, String subject, String topic) =>
      'quizTopic::$category::$subject::$topic';

  Future<Map<String, CurriculumIcon>> quizNodeIconsOnce() async {
    return _memoizer.runOnce('quizNodeIconsOnce', () async {
      final rows = await _nodeIcons.select().limit(2000);
      return {
        for (final r in rows)
          r['key'] as String: CurriculumIcon(
            emoji: r['emoji'] as String? ?? '',
            imageUrl: r['image_url'] as String? ?? '',
          ),
      };
    });
  }

  Future<void> setQuizNodeIcon(String key, {String emoji = '', String imageUrl = ''}) async {
    if (emoji.isEmpty && imageUrl.isEmpty) {
      await _nodeIcons.delete().eq('key', key);
    } else {
      await _nodeIcons.upsert({'key': key, 'emoji': emoji, 'image_url': imageUrl});
    }
    _memoizer.clear();
  }

  Future<Result<String>> uploadQuizNodeImage({
    required String key,
    required File imageFile,
  }) async {
    try {
      final docId = key.replaceAll('/', '-');
      final path = 'curriculum_icons/$docId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload image', e);
    }
  }

  /// Uploads a photo for one quiz's own tile/card (see [Test.thumbnailUrl]).
  Future<Result<String>> uploadTestThumbnail({
    required String testId,
    required File imageFile,
  }) async {
    try {
      final path = 'test_thumbnails/$testId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload thumbnail', e);
    }
  }

  /// Uploads a real photo/diagram for one question inside a test
  /// (architecture brief item 9 — [TestQuestion.imageUrl]). Keyed by
  /// both testId and questionId since a single test has many questions,
  /// unlike the one-per-test thumbnail above.
  Future<Result<String>> uploadQuestionImage({
    required String testId,
    required String questionId,
    required File imageFile,
  }) async {
    try {
      final path = 'test_question_images/${testId}_$questionId.jpg';
      await _db.storage.from(_bucket).upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
      return Success(_db.storage.from(_bucket).getPublicUrl(path));
    } catch (e) {
      return Failure('Failed to upload question image', e);
    }
  }

  /// Bounded recent-tests fetch across every subject — the fallback/pool
  /// query for RecommendationRepository.forQuizzes().
  Future<List<Test>> recentPublishedOnce({int limit = 60}) async {
    return _memoizer.runOnce('recentPublishedOnce_$limit', () async {
      final rows = await _tests.select().eq('published', true).order('created_at', ascending: false).limit(limit);
      return rows.map(Test.fromSupabase).where((t) => !isPlaceholderQuiz(t)).toList();
    });
  }

  // ── Usage signal (production_plan.md §5) ────────────────────────────
  // "Mathematics + Physics → follows Physics authors → frequently
  // completes Physics quizzes" — derived from data already recorded on
  // every attempt (TestAttempt.subject) via one bounded query.

  /// How many of [userId]'s most recent test attempts were in each
  /// subject. Bounded to [sampleSize] so this stays a single cheap query
  /// regardless of account age.
  Future<Map<String, int>> subjectCompletionCountsOnce(String userId,
      {int sampleSize = 100}) async {
    if (userId.isEmpty) return const {};
    return _memoizer.runOnce('subjectCompletionCountsOnce_${userId}_$sampleSize', () async {
      final rows = await _attempts
          .select('subject')
          .eq('user_id', userId)
          .order('submitted_at', ascending: false)
          .limit(sampleSize);
      final counts = <String, int>{};
      for (final row in rows) {
        final subject = (row['subject'] as String?) ?? '';
        if (subject.isEmpty) continue;
        counts[subject] = (counts[subject] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ── Authoring (lecturer/admin) ───────────────────────────────────────

  Future<Result<String>> createTest(Test test) async {
    try {
      final row = await _tests.insert(test.toSupabase()).select('id').single();
      _memoizer.clear();
      return Success(row['id'] as String);
    } catch (e) {
      return Failure('Failed to create test', e);
    }
  }

  Future<Result<void>> updateTest(String testId, Test test) async {
    try {
      await _tests.update(test.toSupabase()).eq('id', testId);
      _memoizer.clear();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update test', e);
    }
  }

  Future<Result<void>> deleteTest(String testId) async {
    try {
      await _tests.delete().eq('id', testId);
      _memoizer.clear();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete test', e);
    }
  }

  // ── Taking a test ────────────────────────────────────────────────────

  /// Submits one attempt. [rawAnswers] keys are question ids; values are
  /// an `int` (selected option index) for mcq questions or a
  /// `List<String>` (one entry per line/key point) for structured/longForm
  /// questions.
  ///
  /// MCQ questions are graded and their XP awarded immediately. If the
  /// test is pure-MCQ (no manual grading needed), the completion bonus is
  /// also awarded immediately and the attempt is stored already `graded`.
  /// Otherwise the attempt is stored `submitted`, pending gradeResponse()
  /// calls for its structured/longForm questions.
  Future<Result<TestAttempt>> submitAttempt({
    required Test test,
    required String userId,
    required String userName,
    required Map<String, dynamic> rawAnswers,
    String educationLevel = '',
    /// Set when this test is being taken as quiz-as-homework (spec item
    /// 4B) — see TestTakingPage's "Take Quiz" launch from HomeworkPage.
    String? homeworkId,
  }) async {
    if (userId.isEmpty) return const Failure('Sign in to submit a test.', null);
    if (homeworkId != null) {
      // Fail fast client-side before doing any grading work -- the real,
      // unbypassable gate is the trigger on public.test_attempts (see
      // supabase/migrations/20260904000008_quiz_homework_expiry_enforcement.sql),
      // which re-checks this same effective-due-date function server-side
      // regardless of what the client does or skips.
      try {
        final effectiveDueAt = await _db.rpc('get_effective_homework_due_at', params: {
          'p_homework_id': homeworkId, 'p_student_id': userId,
        });
        final due = effectiveDueAt == null ? null : DateTime.tryParse(effectiveDueAt.toString());
        if (due != null && DateTime.now().isAfter(due)) {
          return const Failure('This quiz has expired and can no longer be submitted.', null);
        }
      } catch (_) {
        // best-effort pre-check -- the DB trigger is the real gate either way
      }
    }
    try {
      final levelMultiplier = academicLevelMultiplier(educationLevel);
      var totalXpFromQuestions = 0;
      final responses = <QuestionResponse>[];

      for (final q in test.questions) {
        if (q.type == QuestionType.mcq) {
          final selected = rawAnswers[q.id];
          final selectedIndex = selected is int ? selected : -1;
          final correct = selectedIndex == q.correctIndex;
          final pointsAwarded = correct ? q.maxPoints : 0;
          final xp = questionXp(
            type: q.type,
            pointsAwarded: pointsAwarded,
            maxPoints: q.maxPoints,
            difficulty: test.difficulty,
            levelMultiplier: levelMultiplier,
          );
          totalXpFromQuestions += xp;
          responses.add(QuestionResponse(
            questionId: q.id, type: q.type, maxPoints: q.maxPoints,
            selectedIndex: selectedIndex, pointsAwarded: pointsAwarded,
            graded: true, xpEarned: xp,
          ));
        } else if (q.type == QuestionType.longForm) {
          // production_plan.md §3 Quiz Type 3: the student submitted their
          // OWN short key points, not an essay. Match them against the
          // question's essential points offline (core/essay_matching.dart)
          // and score as "captured N of the 7–9 essential points".
          final graded = _matchAndGrade(
            q: q,
            expectedPoints: q.keyPoints,
            raw: rawAnswers[q.id],
            difficulty: test.difficulty,
            levelMultiplier: levelMultiplier,
          );
          totalXpFromQuestions += graded.xp;
          responses.add(graded.response);
        } else if (q.type == QuestionType.structured &&
            q.expectedPoints.isNotEmpty) {
          // production_plan.md §3 Quiz Type 2: same offline matcher as
          // Essay, reused against the author's expected answer/key
          // points. Only genuinely uncertain points reach the human queue.
          final graded = _matchAndGrade(
            q: q,
            expectedPoints: q.expectedPoints,
            raw: rawAnswers[q.id],
            difficulty: test.difficulty,
            levelMultiplier: levelMultiplier,
          );
          totalXpFromQuestions += graded.xp;
          responses.add(graded.response);
        } else {
          // Structured with no expected points authored — no expected
          // answer to match against, so this stays fully human-graded via
          // gradeResponse().
          final raw = rawAnswers[q.id];
          final textAnswer = raw is List
              ? raw.map((e) => e.toString()).toList()
              : (raw is String ? [raw] : <String>[]);
          responses.add(QuestionResponse(
            questionId: q.id, type: q.type, maxPoints: q.maxPoints,
            textAnswer: textAnswer, graded: false,
          ));
        }
      }

      final fullyGradedNow = responses.every((r) => r.graded);
      final scorePercentSoFar = test.totalPossiblePoints <= 0
          ? 0.0
          : (responses.fold(0, (s, r) => s + (r.pointsAwarded ?? 0)) /
              test.totalPossiblePoints *
              100);
      var bonus = 0;
      if (fullyGradedNow) {
        bonus = completionBonusXp(
          totalQuestionXpEarned: totalXpFromQuestions,
          scorePercent: scorePercentSoFar,
        );
        // production_plan.md §4.2 minimum completion reward: the whole
        // attempt's total (questions + bonus) must reach 25% of what
        // every question in the test was worth at this base rate/level —
        // top the bonus up if the tiered completionBonusXp() alone
        // didn't get there.
        final floor = minimumCompletionFloor(
            test.questions.map((q) => q.type).toList(), levelMultiplier);
        if (totalXpFromQuestions + bonus < floor) {
          bonus = floor - totalXpFromQuestions;
        }
      }

      // production_plan.md §4.3: the same test, by the same user, within
      // a rolling 72h window earns full/40%/0% on the 1st/2nd/3rd+
      // attempt. Applied AFTER the completion-bonus/floor math above, then
      // re-distributed across each response's own xpEarned so the model's
      // own documented invariant (sum of response xpEarned + bonus ==
      // totalXpAwarded) still holds.
      final cooldownStart = DateTime.now().subtract(kAttemptCooldownWindow);
      final priorRows = await _attempts
          .select('submitted_at')
          .eq('user_id', userId)
          .eq('test_id', test.id);
      final priorAttemptsInWindow = priorRows.where((r) {
        final ts = DateTime.tryParse(r['submitted_at']?.toString() ?? '');
        return ts != null && ts.isAfter(cooldownStart);
      }).length;
      final attemptMultiplier = attemptCooldownMultiplier(priorAttemptsInWindow);

      var dampedResponses = responses;
      var dampedTotalXpFromQuestions = totalXpFromQuestions;
      var dampedBonus = bonus;
      if (attemptMultiplier != 1.0) {
        dampedResponses = responses
            .map((r) => r.copyWith(xpEarned: (r.xpEarned * attemptMultiplier).round()))
            .toList();
        dampedTotalXpFromQuestions = dampedResponses.fold(0, (s, r) => s + r.xpEarned);
        dampedBonus = (bonus * attemptMultiplier).round();
      }

      final attempt = TestAttempt(
        id: '',
        testId: test.id,
        testTitle: test.title,
        subject: test.subject,
        difficulty: test.difficulty,
        userId: userId,
        userName: userName,
        responses: dampedResponses,
        totalPossiblePoints: test.totalPossiblePoints,
        status: fullyGradedNow ? AttemptStatus.graded : AttemptStatus.submitted,
        totalXpAwarded: dampedTotalXpFromQuestions + dampedBonus,
        submittedAt: DateTime.now(),
        gradedAt: fullyGradedNow ? DateTime.now() : null,
        levelMultiplier: levelMultiplier,
        attemptMultiplier: attemptMultiplier,
        homeworkId: homeworkId,
      );
      final Map<String, dynamic> row;
      try {
        row = await _attempts.insert(attempt.toSupabase()).select('id').single();
      } on PostgrestException catch (e) {
        // The homework-expiry trigger raises a plain exception if the
        // effective due date has passed -- surface that message directly
        // rather than a generic failure, same as the client-side
        // pre-check above.
        return Failure(e.message, e);
      }
      final attemptId = row['id'] as String;
      final savedAttempt = TestAttempt(
        id: attemptId, testId: attempt.testId, testTitle: attempt.testTitle,
        subject: attempt.subject, difficulty: attempt.difficulty,
        userId: attempt.userId, userName: attempt.userName, responses: attempt.responses,
        totalPossiblePoints: attempt.totalPossiblePoints, status: attempt.status,
        totalXpAwarded: attempt.totalXpAwarded, submittedAt: attempt.submittedAt,
        gradedAt: attempt.gradedAt, levelMultiplier: attempt.levelMultiplier,
        attemptMultiplier: attempt.attemptMultiplier, homeworkId: attempt.homeworkId,
      );
      bonus = dampedBonus;

      // Award XP for every auto-graded question, grouped BY SOURCE so the
      // ledger shows one clean "+N XP · MCQ" / "+N XP · Structural" /
      // "+N XP · Essay" entry per attempt rather than one row per
      // question.
      final xpBySource = <XpSource, int>{};
      for (final r in dampedResponses) {
        if (r.xpEarned <= 0) continue;
        final source = xpSourceForQuestionType(r.type);
        xpBySource[source] = (xpBySource[source] ?? 0) + r.xpEarned;
      }
      for (final entry in xpBySource.entries) {
        await XpRepository.instance.awardXp(userId, entry.key, entry.value, refId: attemptId);
      }
      if (bonus > 0) {
        await XpRepository.instance.awardXp(userId, XpSource.testCompletion, bonus, refId: attemptId);
      }
      _memoizer.clear();

      return Success(savedAttempt);
    } catch (e) {
      return Failure('Failed to submit test', e);
    }
  }

  // ── Grading (lecturer/admin, or a future AI grader) ─────────────────

  /// Grades one Structured/Essay response inside [attemptId]. Awards that
  /// question's XP immediately, and — if this was the LAST ungraded
  /// response in the attempt — also computes and awards the completion
  /// bonus, marking the attempt fully `graded`.
  ///
  /// [capturedKeyPointIds] is for a response that carries
  /// [QuestionResponse.keyPointOutcomes] — an Essay, or a Structured
  /// question authored with expected points: the ids of every key point
  /// the human grader considers captured, INCLUDING the ones the offline
  /// matcher already auto-confirmed. When it is supplied, [pointsAwarded]
  /// is ignored and the score is derived from its length instead. A plain
  /// Structured response with no expected points (empty
  /// [QuestionResponse.keyPointOutcomes]) ignores this parameter and is
  /// scored purely from the typed [pointsAwarded].
  Future<Result<void>> gradeResponse({
    required String attemptId,
    required String questionId,
    required int pointsAwarded,
    String? feedback,
    List<String>? capturedKeyPointIds,
  }) async {
    try {
      final row = await _attempts.select().eq('id', attemptId).maybeSingle();
      if (row == null) throw Exception('Attempt not found');
      final attempt = TestAttempt.fromSupabase(row);
      final userId = attempt.userId;

      final idx = attempt.responses.indexWhere((r) => r.questionId == questionId);
      if (idx == -1) throw Exception('Question not found in this attempt');
      final target = attempt.responses[idx];
      if (target.graded) throw Exception('This answer was already graded');

      // For an Essay, or a Structured question graded against expected
      // points, the grader's ticked key points ARE the score — record
      // their decision on each outcome so the result screen can show
      // exactly which points counted, and derive the points from that
      // same list.
      var effectivePoints = pointsAwarded;
      List<KeyPointOutcome>? updatedOutcomes;
      if (capturedKeyPointIds != null && target.keyPointOutcomes.isNotEmpty) {
        final captured = capturedKeyPointIds.toSet();
        updatedOutcomes = target.keyPointOutcomes
            .map((o) => o.copyWith(
                  verdict: captured.contains(o.keyPointId)
                      ? KeyPointVerdict.captured
                      : KeyPointVerdict.missed,
                  humanDecision: captured.contains(o.keyPointId),
                ))
            .toList();
        effectivePoints = updatedOutcomes.where((o) => o.counted).length;
      }

      // attempt.attemptMultiplier was fixed at submit time (§4.3 cooldown
      // dampening) — a manually-graded question inside a dampened attempt
      // earns the same reduced rate as every other question in it.
      final xp = (questionXp(
        type: target.type,
        pointsAwarded: effectivePoints,
        maxPoints: target.maxPoints,
        difficulty: attempt.difficulty,
        levelMultiplier: attempt.levelMultiplier,
      ) * attempt.attemptMultiplier).round();

      final updatedResponses = List<QuestionResponse>.from(attempt.responses);
      updatedResponses[idx] = target.copyWith(
        pointsAwarded: effectivePoints.clamp(0, target.maxPoints),
        graded: true, feedback: feedback, xpEarned: xp,
        keyPointOutcomes: updatedOutcomes,
      );

      final nowFullyGraded = updatedResponses.every((r) => r.graded);
      var bonus = 0;
      if (nowFullyGraded) {
        if (attempt.attemptMultiplier <= 0) {
          // Third+ attempt within the cooldown window earns 0 XP outright.
          bonus = 0;
        } else {
          // Every response's stored xpEarned (including the one just
          // graded above) is already damped by attemptMultiplier. Recover
          // the full-rate (undamped) total to run the bonus/floor math
          // against — matches submitAttempt's "compute at full rate,
          // dampen once at the end" order.
          final dampedTotalQuestionXp = updatedResponses.fold(0, (s, r) => s + r.xpEarned);
          final rawTotalQuestionXp = (dampedTotalQuestionXp / attempt.attemptMultiplier).round();
          final gradedPoints = updatedResponses.fold(0, (s, r) => s + (r.pointsAwarded ?? 0));
          final scorePercent = attempt.totalPossiblePoints <= 0
              ? 0.0
              : (gradedPoints / attempt.totalPossiblePoints * 100);
          var rawBonus = completionBonusXp(
            totalQuestionXpEarned: rawTotalQuestionXp,
            scorePercent: scorePercent,
          );
          final floor = minimumCompletionFloor(
              updatedResponses.map((r) => r.type).toList(), attempt.levelMultiplier);
          if (rawTotalQuestionXp + rawBonus < floor) {
            rawBonus = floor - rawTotalQuestionXp;
          }
          bonus = (rawBonus * attempt.attemptMultiplier).round();
        }
      }

      await _attempts.update({
        'responses': updatedResponses.map((r) => r.toMap()).toList(),
        'status': nowFullyGraded ? AttemptStatus.graded.name : AttemptStatus.submitted.name,
        'graded_at': nowFullyGraded ? DateTime.now().toIso8601String() : null,
        'total_xp_awarded': attempt.totalXpAwarded + xp + bonus,
      }).eq('id', attemptId);

      if (xp > 0) {
        await XpRepository.instance.awardXp(userId, xpSourceForQuestionType(target.type), xp, refId: attemptId);
      }
      if (bonus > 0) {
        await XpRepository.instance.awardXp(userId, XpSource.testCompletion, bonus, refId: attemptId);
      }
      _memoizer.clear();
      return const Success(null);
    } catch (e) {
      return Failure(e.toString().replaceFirst('Exception: ', ''), e);
    }
  }

  // ── Shared key-point matching (Essay + auto-graded Structured) ──────
  //
  // Both Essay (longForm) and a Structured question authored with
  // TestQuestion.expectedPoints are graded the exact same way: match the
  // student's own short points against a list of EssayKeyPoint-shaped
  // expected points via core/essay_matching.dart, and either grade
  // immediately (matcher confident about every point) or leave the
  // response ungraded with the confident outcomes already attached
  // (matcher genuinely undecided about at least one point).
  ({QuestionResponse response, int xp}) _matchAndGrade({
    required TestQuestion q,
    required List<EssayKeyPoint> expectedPoints,
    required dynamic raw,
    required TestDifficulty difficulty,
    required double levelMultiplier,
  }) {
    final studentPoints = (raw is List
            ? raw.map((e) => e.toString())
            : (raw is String ? [raw] : const <String>[]))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final match = matchEssayKeyPoints(
      keyPoints: expectedPoints,
      studentPoints: studentPoints,
    );
    final outcomes = match.matches
        .map((m) => KeyPointOutcome(
              keyPointId: m.keyPointId,
              keyPointText: m.keyPointText,
              studentText: m.studentText,
              score: m.score,
              verdict: m.verdict,
            ))
        .toList();

    if (match.needsHumanReview) {
      // Only the genuinely ambiguous points need a person. The response
      // carries every outcome already decided, so the grading queue shows
      // a mostly-finished picture and asks for a call on the flagged
      // points only.
      return (
        response: QuestionResponse(
          questionId: q.id, type: q.type, maxPoints: q.maxPoints,
          textAnswer: studentPoints, keyPointOutcomes: outcomes,
          graded: false,
        ),
        xp: 0,
      );
    }

    final pointsAwarded = match.capturedCount;
    final xp = questionXp(
      type: q.type,
      pointsAwarded: pointsAwarded,
      maxPoints: q.maxPoints,
      difficulty: difficulty,
      levelMultiplier: levelMultiplier,
    );
    return (
      response: QuestionResponse(
        questionId: q.id, type: q.type, maxPoints: q.maxPoints,
        textAnswer: studentPoints, keyPointOutcomes: outcomes,
        pointsAwarded: pointsAwarded, graded: true, xpEarned: xp,
      ),
      xp: xp,
    );
  }

  // ── History ──────────────────────────────────────────────────────────

  /// A user's full test history, newest first.
  Stream<List<TestAttempt>> watchAttemptHistory(String userId, {int limit = 50}) => _attempts
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('submitted_at', ascending: false)
      .limit(limit)
      .realtimeTolerant()
      .map((rows) => rows.map(TestAttempt.fromSupabase).toList());

  /// Attempts still awaiting manual grading — the lecturer/admin queue.
  /// Optionally scoped to one subject.
  Stream<List<TestAttempt>> watchPendingGradingQueue({String? subject}) {
    return _attempts
        .stream(primaryKey: ['id'])
        .eq('status', AttemptStatus.submitted.name)
        .order('submitted_at')
        .realtimeTolerant()
        .map((rows) {
      final all = rows.map(TestAttempt.fromSupabase).toList();
      if (subject == null || subject.isEmpty) return all;
      return all.where((a) => a.subject == subject).toList();
    });
  }
}
