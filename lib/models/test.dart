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
import 'academic_section.dart';

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
///  - structured (production_plan.md §3, "Quiz Type 2 — Short Answer /
///    Structural"): uses [lineCount] (how many ruled answer-lines to
///    render), optional [expectedPoints] — the author's expected
///    answer/key points, SAME shape as an Essay's [EssayKeyPoint] and
///    matched the same way by core/essay_matching.dart — and optional
///    [rubricGuidance] (free-text guidance shown to whoever grades it).
///    Unlike Essay, the spec does not mandate a point count for
///    Structural, so [expectedPoints] is genuinely optional: a question
///    authored WITH expected points auto-grades (mirrors Essay exactly,
///    including routing individually-uncertain points to a human); a
///    question authored WITHOUT any (the pre-existing shape, or a
///    genuinely rubric-only question with no discrete expected answer)
///    still goes to a human grader in full, exactly as before.
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
  /// The author's expected answer/key points for a Structured question —
  /// optional (see class doc). Reuses [EssayKeyPoint] rather than a new
  /// type: an expected point is the exact same shape as an essential
  /// essay point (a short phrase plus optional alternate-wording
  /// keywords), and core/essay_matching.dart's matcher is already generic
  /// lexical matching, not Essay-specific in its logic.
  final List<EssayKeyPoint> expectedPoints;

  // Essay (longForm) only
  final List<EssayKeyPoint> keyPoints;

  /// Architecture brief item 9: real photos/diagrams a question can show
  /// or ask the learner to analyse, not emoji decoration. Optional and
  /// type-independent -- any of the three formats can attach one image.
  /// A real Firebase Storage download URL, same pick -> upload -> preview
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
        expectedPoints: (m['expectedPoints'] as List<dynamic>? ?? [])
            .map((k) => EssayKeyPoint.fromMap(Map<String, dynamic>.from(k)))
            .toList(),
        keyPoints: (m['keyPoints'] as List<dynamic>? ?? [])
            .map((k) => EssayKeyPoint.fromMap(Map<String, dynamic>.from(k)))
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
        'imageUrl': imageUrl,
        'expectedPoints': expectedPoints.map((k) => k.toMap()).toList(),
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

  // ── Browse hierarchy (Category > Subject > Topic > this Test) ────────
  // Mirrors PublicCourse's Category/Subject/Level/Topic tree (see
  // public_course.dart) one tier shallower — Quizzes don't have a
  // separate "Level" tier because [category] already IS the education
  // level (Primary School / JSS / SSS / High School / Undergraduate /
  // any admin-added one — see QuizCategory). Both free-text, same
  // "blank = not placed in the tree yet, still reachable other ways"
  // honesty as PublicCourse.hasCurriculumPlacement.

  /// Name of a QuizCategory doc (education level) — e.g. "Senior
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
  /// knowable before any attempt exists. So this flag now means "at least
  /// one Structured question has no expected points authored", not "this
  /// test has structured questions". It still under-promises in one way,
  /// honestly: an expectedPoints-authored Structured or an Essay question
  /// can ALSO land an individual point in the human queue after the
  /// student answers, and that case is deliberately not reflected here for
  /// the same "don't promise a review that usually won't happen" reason
  /// Essay was excluded for.
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
      category: d['category'] ?? '',
      topic: d['topic'] ?? '',
      thumbnailUrl: d['thumbnailUrl'],
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
        'category': category,
        'topic': topic,
        'thumbnailUrl': thumbnailUrl,
      };
}

/// The Quiz page's top-level tier — an education level like "Senior
/// Secondary School". Unlike Subject/Topic (free text derived from
/// whatever's on existing Test docs, see PublicCourse's identical
/// choice for its own tree), a category is a real Firestore doc: the
/// user asked to be able to add whole new sections (e.g. "Nursery",
/// "Master's") from the Quiz page itself, independent of whether any
/// quiz has been placed under it yet — a derived-string tier can't
/// exist before its first quiz does, a real doc can.
///
/// [QuizCategory] is now just this Quiz feature's name for the shared
/// [AcademicSection] model (see models/academic_section.dart) — the same
/// admin-managed section list also drives Course Navigation and the
/// Library, rather than each feature growing its own separate tree of
/// near-identical "Primary School/JSS/SSS/..." docs. Kept as a type
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
