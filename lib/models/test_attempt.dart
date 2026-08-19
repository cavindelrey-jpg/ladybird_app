// lib/models/test_attempt.dart
// One user's submission for one Test. Firestore: top-level
// `testAttempts/{attemptId}` (not a subcollection of the test) so a
// user's full test history can be queried with one
// `where(userId==...).orderBy(submittedAt)` regardless of which subject
// or test each attempt belongs to — same shape as xpTransactions.
//
// Grading framework:
//   - mcq responses are graded the instant the attempt is submitted
//     (TestRepository.submitAttempt) — deterministic, no human needed.
//   - longForm (Essay) responses are matched against the question's
//     essential key points at submit time by core/essay_matching.dart,
//     entirely offline. When the matcher is confident about every key
//     point — the common case — the response is graded immediately too,
//     scored as "captured N of the 7–9 essential points". Only when it
//     is genuinely undecided about one or more points does the response
//     stay ungraded and enter the human queue, and even then the human
//     is deciding a handful of specific flagged points rather than
//     reading prose from scratch.
//   - structured responses (production_plan.md §3 Quiz Type 2) follow the
//     identical rule to Essay whenever the question was authored with
//     TestQuestion.expectedPoints: matched the same way, at submit time,
//     by the same core/essay_matching.dart matcher, with only genuinely
//     undecided points reaching the human queue. A structured question
//     authored with NO expected points (the pre-existing shape, or a
//     genuinely rubric-only question) always starts ungraded
//     (pointsAwarded: null, graded: false) and waits for
//     TestRepository.gradeResponse(), called today by a lecturer/admin
//     from the grading queue. That method is the seam an AI grader would
//     plug into later (call it with a model-suggested score instead of a
//     human-typed one) — nothing about the data model or XP math changes
//     if the grader on the other end becomes automated, which is the
//     "future AI evaluation" the spec asks to leave room for. No AI
//     grading call is wired up yet — flagging that honestly rather than
//     pretending it's live.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/essay_matching.dart';
import 'test.dart';

enum AttemptStatus { submitted, graded }

extension AttemptStatusExt on AttemptStatus {
  static AttemptStatus fromKey(String? key) => key == 'graded'
      ? AttemptStatus.graded
      : AttemptStatus.submitted;
}

/// The stored verdict for ONE essential/expected key point of an Essay or
/// auto-graded Structured answer (production_plan.md §3, Quiz Types 2 and
/// 3). Produced by core/essay_matching.dart at submit time and then
/// frozen into the attempt.
///
/// [keyPointText] is DENORMALIZED on purpose — copied out of the Test at
/// submit time rather than re-read from it when grading. An attempt is a
/// record of what the student was actually asked; if the author later
/// edits or reorders the question's key points, this attempt's grading
/// screen and result screen must still show what was true when it was
/// taken. It also means the grading queue needs no second fetch.
class KeyPointOutcome {
  final String keyPointId;
  final String keyPointText;

  /// The student's own wording that the matcher paired with this key
  /// point; empty when nothing matched it.
  final String studentText;

  /// The matcher's weighted-recall score, kept for transparency — a
  /// grader can see how close the call was, and it makes any later
  /// threshold tuning auditable against real attempts.
  final double score;

  final KeyPointVerdict verdict;

  /// Set only when a human resolved an [KeyPointVerdict.uncertain] point
  /// in the grading queue: true = the grader allowed it, false = the
  /// grader rejected it. Null means no human ever touched this point.
  final bool? humanDecision;

  const KeyPointOutcome({
    required this.keyPointId,
    required this.keyPointText,
    this.studentText = '',
    this.score = 0,
    required this.verdict,
    this.humanDecision,
  });

  /// Whether this point counts toward the score right now — a human's
  /// decision always wins over the matcher's.
  bool get counted =>
      humanDecision ?? (verdict == KeyPointVerdict.captured);

  KeyPointOutcome copyWith({KeyPointVerdict? verdict, bool? humanDecision}) =>
      KeyPointOutcome(
        keyPointId: keyPointId,
        keyPointText: keyPointText,
        studentText: studentText,
        score: score,
        verdict: verdict ?? this.verdict,
        humanDecision: humanDecision ?? this.humanDecision,
      );

