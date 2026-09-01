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
// Every question format auto-grades — see core/essay_matching.dart for
// how structured/long-form answers are matched against [expectedPoints]/
// [keyPoints]. There is no manual-grading path in this app.
//
// Firestore: tests/{testId}
// Questions are embedded (denormalized), not a subcollection — mirrors
// the existing DailyChallenge pattern (models/daily_challenge.dart).
// A test document stays a single read regardless of question count, and
// realistic tests (tens of questions, not thousands) stay well under
// Firestore's 1MB document limit. Scale (per the spec's "thousands of
// tests") comes from having many small `tests` docs, not from splitting
// one test's own questions further.

import 'essay_key_point.dart';
import 'academic_section.dart';

// Re-exported so every file that already imports test.dart for
// TestQuestion/Test (which reference EssayKeyPoint directly) keeps
// getting it too, matching the pre-extraction behavior when
// EssayKeyPoint was defined inline in this file.
export 'essay_key_point.dart';
export 'academic_section.dart' show AcademicSection, kDefaultAcademicSections;

enum QuestionType { mcq, structured, longForm }

extension QuestionTypeExt on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.mcq:        return 'Multiple Choice';
      case QuestionType.structured: return 'Structured';
      case QuestionType.longForm:   return 'Essay';
    }
  }

  static QuestionType fromKey(String? key) {
    // 'long_form' is what the Supabase migration import wrote into
    // existing jsonb rows (snake_case, matching the Postgres question_type
    // enum used elsewhere) — accept both so old and new data parse the same.
    if (key == 'long_form') return QuestionType.longForm;
    return QuestionType.values.firstWhere((t) => t.name == key, orElse: () => QuestionType.mcq);
  }
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
///  - structured: uses [lineCount] (how many ruled answer-lines to render),
///    optional [rubricGuidance] (shown alongside the correction, not used
///    for grading itself), and [expectedPoints] — the key points the
///    answer is auto-graded against (core/essay_matching.dart).
///  - longForm (AC): a single free-text essay box, auto-graded against
///    [keyPoints] the same way as structured's [expectedPoints], just
///    with more of them (7-9 — see kMinEssayKeyPoints/kMaxEssayKeyPoints).
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
  final List<EssayKeyPoint> expectedPoints;

  // Essay (longForm) only
  final List<EssayKeyPoint> keyPoints;

  /// Architecture brief item 9: real photos/diagrams a question can show
  /// or ask the learner to analyse, not emoji decoration. Optional and
  /// type-independent -- any of the three formats can attach one image.
  /// A real Supabase Storage download URL, same pick -> upload -> preview
  /// pattern as every other image attachment in this app.
  final String? imageUrl;

  const TestQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.points = 10,
    this.options = const [],
    this.correctIndex = 0,
    this.lineCount = 4,
    this.rubricGuidance,
    this.expectedPoints = const [],
    this.keyPoints = const [],
    this.imageUrl,
  });

  /// What this question is actually scored out of.
  ///  - Essay: the KEY POINT COUNT — "captured 6 of 9" is the plan's own
  ///    scoring unit, and feeding pointsAwarded=6/maxPoints=9 into
  ///    core/xp_rules.dart's questionXp() gives exactly the ratio the XP
  ///    machinery already expects, with no parallel XP path.
  ///  - Structured WITH [expectedPoints] authored: same reasoning,
  ///    scored out of the expected-point count so an auto-graded
  ///    Structured answer feeds questionXp() the identical way an Essay
  ///    does.
  ///  - mcq, and Structured with no [expectedPoints] (still fully
  ///    human-graded): the author-set [points], unchanged.
  int get maxPoints {
    if (type == QuestionType.longForm) return keyPoints.length;
    if (type == QuestionType.structured && expectedPoints.isNotEmpty) {
      return expectedPoints.length;
    }
    return points;
  }

  factory TestQuestion.fromMap(Map<String, dynamic> m) => TestQuestion(
        id: m['id'] ?? '',
        type: QuestionTypeExt.fromKey(m['type']),
        prompt: m['prompt'] ?? '',
        points: (m['points'] as num?)?.toInt() ?? 10,
        options: List<String>.from(m['options'] ?? const []),
        correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
        lineCount: (m['lineCount'] as num?)?.toInt() ?? 4,
        rubricGuidance: m['rubricGuidance'],
        expectedPoints: (m['expectedPoints'] as List<dynamic>? ?? const [])
            .map((p) => EssayKeyPoint.fromMap(Map<String, dynamic>.from(p)))
            .toList(),
        keyPoints: (m['keyPoints'] as List<dynamic>? ?? const [])
            .map((p) => EssayKeyPoint.fromMap(Map<String, dynamic>.from(p)))
            .toList(),
        imageUrl: m['imageUrl'],
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
        'expectedPoints': expectedPoints.map((p) => p.toMap()).toList(),
        'keyPoints': keyPoints.map((p) => p.toMap()).toList(),
        'imageUrl': imageUrl,
      };
}

