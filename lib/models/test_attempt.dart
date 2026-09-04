// lib/models/test_attempt.dart
// One user's submission for one Test. Firestore: top-level
// `testAttempts/{attemptId}` (not a subcollection of the test) so a
// user's full test history can be queried with one
// `where(userId==...).orderBy(submittedAt)` regardless of which subject
// or test each attempt belongs to — same shape as xpTransactions.
//
// Grading framework: every question type is graded the instant the
// attempt is submitted (TestRepository.submitAttempt) — mcq by exact
// match, structured/longForm by core/essay_matching.dart's key-point
// matcher. There is no manual grading queue; [AttemptStatus.submitted]
// only exists for attempts written before this became true.
//
// Each response denormalizes enough of its question (prompt, mcq
// options/correct answer, or key-point match results) that the results
// page can render a full correction — right/wrong per question — from
// the attempt alone, without a second read of the (possibly since
// edited or deleted) Test document. Same "denormalize, don't join"
// reasoning as embedding questions on Test itself.

import 'test.dart';
import '../core/essay_matching.dart';

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

  /// Set only when a human resolved a [KeyPointVerdict.uncertain] point
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
  final String prompt;
  final int maxPoints;

  // mcq — denormalized so the correction view can show the right answer
  // even if the Test's own options are edited/removed later.
  final int? selectedIndex;
  final List<String> options;
  final int? correctIndex;

  // structured / longForm — raw text, one entry per line (structured) or
  // a single full-essay entry (longForm), same order as submitted.
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
    this.prompt = '',
    required this.maxPoints,
    this.selectedIndex,
    this.options = const [],
    this.correctIndex,
    this.textAnswer = const [],
    this.keyPointOutcomes = const [],
    this.pointsAwarded,
    this.graded = false,
    this.feedback,
    this.xpEarned = 0,
  });

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
        prompt: prompt,
        maxPoints: maxPoints,
        selectedIndex: selectedIndex,
        options: options,
        correctIndex: correctIndex,
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
        prompt: m['prompt'] ?? '',
        maxPoints: (m['maxPoints'] as num?)?.toInt() ?? 0,
        selectedIndex: (m['selectedIndex'] as num?)?.toInt(),
        options: List<String>.from(m['options'] ?? const []),
        correctIndex: (m['correctIndex'] as num?)?.toInt(),
        textAnswer: List<String>.from(m['textAnswer'] ?? const []),
        keyPointOutcomes: (m['keyPointOutcomes'] as List<dynamic>? ?? const [])
            .map((k) => KeyPointOutcome.fromMap(Map<String, dynamic>.from(k)))
            .toList(),
        pointsAwarded: (m['pointsAwarded'] as num?)?.toInt(),
        graded: m['graded'] ?? false,
        feedback: m['feedback'],
        xpEarned: (m['xpEarned'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'questionId': questionId,
        'type': type.name,
        'prompt': prompt,
        'maxPoints': maxPoints,
        'selectedIndex': selectedIndex,
        'options': options,
        'correctIndex': correctIndex,
        'textAnswer': textAnswer,
        'keyPointOutcomes': keyPointOutcomes.map((k) => k.toMap()).toList(),
        'pointsAwarded': pointsAwarded,
        'graded': graded,
        'feedback': feedback,
        'xpEarned': xpEarned,
      };

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

  /// Set only when this attempt was launched from a quiz-as-homework
  /// assignment (spec item 4B) — see TestTakingPage/HomeworkPage's
  /// "Take Quiz" action. Lets the server enforce the REAL, per-student
  /// homework deadline (including any extension) at submit time via a
  /// trigger on public.test_attempts, not merely a client-side check —
  /// see supabase/migrations/20260904000008_quiz_homework_expiry_enforcement.sql.
  final String? homeworkId;

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
    this.homeworkId,
  });

  int get gradedPoints =>
      responses.fold(0, (s, r) => s + (r.pointsAwarded ?? 0));

  double get scorePercent => totalPossiblePoints <= 0
      ? 0
      : (gradedPoints / totalPossiblePoints * 100);

  bool get fullyGraded => responses.every((r) => r.graded);
  bool get hasPendingGrading => !fullyGraded;

  factory TestAttempt.fromSupabase(Map<String, dynamic> d) {
    return TestAttempt(
      id: d['id'] as String,
      testId: d['test_id'] ?? '',
      testTitle: d['test_title'] ?? '',
      subject: d['subject'] ?? '',
      difficulty: TestDifficultyExt.fromKey(d['difficulty']),
      userId: d['user_id'] ?? '',
      userName: d['user_name'] ?? '',
      responses: (d['responses'] as List<dynamic>? ?? [])
          .map((r) => QuestionResponse.fromMap(Map<String, dynamic>.from(r)))
          .toList(),
      totalPossiblePoints: (d['total_possible_points'] as num?)?.toInt() ?? 0,
      status: AttemptStatusExt.fromKey(d['status']),
      totalXpAwarded: (d['total_xp_awarded'] as num?)?.toInt() ?? 0,
      submittedAt: DateTime.tryParse(d['submitted_at']?.toString() ?? '') ?? DateTime.now(),
      gradedAt: d['graded_at'] == null ? null : DateTime.tryParse(d['graded_at'].toString()),
      levelMultiplier: (d['level_multiplier'] as num?)?.toDouble() ?? 1.0,
      attemptMultiplier: (d['attempt_multiplier'] as num?)?.toDouble() ?? 1.0,
      homeworkId: d['homework_id']?.toString(),
    );
  }

  Map<String, dynamic> toSupabase() => {
        'test_id': testId.isEmpty ? null : testId,
        'homework_id': homeworkId,
        'test_title': testTitle,
        'subject': subject,
        'difficulty': difficulty.name,
        'user_id': userId.isEmpty ? null : userId,
        'user_name': userName,
        'responses': responses.map((r) => r.toMap()).toList(),
        'total_possible_points': totalPossiblePoints,
        'status': status.name,
        'total_xp_awarded': totalXpAwarded,
        'submitted_at': submittedAt.toIso8601String(),
        'graded_at': gradedAt?.toIso8601String(),
        'level_multiplier': levelMultiplier,
        'attempt_multiplier': attemptMultiplier,
      };
}
