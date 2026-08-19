// lib/repositories/test_repository.dart
// All reads/writes for the Testing & Quiz system: tests/{testId} and
// top-level testAttempts/{attemptId}. See models/test.dart and
// models/test_attempt.dart for the schema rationale.
//
// Grading framework:
//   - MCQ questions are graded the instant an attempt is submitted.
//   - Essay (longForm) questions are auto-scored at submit time against
//     the question's essential key points by core/essay_matching.dart —
//     offline, in-process, no external service. They only enter the human
//     queue when that matcher is explicitly undecided about one or more
//     key points, and the human then confirms/rejects just those points
//     rather than grading the answer from scratch.
//   - Structured questions start ungraded and are graded via
//     gradeResponse() — today, called by a lecturer/admin from the
//     grading queue (watchPendingGradingQueue). That single method is
//     the seam a future AI grader would call into instead of a human —
//     nothing else in this repository would need to change. No AI
//     grading is wired up yet; this is a real gap, not a hidden one.
//   - XP for every graded question flows through XpRepository.awardXp
//     (capped, logged) using the rates in core/xp_rules.dart — never a
//     bespoke increment here.
//
// Honest scope note: this repository doesn't itself restrict who can
// call createTest() or gradeResponse() — that enforcement belongs in
// firestore.rules (role checks against the caller's `users/{uid}.role`),
// which hasn't been updated for the `tests`/`testAttempts` collections
// yet. UI should still gate these behind AppUser.canUploadContent /
// hasMinRole(lecturer) as a first line of defense, matching how
// AcademicContentRepository's upload flow already works.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/essay_matching.dart';
import '../core/result.dart';
import '../core/xp_rules.dart';
import '../models/test.dart';
import '../models/test_attempt.dart';
import '../models/xp_transaction.dart';
import 'xp_repository.dart';

class TestRepository {
  TestRepository._();
  static final TestRepository instance = TestRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tests =>
      _db.collection(AppConstants.colTests);
  CollectionReference<Map<String, dynamic>> get _attempts =>
      _db.collection(AppConstants.colTestAttempts);

  // ── Reading tests ────────────────────────────────────────────────────