/// longForm (AC) key-point count bounds — mirrors
/// academia_compiler/compile-quiz.js's MIN/MAX_ESSAY_KEY_POINTS; keep the
/// two in sync if this range ever changes.
const int kMinEssayKeyPoints = 7;
const int kMaxEssayKeyPoints = 9;

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

  // ── Browse hierarchy (Category > Subject > Topic > this Test) ────────
  // Mirrors PublicCourse's Category/Subject/Level/Topic tree (see
  // public_course.dart) one tier shallower — Quizzes don't have a
  // separate "Level" tier because [category] already IS the education
  // level (Primary School / JSS / SSS / High School / Undergraduate /
  // any admin-added one — see QuizCategory). Both free-text, same
  // "blank = not placed in the tree yet, still reachable other ways"
  // honesty as PublicCourse.hasCurriculumPlacement.

  /// Name of a QuizCategory row (education level) — e.g. "Senior
  /// Secondary School". Free text so it survives a category being
  /// renamed without a foreign-key migration; TestsQuizCategoriesPage
  /// is the source of truth for which names currently exist.
  final String category;

  /// The unit within [subject] this quiz belongs to — e.g. "The French
  /// Revolution". Siblings sharing (category, subject, topic) group
  /// into one tile in TestsTopicPickerPage.
  final String topic;

  /// Optional uploaded photo for this quiz's own tile/card (see
  /// HierarchyAvatar's letter-avatar fallback in widgets.dart — an
  /// image always takes priority over the generated letter when set).
  final String? thumbnailUrl;

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
    this.category = '',
    this.topic = '',
    this.thumbnailUrl,
  });

  int get questionCount => questions.length;
  int get totalPossiblePoints => questions.fold(0, (s, q) => s + q.maxPoints);

  /// Questions GUARANTEED to need a human grader, knowable from the Test
  /// alone (before any student ever attempts it). Essay (longForm) is
  /// never in here: since the key-points redesign every essay is authored
  /// with its 7–9 key points and auto-matched offline
  /// (core/essay_matching.dart), so a human is only ever needed for
  /// specific post-grading-uncertain points — not knowable pre-attempt,
  /// so it can't honestly back a "will need review" promise here (see
  /// [hasEssayQuestions] instead). A Structured question, by contrast,
  /// splits cleanly at author time: one with [TestQuestion.expectedPoints]
  /// authored auto-grades the same way an Essay does (and, same as Essay,
  /// might still flag an individual uncertain point after the fact); one
  /// with none has no expected answer to match against at all and is
  /// ALWAYS fully human-graded, which — unlike Essay's uncertainty — IS
  /// knowable before any attempt exists.
  bool get hasManualGrading => questions.any(
      (q) => q.type == QuestionType.structured && q.expectedPoints.isEmpty);

  /// Contains at least one Essay question — i.e. an attempt on this test
  /// MIGHT route some points to a human for a final call.
  bool get hasEssayQuestions =>
      questions.any((q) => q.type == QuestionType.longForm);

  /// Contains at least one Structured question authored WITH expected
  /// points — i.e. auto-gradable, but (mirroring [hasEssayQuestions])
  /// might still route an individual uncertain point to a human.
  bool get hasAutoGradedStructuredQuestions => questions.any((q) =>
      q.type == QuestionType.structured && q.expectedPoints.isNotEmpty);

  factory Test.fromSupabase(Map<String, dynamic> d) {
    return Test(
      id: d['id'] as String,
      subject: d['subject'] ?? '',
      title: d['title'] ?? 'Untitled Test',
      description: d['description'] ?? '',
      difficulty: TestDifficultyExt.fromKey(d['difficulty']),
      questions: (d['questions'] as List<dynamic>? ?? [])
          .map((q) => TestQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList(),
      createdBy: d['created_by'] ?? '',
      createdByName: d['created_by_name'] ?? '',
      institutionId: d['institution_id'],
      published: d['published'] ?? true,
      createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
      category: d['category'] ?? '',
      topic: d['topic'] ?? '',
      thumbnailUrl: d['thumbnail_url'],
    );
  }

  Map<String, dynamic> toSupabase() => {
        'subject': subject,
        'title': title,
        'description': description,
        'difficulty': difficulty.name,
        'questions': questions.map((q) => q.toMap()).toList(),
        'created_by': createdBy.isEmpty ? null : createdBy,
        'created_by_name': createdByName,
        'institution_id': institutionId,
        'published': published,
        'created_at': createdAt.toIso8601String(),
        'category': category,
        'topic': topic,
        'thumbnail_url': thumbnailUrl,
      };
}

/// The Quiz page's top-level tier — an education level like "Senior
/// Secondary School". Unlike Subject/Topic (free text derived from
/// whatever's on existing Test rows, see PublicCourse's identical choice
/// for its own tree), a category is a real Postgres row: the user asked
/// to be able to add whole new sections (e.g. "Nursery", "Master's") from
/// the Quiz page itself, independent of whether any quiz has been placed
/// under it yet — a derived-string tier can't exist before its first
/// quiz does, a real row can.
///
/// [QuizCategory] is now just this Quiz feature's name for the shared
/// [AcademicSection] model (see models/academic_section.dart) — the same
/// admin-managed section list also drives Course Navigation and the
/// Library, rather than each feature growing its own separate tree of
/// near-identical "Primary School/JSS/SSS/..." rows. Kept as a type
/// alias (not a straight rename) so every existing Quiz call site
/// (QuizCategoriesPage, TestComposerPage, TestRepository, ...) keeps
/// compiling unchanged.
typedef QuizCategory = AcademicSection;

/// Same list as [kDefaultAcademicSections] under this feature's original
/// name — see that constant's doc for what it means.
const kDefaultQuizCategories = kDefaultAcademicSections;

/// Synthetic bucket label for a quiz/topic saved before this hierarchy
/// existed (blank [Test.category]/[Test.topic]) — keeps old content
/// reachable instead of silently vanishing from the new browse tree.
const kUncategorizedQuizBucket = 'Uncategorized';
const kGeneralQuizTopicBucket = 'General';