  factory KeyPointOutcome.fromMap(Map<String, dynamic> m) => KeyPointOutcome(
        keyPointId: m['keyPointId'] ?? '',
        keyPointText: m['keyPointText'] ?? '',
        studentText: m['studentText'] ?? '',
        score: (m['score'] as num?)?.toDouble() ?? 0,
        verdict: KeyPointVerdictExt.fromKey(m['verdict']),
        humanDecision: m['humanDecision'] as bool?,
      );

  Map<String, dynamic> toMap() => {
        'keyPointId': keyPointId,
        'keyPointText': keyPointText,
        'studentText': studentText,
        'score': score,
        'verdict': verdict.name,
        'humanDecision': humanDecision,
      };
}

class QuestionResponse {
  final String questionId;
  final QuestionType type;
  final int maxPoints;

  // mcq
  final int? selectedIndex;

  // structured — raw text, one entry per answered line (whether or not
  // the question was authored with expectedPoints — this is always what
  // the student actually typed).
  // longForm (Essay) — the student's OWN short key points, one entry
  // each, in the order they entered them. Never a full essay: §3 is
  // explicit that the student states the essential points rather than
  // reproducing a two-page essay in the app.
  final List<String> textAnswer;

  /// One entry per authored expected/key point, in the author's order —
  /// for an Essay (always) or a Structured question authored WITH
  /// TestQuestion.expectedPoints (auto-graded the same way). Empty for
  /// mcq and for a Structured response with no expected points (still
  /// fully human-graded).
  final List<KeyPointOutcome> keyPointOutcomes;

  final int? pointsAwarded;
  final bool graded;
  final String? feedback;
  /// XP already credited for this specific response — kept per-response
  /// so a full test-history breakdown can show "this question earned you
  /// N XP" without recomputing from scratch.
  final int xpEarned;

  const QuestionResponse({
    required this.questionId,
    required this.type,
    required this.maxPoints,
    this.selectedIndex,
    this.textAnswer = const [],
    this.keyPointOutcomes = const [],
    this.pointsAwarded,
    this.graded = false,
    this.feedback,
    this.xpEarned = 0,
  });

  /// Key points still awaiting a human's final call.
  List<KeyPointOutcome> get uncertainOutcomes => keyPointOutcomes
      .where((o) => o.verdict == KeyPointVerdict.uncertain && o.humanDecision == null)
      .toList();

  /// How many essential/expected points currently count as captured —
  /// the Essay/auto-graded-Structured score, straight out of §3's
  /// "evaluate how many essential points the student captured" /
  /// "evaluate automatically where possible" wording for each format.
  int get capturedKeyPointCount =>
      keyPointOutcomes.where((o) => o.counted).length;

  QuestionResponse copyWith({
    int? pointsAwarded,
    bool? graded,
    String? feedback,
    int? xpEarned,
    List<KeyPointOutcome>? keyPointOutcomes,
  }) =>
      QuestionResponse(
        questionId: questionId,
        type: type,
        maxPoints: maxPoints,
        selectedIndex: selectedIndex,
        textAnswer: textAnswer,
        keyPointOutcomes: keyPointOutcomes ?? this.keyPointOutcomes,
        pointsAwarded: pointsAwarded ?? this.pointsAwarded,
        graded: graded ?? this.graded,
        feedback: feedback ?? this.feedback,
        xpEarned: xpEarned ?? this.xpEarned,
      );

