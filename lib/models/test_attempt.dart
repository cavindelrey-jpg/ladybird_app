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
//   - structured/longForm responses start ungraded (pointsAwarded: null,
//     graded: false) and wait for TestRepository.gradeResponse(), called
//     today by a lecturer/admin from the grading queue. That method is
//     the seam an AI grader would plug into later (call it with a
//     model-suggested score instead of a human-typed one) — nothing
//     about the data model or XP math changes if the grader on the other
//     end becomes automated, which is the "future AI evaluation" the
//     spec asks to leave room for. No AI grading call is wired up yet —
//     flagging that honestly rather than pretending it's live.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'test.dart';

enum AttemptStatus { submitted, graded }

extension AttemptStatusExt on AttemptStatus {
  static AttemptStatus fromKey(String? key) => key == 'graded'
      ? AttemptStatus.graded
      : AttemptStatus.submitted;
}

class QuestionResponse {
  final String questionId;
  final QuestionType type;
  final int maxPoints;

  // mcq
  final int? selectedIndex;

  // structured / longForm — raw text, one entry per line (structured) or
  // per required section (longForm), same order as the question defined.
  final List<String> textAnswer;

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
  }) =>
      QuestionResponse(
        questionId: questionId,
        type: type,
        maxPoints: maxPoints,
        selectedIndex: selectedIndex,
        textAnswer: textAnswer,
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
