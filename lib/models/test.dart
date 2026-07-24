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
      case QuestionType.longForm:   return 'Long Form';
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

/// One question inside a Test. Which fields are meaningful depends on
/// [type]:
///  - mcq: uses [options] + [correctIndex]. Auto-graded instantly.
///  - structured: uses [lineCount] (how many ruled answer-lines to render)
///    and optional [rubricGuidance] (shown to whoever grades it — human
///    today, an AI grader potentially later; see TestRepository's honest
///    scope note on that).
///  - longForm: uses [requiredSections] (e.g. Summary / Methodology /
///    Steps, or a theory subject's outline headings) — the answer UI
///    renders one labelled box per section instead of free-form lines.
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

  // Long-form only
  final List<String> requiredSections;

  const TestQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.points = 10,
    this.options = const [],
    this.correctIndex = 0,
    this.lineCount = 4,
    this.rubricGuidance,
    this.requiredSections = const [],
  });

  factory TestQuestion.fromMap(Map<String, dynamic> m) => TestQuestion(
        id: m['id'] ?? '',
        type: QuestionTypeExt.fromKey(m['type']),
        prompt: m['prompt'] ?? '',
        points: (m['points'] as num?)?.toInt() ?? 10,
        options: List<String>.from(m['options'] ?? const []),
        correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
        lineCount: (m['lineCount'] as num?)?.toInt() ?? 4,
        rubricGuidance: m['rubricGuidance'],
        requiredSections: List<String>.from(m['requiredSections'] ?? const []),
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
        'requiredSections': requiredSections,
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
  int get totalPossiblePoints => questions.fold(0, (s, q) => s + q.points);
  bool get hasManualGrading =>
      questions.any((q) => q.type != QuestionType.mcq);

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
