// lib/models/test.dart
// Subject-based Testing system — every subject has its own collection of
// Tests (Firestore: top-level `tests/{testId}`, not school-scoped, so the
// same GCE-subject test bank is shared by independent students AND every
// linked school, exactly like PublicCourse — see public_course.dart for
// the same "shared, not per-school" design decision). A school-authored
// test can still be restricted to its own students via [institutionId];
// leaving it null means "everyone studying this subject can take it".
//
// A single Test can mix all three question formats in one attempt — the
// spec's "every test can have three possible question formats" reads as
// "these are the three formats available", not "pick one per test" — so
// TestQuestion is one flexible shape rather than three separate models,
// discriminated by `type`. This keeps grading, scoring, and XP math in
// one place (see core/xp_rules.dart) regardless of the mix.
//
// Firestore: tests/{testId}
// Questions are embedded (denormalized), not a subcollection — mirrors
// the existing DailyChallenge pattern (models/daily_challenge.dart).
// A test document stays a single read regardless of question count, and
// realistic tests (tens of questions, not thousands) stay well under
// Firestore's 1MB document limit. Scale (per the spec's "thousands of
// tests") comes from having many small `tests` docs, not from splitting
// one test's own questions further.

import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestionType { mcq, structured, longForm }

extension QuestionTypeExt on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.mcq:        return 'Multiple Choice';
      case QuestionType.structured: return 'Structured';
      case QuestionType.longForm:   return 'Essay';
    }
  }

  static QuestionType fromKey(String? key) => QuestionType.values
      .firstWhere((t) => t.name == key, orElse: () => QuestionType.mcq);
}

enum TestDifficulty { easy, medium, hard }

extension TestDifficultyExt on TestDifficulty {
  String get label {
    switch (this) {
      case TestDifficulty.easy:   return 'Easy';
      case TestDifficulty.medium: return 'Medium';
      case TestDifficulty.hard:   return 'Hard';
    }
  }

  static TestDifficulty fromKey(String? key) => TestDifficulty.values
      .firstWhere((d) => d.name == key, orElse: () => TestDifficulty.medium);
}

// ── Essay key points (production_plan.md §3, "Quiz Type 3 — Essay") ──────
// The plan is explicit that an Essay question is NOT "type two pages of
// prose into the app". It is: the author names the 7–9 essential points a
// strong answer must contain, the student states the points they'd
// include, and the score is simply how many of those essential points
// they captured. So an Essay question's authored payload is a LIST OF KEY
// POINTS, not a list of prose section headings (which is what the first
// cut of this model shipped — see AUTOPILOT_LOG for the swap).

/// The spec's stated range for "the essential points a strong answer
/// should contain". Enforced in the authoring UI (TestComposerPage), not
/// in this constructor — a malformed document read back from Firestore
/// should still parse rather than throw in a fromMap.
const int kMinEssayKeyPoints = 7;
const int kMaxEssayKeyPoints = 9;

/// One essential point of a strong essay answer. [text] is deliberately a
/// short phrase/sentence ("Photosynthesis converts light energy to
/// chemical energy"), never a paragraph — it is the unit the student's
/// own submitted points get matched against.
///
/// [keywords] are OPTIONAL alternate phrasings the author can add for the
/// same idea ("light reaction", "converts sunlight"). They exist purely
/// to make the offline matcher (core/essay_matching.dart) fairer to a
/// student who used different words for the right idea — each keyword is
/// scored as an ALTERNATIVE to [text], never as an extra requirement on
/// top of it.
class EssayKeyPoint {
  final String id;
  final String text;
  final List<String> keywords;

  const EssayKeyPoint({
    required this.id,
    required this.text,
    this.keywords = const [],
  });

  factory EssayKeyPoint.fromMap(Map<String, dynamic> m) => EssayKeyPoint(
        id: m['id'] ?? '',
        text: m['text'] ?? '',
        keywords: List<String>.from(m['keywords'] ?? const []),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'keywords': keywords,
      };
}

/// One question inside a Test. Which fields are meaningful depends on
/// [type]:
///  - mcq: uses [options] + [correctIndex]. Auto-graded instantly.
///  - structured: uses [lineCount] (how many ruled answer-lines to render)
///    and optional [rubricGuidance] (shown to whoever grades it — human
///    today, an AI grader potentially later; see TestRepository's honest
///    scope note on that).
///  - longForm (the plan's "Essay"): uses [keyPoints] — the 7–9 essential
///    points. Scored out of the NUMBER of key points, not out of [points]
///    (see [maxPoints]), because the plan defines the essay score as
///    "how many essential points the student captured".
class TestQuestion {
  final String id;
  final QuestionType type;
  final String prompt;
  final int points; // max points this question is worth toward the score