  factory QuestionResponse.fromMap(Map<String, dynamic> m) => QuestionResponse(
        questionId: m['questionId'] ?? '',
        type: QuestionTypeExt.fromKey(m['type']),
        maxPoints: (m['maxPoints'] as num?)?.toInt() ?? 0,
        selectedIndex: (m['selectedIndex'] as num?)?.toInt(),
        textAnswer: List<String>.from(m['textAnswer'] ?? const []),
        keyPointOutcomes: (m['keyPointOutcomes'] as List<dynamic>? ?? [])
            .map((o) => KeyPointOutcome.fromMap(Map<String, dynamic>.from(o)))
            .toList(),
        pointsAwarded: (m['pointsAwarded'] as num?)?.toInt(),
        graded: m['graded'] ?? false,
        feedback: m['feedback'],
        xpEarned: (m['xpEarned'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'questionId': questionId,
        'type': type.name,
        'maxPoints': maxPoints,
        'selectedIndex': selectedIndex,
        'textAnswer': textAnswer,
        'keyPointOutcomes': keyPointOutcomes.map((o) => o.toMap()).toList(),
        'pointsAwarded': pointsAwarded,
        'graded': graded,
        'feedback': feedback,
        'xpEarned': xpEarned,
      };
}

class TestAttempt {
  final String id;
  final String testId;
  final String testTitle;
  final String subject;
  final TestDifficulty difficulty;
  final String userId;
  final String userName;
  final List<QuestionResponse> responses;
  final int totalPossiblePoints;
  final AttemptStatus status;
  /// Sum of every response's [QuestionResponse.xpEarned] PLUS the
  /// completion bonus once awarded — the one number test-history UI
  /// should show as "XP from this attempt".
  final int totalXpAwarded;
  final DateTime submittedAt;
  final DateTime? gradedAt;

  /// The submitter's academic-level XP multiplier (see
  /// core/xp_rules.dart's academicLevelMultiplier), captured at submit
  /// time and reused for every later gradeResponse() call on structured/
  /// longForm questions in this same attempt — so a profile-level change
  /// after submitting never retroactively changes an already-in-progress
  /// attempt's XP math. Defaults to 1.0 for attempts written before this
  /// field existed.
  final double levelMultiplier;

  /// production_plan.md §4.3 attempt-cooldown dampening for this exact
  /// test within a rolling 72h window: 1.0 on the first eligible attempt,
  /// 0.4 on a second, 0.0 on a third or later. Computed once at submit
  /// time (see TestRepository.submitAttempt) and reused by every later
  /// gradeResponse() call on the same attempt, for the same "don't let a
  /// profile/context change retroactively alter an in-progress attempt's
  /// math" reason as [levelMultiplier]. Defaults to 1.0 for attempts
  /// written before this field existed.
  final double attemptMultiplier;

  const TestAttempt({
    required this.id,
    required this.testId,
    required this.testTitle,
    required this.subject,
    required this.difficulty,
    required this.userId,
    required this.userName,
    required this.responses,
    required this.totalPossiblePoints,
    required this.status,
    required this.totalXpAwarded,
    required this.submittedAt,
    this.gradedAt,
    this.levelMultiplier = 1.0,
    this.attemptMultiplier = 1.0,
  });

  int get gradedPoints =>
      responses.fold(0, (s, r) => s + (r.pointsAwarded ?? 0));

  double get scorePercent => totalPossiblePoints <= 0
      ? 0
      : (gradedPoints / totalPossiblePoints * 100);

  bool get fullyGraded => responses.every((r) => r.graded);
  bool get hasPendingGrading => !fullyGraded;

  factory TestAttempt.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final submitted = d['submittedAt'];
    final graded = d['gradedAt'];
    return TestAttempt(
      id: doc.id,
      testId: d['testId'] ?? '',
      testTitle: d['testTitle'] ?? '',
      subject: d['subject'] ?? '',
      difficulty: TestDifficultyExt.fromKey(d['difficulty']),
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      responses: (d['responses'] as List<dynamic>? ?? [])
          .map((r) => QuestionResponse.fromMap(Map<String, dynamic>.from(r)))
          .toList(),
      totalPossiblePoints: (d['totalPossiblePoints'] as num?)?.toInt() ?? 0,
      status: AttemptStatusExt.fromKey(d['status']),
      totalXpAwarded: (d['totalXpAwarded'] as num?)?.toInt() ?? 0,
      submittedAt: submitted is Timestamp ? submitted.toDate() : DateTime.now(),
      gradedAt: graded is Timestamp ? graded.toDate() : null,
      levelMultiplier: (d['levelMultiplier'] as num?)?.toDouble() ?? 1.0,
      attemptMultiplier: (d['attemptMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'testId': testId,
        'testTitle': testTitle,
        'subject': subject,
        'difficulty': difficulty.name,
        'userId': userId,
        'userName': userName,
        'responses': responses.map((r) => r.toMap()).toList(),
        'totalPossiblePoints': totalPossiblePoints,
        'status': status.name,
        'totalXpAwarded': totalXpAwarded,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'gradedAt': gradedAt == null ? null : Timestamp.fromDate(gradedAt!),
        'levelMultiplier': levelMultiplier,
        'attemptMultiplier': attemptMultiplier,
      };
}
