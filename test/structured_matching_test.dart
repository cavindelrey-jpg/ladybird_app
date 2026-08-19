// test/structured_matching_test.dart
// Unit tests for the Structured question's auto-grading path
// (production_plan.md §3 Quiz Type 2 — "Short Answer / Structural").
//
// Unlike Essay, Structured does NOT get its own matcher: the spec asks
// for "compare against the expected answer / use expected answers-key
// points / evaluate automatically where possible", and
// core/essay_matching.dart's matchEssayKeyPoints() was already generic
// lexical matching, not Essay-specific in its logic — so these tests
// exist to pin down the MODEL and XP wiring that make Structured reuse
// that same matcher (TestQuestion.expectedPoints, TestQuestion.maxPoints,
// Test.hasManualGrading, and questionXp()'s Structural base rate), not to
// re-prove the matcher itself — that's already covered end-to-end by
// test/essay_matching_test.dart against the identical function.

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/essay_matching.dart';
import 'package:academia_app/core/xp_rules.dart';
import 'package:academia_app/models/test.dart';
import 'package:academia_app/models/xp_transaction.dart';

EssayKeyPoint ep(String id, String text, {List<String> keywords = const []}) =>
    EssayKeyPoint(id: id, text: text, keywords: keywords);

final mitosisPoints = <EssayKeyPoint>[
  ep('e1', 'Mitosis produces two genetically identical daughter cells'),
  ep('e2', 'The chromosomes line up at the equator during metaphase'),
  ep('e3', 'Sister chromatids separate during anaphase'),
];

void main() {
  group('TestQuestion.maxPoints for Structured', () {
    test('falls back to the author-set points with no expected points', () {
      const q = TestQuestion(
        id: 'q1',
        type: QuestionType.structured,
        prompt: 'Describe photosynthesis',
        points: 12,
        lineCount: 3,
      );
      expect(q.maxPoints, 12);
    });

    test('scores out of the expected-point count once any are authored', () {
      final q = TestQuestion(
        id: 'q1',
        type: QuestionType.structured,
        prompt: 'Describe mitosis',
        points: 12, // deliberately different — must be ignored once expectedPoints exist
        expectedPoints: mitosisPoints,
      );
      expect(q.maxPoints, 3);
    });
  });

  group('Test.hasManualGrading reflects only guaranteed-manual Structured', () {
    test('a Structured question with no expected points needs a human', () {
      final t = Test(
        id: 't1',
        subject: 'Biology',
        title: 'Cell Biology',
        createdBy: 'u1',
        createdAt: DateTime(2026),
        questions: [
          const TestQuestion(
            id: 'q1',
            type: QuestionType.structured,
            prompt: 'Describe mitosis',
          ),
        ],
      );
      expect(t.hasManualGrading, isTrue);
    });

    test('a Structured question authored with expected points does not',
        () {
      final t = Test(
        id: 't1',
        subject: 'Biology',
        title: 'Cell Biology',
        createdBy: 'u1',
        createdAt: DateTime(2026),
        questions: [
          TestQuestion(
            id: 'q1',
            type: QuestionType.structured,
            prompt: 'Describe mitosis',
            expectedPoints: mitosisPoints,
          ),
        ],
      );
      expect(t.hasManualGrading, isFalse);
      expect(t.hasAutoGradedStructuredQuestions, isTrue);
    });

    test('a pure-MCQ test needs no manual grading at all', () {
      final t = Test(
        id: 't1',
        subject: 'Biology',
        title: 'Quick Quiz',
        createdBy: 'u1',
        createdAt: DateTime(2026),
        questions: [
          const TestQuestion(
            id: 'q1',
            type: QuestionType.mcq,
            prompt: 'Water is H2O?',
            options: ['True', 'False'],
            correctIndex: 0,
          ),
        ],
      );
      expect(t.hasManualGrading, isFalse);
      expect(t.hasAutoGradedStructuredQuestions, isFalse);
    });
  });

  group('the shared matcher grades Structured the same way it grades Essay',
      () {
    test('a confidently-matched Structured answer needs no human review',
        () {
      final result = matchEssayKeyPoints(
        keyPoints: mitosisPoints,
        studentPoints: [
          'Mitosis produces two genetically identical daughter cells',
          'Chromosomes line up at the equator during metaphase',
          'Sister chromatids separate during anaphase',
        ],
      );
      expect(result.capturedCount, 3);
      expect(result.needsHumanReview, isFalse);
    });

    test('a partial/ambiguous Structured point is routed to a human, not '
        'guessed', () {
      final result = matchEssayKeyPoints(
        keyPoints: [
          ep('e1', 'Sister chromatids separate during anaphase'),
        ],
        // Shares 'chromatid'/'separate' with the expected point (2 of its
        // 5 content tokens) but not enough of the rest to be a confident
        // capture — deliberately in the matcher's refuse-to-guess band.
        studentPoints: ['chromatids separate apart from each other'],
      );
      expect(result.matches.single.verdict, KeyPointVerdict.uncertain);
      expect(result.needsHumanReview, isTrue);
    });
  });

  // The Structured score must feed the SAME XP machinery as every other
  // format rather than a parallel path: "captured 2 of 3 expected points"
  // is simply pointsAwarded=2, maxPoints=3 through questionXp(), anchored
  // on the Structural base rate (30 XP, production_plan.md §3), not a
  // bespoke calculation.
  group('Structured score feeds the existing XP machinery', () {
    test('Structured XP anchors on the plan\'s 30 base rate', () {
      expect(xpSourceForQuestionType(QuestionType.structured),
          XpSource.structural);
      expect(XpSource.structural.baseXp, 30);
    });

    test('capturing 2 of 3 expected points earns the 2/3 share of the rate',
        () {
      final xp = questionXp(
        type: QuestionType.structured,
        pointsAwarded: 2,
        maxPoints: 3,
        difficulty: TestDifficulty.medium,
        levelMultiplier: 1.0,
      );
      // 30 base * 115% medium difficulty * (2/3) = 23.0 -> 23
      expect(xp, 23);
    });

    test('capturing every point earns strictly more than capturing some',
        () {
      int xpFor(int captured) => questionXp(
            type: QuestionType.structured,
            pointsAwarded: captured,
            maxPoints: 3,
            difficulty: TestDifficulty.hard,
            levelMultiplier: kSeniorSecondaryMultiplier,
          );
      expect(xpFor(3), greaterThan(xpFor(2)));
      expect(xpFor(2), greaterThan(xpFor(0)));
      expect(xpFor(0), 0);
    });

    test(
        'a Structured question with no expected points still scores through '
        'its own author-set points, unaffected by the key-point machinery',
        () {
      final xp = questionXp(
        type: QuestionType.structured,
        pointsAwarded: 7,
        maxPoints: 10, // the author-set `points`, since expectedPoints is empty
        difficulty: TestDifficulty.easy,
        levelMultiplier: 1.0,
      );
      // 30 base * 100% easy * (7/10) = 21
      expect(xp, 21);
    });
  });
}