  // MCQ only
  final List<String> options;
  final int correctIndex;

  // Structured only
  final int lineCount;
  final String? rubricGuidance;

  // Essay (longForm) only
  final List<EssayKeyPoint> keyPoints;

  const TestQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.points = 10,
    this.options = const [],
    this.correctIndex = 0,
    this.lineCount = 4,
    this.rubricGuidance,
    this.keyPoints = const [],
  });

  /// What this question is actually scored out of. For an Essay this is
  /// the KEY POINT COUNT — "captured 6 of 9" is the plan's own scoring
  /// unit, and feeding pointsAwarded=6/maxPoints=9 into
  /// core/xp_rules.dart's questionXp() gives exactly the ratio the XP
  /// machinery already expects, with no parallel XP path. For mcq and
  /// structured it is the author-set [points], unchanged.
  int get maxPoints =>
      type == QuestionType.longForm ? keyPoints.length : points;

  factory TestQuestion.fromMap(Map<String, dynamic> m) => TestQuestion(
        id: m['id'] ?? '',
        type: QuestionTypeExt.fromKey(m['type']),
        prompt: m['prompt'] ?? '',
        points: (m['points'] as num?)?.toInt() ?? 10,
        options: List<String>.from(m['options'] ?? const []),
        correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
        lineCount: (m['lineCount'] as num?)?.toInt() ?? 4,
        rubricGuidance: m['rubricGuidance'],
        keyPoints: (m['keyPoints'] as List<dynamic>? ?? [])
            .map((k) => EssayKeyPoint.fromMap(Map<String, dynamic>.from(k)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'prompt': prompt,
        'points': points,
        'options': options,
        'correctIndex': correctIndex,
        'lineCount': lineCount,
        'rubricGuidance': rubricGuidance,
        'keyPoints': keyPoints.map((k) => k.toMap()).toList(),
      };
}

class Test {
  final String id;
  final String subject;
  final String title;
  final String description;
  final TestDifficulty difficulty;
  final List<TestQuestion> questions;
  final String createdBy;
  final String createdByName;
  /// Null = open to every student studying this subject, independent or
  /// school-linked. Set = restricted to that one school's students.
  final String? institutionId;
  final bool published;
  final DateTime createdAt;

  const Test({
    required this.id,
    required this.subject,
    required this.title,
    this.description = '',
    this.difficulty = TestDifficulty.medium,
    this.questions = const [],
    required this.createdBy,
    this.createdByName = '',
    this.institutionId,
    this.published = true,
    required this.createdAt,
  });

  int get questionCount => questions.length;
  int get totalPossiblePoints => questions.fold(0, (s, q) => s + q.maxPoints);

  /// Questions that ALWAYS need a human grader. Essay (longForm) is
  /// deliberately NOT in here any more: since the key-points redesign an
  /// essay answer is auto-matched offline (core/essay_matching.dart) and
  /// only reaches the grading queue when the matcher is genuinely
  /// undecided about one of the points — which can't be known before the
  /// student answers. So this stays a promise the UI can actually keep,
  /// rather than warning every essay-taker about a review that usually
  /// won't happen.
  bool get hasManualGrading =>
      questions.any((q) => q.type == QuestionType.structured);

  /// Contains at least one Essay question — i.e. an attempt on this test
  /// MIGHT route some points to a human for a final call.
  bool get hasEssayQuestions =>
      questions.any((q) => q.type == QuestionType.longForm);

  factory Test.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    return Test(
      id: doc.id,
      subject: d['subject'] ?? '',
      title: d['title'] ?? 'Untitled Test',
      description: d['description'] ?? '',
      difficulty: TestDifficultyExt.fromKey(d['difficulty']),
      questions: (d['questions'] as List<dynamic>? ?? [])
          .map((q) => TestQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList(),
      createdBy: d['createdBy'] ?? '',
      createdByName: d['createdByName'] ?? '',
      institutionId: d['institutionId'],
      published: d['published'] ?? true,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'subject': subject,
        'title': title,
        'description': description,
        'difficulty': difficulty.name,
        'questions': questions.map((q) => q.toMap()).toList(),
        'createdBy': createdBy,
        'createdByName': createdByName,
        'institutionId': institutionId,
        'published': published,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