  /// Live list of published tests for one subject. [institutionId] null
  /// means "show only the open-to-everyone tests"; pass the student's
  /// own institutionId to ALSO include their school's restricted tests
  /// (done client-side below since Firestore can't OR two `where`s on
  /// different fields in one query without a composite index per
  /// combination — acceptable at this scale; revisit if a subject
  /// regularly has hundreds of tests).
  Stream<List<Test>> watchTestsBySubject(String subject, {String? institutionId}) {
    return _tests
        .where('subject', isEqualTo: subject)
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) {
      final all = s.docs.map(Test.fromFirestore).toList();
      return all
          .where((t) => t.institutionId == null || t.institutionId == institutionId)
          .toList();
    });
  }

  Stream<Test?> watchTest(String testId) => _tests
      .doc(testId)
      .snapshots()
      .map((d) => d.exists ? Test.fromFirestore(d) : null);

  /// Distinct subjects that currently have at least one published test —
  /// drives the subject picker. Computed from real documents, same
  /// pattern as AcademicContentRepository.subjectsOnce(); no fixed
  /// hardcoded subject list.
  Future<List<String>> distinctSubjectsOnce() async {
    final snap = await _tests.where('published', isEqualTo: true).get();
    final subjects = snap.docs
        .map((d) => (d.data()['subject'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return subjects;
  }

  /// Real per-subject test counts — for a subject-picker grid that shows
  /// "12 tests" instead of a bare list, without fabricating a number.
  Future<Map<String, int>> subjectTestCountsOnce() async {
    final snap = await _tests.where('published', isEqualTo: true).get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final subject = (doc.data()['subject'] as String?) ?? '';
      if (subject.isEmpty) continue;
      counts[subject] = (counts[subject] ?? 0) + 1;
    }
    return counts;
  }

  /// Bounded recent-tests fetch across every subject — the fallback/pool
  /// query for RecommendationRepository.forQuizzes(), same "recency,
  /// unfiltered, filtered client-side by caller" shape as
  /// PublicCourseRepository.watchLatest() and MagazineRepository
  /// .watchFeed(). Uses the `published`+`createdAt` composite index that
  /// already exists in firestore.indexes.json for this exact query
  /// shape (see the file's own comment near that index) — no new index
  /// needed.
  Future<List<Test>> recentPublishedOnce({int limit = 60}) async {
    final snap = await _tests
        .where('published', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(Test.fromFirestore).toList();
  }

  // ── Usage signal (production_plan.md §5) ────────────────────────────
  // "Mathematics + Physics → follows Physics authors → frequently
  // completes Physics quizzes" — the plan's own example of a usage signal
  // the recommendation system should pick up on. Rather than add a new
  // denormalized per-subject counter (a write-time bookkeeping pipeline
  // nothing else in this codebase needed until now), this derives the
  // signal from data that is ALREADY recorded on every attempt —
  // TestAttempt.subject — via one bounded query. Cheap, honest, and
  // self-correcting (no counter that can drift from the underlying
  // attempts).

  /// How many of [userId]'s most recent test attempts were in each
  /// subject. Bounded to [sampleSize] so this stays a single cheap query
  /// regardless of account age — a recency-weighted signal ("what have
  /// you been doing lately"), not a lifetime total, which is also the
  /// more honest thing to rank "frequently completes" against.
  Future<Map<String, int>> subjectCompletionCountsOnce(String userId,
      {int sampleSize = 100}) async {
    if (userId.isEmpty) return const {};
    final snap = await _attempts
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .limit(sampleSize)
        .get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final subject = (doc.data()['subject'] as String?) ?? '';
      if (subject.isEmpty) continue;
      counts[subject] = (counts[subject] ?? 0) + 1;
    }
    return counts;
  }

  // ── Authoring (lecturer/admin) ───────────────────────────────────────

  Future<Result<String>> createTest(Test test) async {
    try {
      final ref = await _tests.add(test.toFirestore());
      return Success(ref.id);
    } catch (e) {
      return Failure('Failed to create test', e);
    }
  }

  Future<Result<void>> updateTest(String testId, Test test) async {
    try {
      await _tests.doc(testId).set(test.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update test', e);
    }
  }

  Future<Result<void>> deleteTest(String testId) async {
    try {
      await _tests.doc(testId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete test', e);
    }
  }

  // ── Taking a test ────────────────────────────────────────────────────

  /// Submits one attempt. [rawAnswers] keys are question ids; values are
  /// an `int` (selected option index) for mcq questions or a
  /// `List<String>` (one entry per line/section) for structured/longForm
  /// questions.
  ///
  /// MCQ questions are graded and their XP awarded immediately. If the
  /// test is pure-MCQ (no manual grading needed), the completion bonus is
  /// also awarded immediately and the attempt is stored already
  /// `graded`. Otherwise the attempt is stored `submitted`, pending
  /// gradeResponse() calls for its structured/longForm questions.
  Future<Result<TestAttempt>> submitAttempt({
    required Test test,
    required String userId,
    required String userName,
    required Map<String, dynamic> rawAnswers,
    String educationLevel = '',
  }) async {
    if (userId.isEmpty) return const Failure('Sign in to submit a test.', null);
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
          // question's essential points offline (core/essay_matching.dart —
          // no external service, see that file's header) and score as
          // "captured N of the 7–9 essential points".
          final raw = rawAnswers[q.id];
          final studentPoints = (raw is List
                  ? raw.map((e) => e.toString())
                  : (raw is String ? [raw] : const <String>[]))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          final match = matchEssayKeyPoints(
            keyPoints: q.keyPoints,
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
            // Only the genuinely ambiguous points need a person. The
            // response carries every outcome already decided, so the
            // grading queue shows a mostly-finished picture and asks for
            // a call on the flagged points only.
            responses.add(QuestionResponse(
              questionId: q.id, type: q.type, maxPoints: q.maxPoints,
              textAnswer: studentPoints, keyPointOutcomes: outcomes,
              graded: false,
            ));
          } else {
            final pointsAwarded = match.capturedCount;
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
              textAnswer: studentPoints, keyPointOutcomes: outcomes,
              pointsAwarded: pointsAwarded, graded: true, xpEarned: xp,
            ));
          }
        } else {
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
        // didn't get there (e.g. a very low score still completed).
        final floor = minimumCompletionFloor(
            test.questions.map((q) => q.type).toList(), levelMultiplier);
        if (totalXpFromQuestions + bonus < floor) {
          bonus = floor - totalXpFromQuestions;
        }
      }

      // production_plan.md §4.3: the same test, by the same user, within
      // a rolling 72h window earns full/40%/0% on the 1st/2nd/3rd+
      // attempt. Applied AFTER the completion-bonus/floor math above (the
      // spec's minimum-reward text explicitly says it's "subject to the
      // applicable attempt rules"), then re-distributed across each
      // response's own xpEarned so the model's own documented invariant
      // (sum of response xpEarned + bonus == totalXpAwarded) still holds.
      final cooldownStart = DateTime.now().subtract(kAttemptCooldownWindow);
      final priorSnap = await _attempts
          .where('userId', isEqualTo: userId)
          .where('testId', isEqualTo: test.id)
          .get();
      final priorAttemptsInWindow = priorSnap.docs.where((d) {
        final ts = d.data()['submittedAt'];
        return ts is Timestamp && ts.toDate().isAfter(cooldownStart);
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

      final attemptRef = _attempts.doc();
      final attempt = TestAttempt(
        id: attemptRef.id,
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
      );
      await attemptRef.set(attempt.toFirestore());
      bonus = dampedBonus;

      // Award XP for every auto-graded question, grouped BY SOURCE so the
      // ledger shows one clean "+N XP · MCQ" / "+N XP · Essay" entry per
      // attempt rather than one row per question. Grouping by source (it
      // used to be a single lump booked as XpSource.mcq) matters now that
      // an Essay can also be auto-graded at submit time — booking essay
      // XP as MCQ XP would quietly corrupt the ledger's own breakdown.
      final xpBySource = <XpSource, int>{};
      for (final r in dampedResponses) {
        if (r.xpEarned <= 0) continue;
        final source = xpSourceForQuestionType(r.type);
        xpBySource[source] = (xpBySource[source] ?? 0) + r.xpEarned;
      }
      for (final entry in xpBySource.entries) {
        await XpRepository.instance.awardXp(
          userId, entry.key, entry.value,
          refId: attemptRef.id,
        );
      }
      if (bonus > 0) {
        await XpRepository.instance.awardXp(
          userId, XpSource.testCompletion, bonus,
          refId: attemptRef.id,
        );
      }

      return Success(attempt);
    } catch (e) {
      return Failure('Failed to submit test', e);
    }
  }

  // ── Grading (lecturer/admin, or a future AI grader) ─────────────────

  /// Grades one structured/Essay response inside [attemptId]. Awards that
  /// question's XP immediately, and — if this was the LAST ungraded
  /// response in the attempt — also computes and awards the completion
  /// bonus, marking the attempt fully `graded`.
  ///
  /// [capturedKeyPointIds] is for Essay responses only: the ids of every
  /// key point the human grader considers captured, INCLUDING the ones
  /// the offline matcher already auto-confirmed. When it is supplied,
  /// [pointsAwarded] is ignored and the score is derived from its length
  /// instead — the Essay score is by definition "how many essential
  /// points were captured" (production_plan.md §3), so allowing a grader
  /// to tick 5 points and simultaneously type a score of 7 would let the
  /// stored outcomes and the stored score disagree. Deriving it removes
  /// that possibility entirely.
  Future<Result<void>> gradeResponse({
    required String attemptId,
    required String questionId,
    required int pointsAwarded,
    String? feedback,
    List<String>? capturedKeyPointIds,
  }) async {
    try {
      int xpJustAwarded = 0;
      int bonusJustAwarded = 0;
      String userId = '';

      await _db.runTransaction((tx) async {
        final snap = await tx.get(_attempts.doc(attemptId));
        if (!snap.exists) throw Exception('Attempt not found');
        final attempt = TestAttempt.fromFirestore(snap);
        userId = attempt.userId;

        final idx = attempt.responses.indexWhere((r) => r.questionId == questionId);
        if (idx == -1) throw Exception('Question not found in this attempt');
        final target = attempt.responses[idx];
        if (target.graded) throw Exception('This answer was already graded');

        // For an Essay, the grader's ticked key points ARE the score —
        // record their decision on each outcome so the result screen can
        // show exactly which essential points counted, and derive the
        // points from that same list.
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

        // attempt.attemptMultiplier was fixed at submit time (§4.3
        // cooldown dampening) — a manually-graded question inside a
        // dampened attempt earns the same reduced rate as every other
        // question in it, not full rate.
        final xp = (questionXp(
          type: target.type,
          pointsAwarded: effectivePoints,
          maxPoints: target.maxPoints,
          difficulty: attempt.difficulty,
          levelMultiplier: attempt.levelMultiplier,
        ) * attempt.attemptMultiplier).round();
        xpJustAwarded = xp;

        final updatedResponses = List<QuestionResponse>.from(attempt.responses);
        updatedResponses[idx] = target.copyWith(
          pointsAwarded: effectivePoints.clamp(0, target.maxPoints),
          graded: true,
          feedback: feedback,
          xpEarned: xp,
          keyPointOutcomes: updatedOutcomes,
        );

        final nowFullyGraded = updatedResponses.every((r) => r.graded);
        var bonus = 0;
        if (nowFullyGraded) {
          if (attempt.attemptMultiplier <= 0) {
            // Third+ attempt within the cooldown window earns 0 XP
            // outright -- every stored xpEarned above is already 0, and
            // there's no full-rate total to recover a floor/bonus from.
            bonus = 0;
          } else {
            // Every response's stored xpEarned (including the one just
            // graded above) is already damped by attemptMultiplier.
            // Recover the full-rate (undamped) total to run the bonus/
            // floor math against — matches submitAttempt's "compute at
            // full rate, dampen once at the end" order, so a repeat
            // attempt's minimum-reward floor can't silently cancel out
            // the §4.3 cooldown reduction it's meant to respect.
            final dampedTotalQuestionXp =
                updatedResponses.fold(0, (s, r) => s + r.xpEarned);
            final rawTotalQuestionXp =
                (dampedTotalQuestionXp / attempt.attemptMultiplier).round();
            final gradedPoints =
                updatedResponses.fold(0, (s, r) => s + (r.pointsAwarded ?? 0));
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
          bonusJustAwarded = bonus;
        }

        tx.update(_attempts.doc(attemptId), {
          'responses': updatedResponses.map((r) => r.toMap()).toList(),
          'status': nowFullyGraded ? AttemptStatus.graded.name : AttemptStatus.submitted.name,
          'gradedAt': nowFullyGraded ? Timestamp.fromDate(DateTime.now()) : null,
          'totalXpAwarded': FieldValue.increment(xp + bonus),
        });
      });

      if (xpJustAwarded > 0) {
        final source = await _sourceForGrading(attemptId, questionId);
        await XpRepository.instance.awardXp(
          userId, source, xpJustAwarded, refId: attemptId,
        );
      }
      if (bonusJustAwarded > 0) {
        await XpRepository.instance.awardXp(
          userId, XpSource.testCompletion, bonusJustAwarded, refId: attemptId,
        );
      }
      return const Success(null);
    } catch (e) {
      return Failure(e.toString().replaceFirst('Exception: ', ''), e);
    }
  }

  // gradeResponse doesn't have the QuestionType handy after the
  // transaction closes (it only returns primitives out of the closure by
  // design, to keep the transaction retryable/side-effect-free) — so it
  // re-derives the source from a fresh read. Simple and correct at the
  // cost of one extra read per manual grade, which is a rare, human-paced
  // action (not a hot path like awardXp's own cap check).
  Future<XpSource> _sourceForGrading(String attemptId, String questionId) async {
    final doc = await _attempts.doc(attemptId).get();
    final attempt = TestAttempt.fromFirestore(doc);
    final q = attempt.responses.firstWhere((r) => r.questionId == questionId);
    return xpSourceForQuestionType(q.type);
  }

  // ── History ──────────────────────────────────────────────────────────

  /// A user's full test history, newest first — powers the XP dashboard's
  /// "Test History" section.
  Stream<List<TestAttempt>> watchAttemptHistory(String userId, {int limit = 50}) => _attempts
      .where('userId', isEqualTo: userId)
      .orderBy('submittedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(TestAttempt.fromFirestore).toList());

  /// Attempts still awaiting manual grading — the lecturer/admin queue.
  /// Optionally scoped to one subject (e.g. a lecturer only grading
  /// their own subject's tests).
  Stream<List<TestAttempt>> watchPendingGradingQueue({String? subject}) {
    Query<Map<String, dynamic>> q = _attempts
        .where('status', isEqualTo: AttemptStatus.submitted.name)
        .orderBy('submittedAt');
    return q.snapshots().map((s) {
      final all = s.docs.map(TestAttempt.fromFirestore).toList();
      if (subject == null || subject.isEmpty) return all;
      return all.where((a) => a.subject == subject).toList();
    });
  }
}
