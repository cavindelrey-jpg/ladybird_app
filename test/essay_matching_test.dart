// test/essay_matching_test.dart
// Unit tests for the offline Essay key-point matcher
// (lib/core/essay_matching.dart, production_plan.md §3 Quiz Type 3).
//
// These exist because the matcher is the one piece of the Essay flow that
// decides a student's score with no human in the loop — its behaviour
// needs to be pinned down, especially the anti-gaming properties (one
// vague sentence must not capture every point) and the "refuse to guess"
// uncertain band.

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/essay_matching.dart';
import 'package:academia_app/core/xp_rules.dart';
import 'package:academia_app/models/test.dart';
import 'package:academia_app/models/xp_transaction.dart';

EssayKeyPoint kp(String id, String text, {List<String> keywords = const []}) =>
    EssayKeyPoint(id: id, text: text, keywords: keywords);

/// A realistic 7-point essay question, used by most tests below.
final photosynthesisPoints = <EssayKeyPoint>[
  kp('k1', 'Photosynthesis converts light energy into chemical energy'),
  kp('k2', 'Chlorophyll in the chloroplasts absorbs sunlight'),
  kp('k3', 'Carbon dioxide enters the leaf through the stomata'),
  kp('k4', 'Water is absorbed by the roots and transported up the xylem'),
  kp('k5', 'Glucose is produced as the main organic product'),
  kp('k6', 'Oxygen is released as a by-product'),
  kp('k7', 'The rate is affected by temperature and light intensity'),
];

void main() {
  group('normalization and tokenizing', () {
    test('folds case, accents and punctuation', () {
      expect(normalizeEssayText('  Éléments, of THE  cell! '),
          'elements of the cell');
    });

    test('drops stopwords and stems inflections together', () {
      final a = essayTokens('converting energy');
      final b = essayTokens('converts the energy');
      expect(a, b);
    });
  });

  group('confident captures', () {
    test('near-verbatim points are captured without human review', () {
      final result = matchEssayKeyPoints(
        keyPoints: photosynthesisPoints,
        studentPoints: [
          'Photosynthesis converts light energy into chemical energy',
          'Chlorophyll in the chloroplasts absorbs sunlight',
          'Carbon dioxide enters the leaf through the stomata',
          'Water is absorbed by the roots and transported up the xylem',
          'Glucose is produced as the main organic product',
          'Oxygen is released as a by-product',
          'The rate is affected by temperature and light intensity',
        ],
      );
      expect(result.capturedCount, 7);
      expect(result.needsHumanReview, isFalse);
    });

    test('reworded-but-equivalent points still capture', () {
      final result = matchEssayKeyPoints(
        keyPoints: photosynthesisPoints,
        studentPoints: [
          'light energy is converted into chemical energy',
          'sunlight absorbed by chlorophyll inside chloroplasts',
          'carbon dioxide enters through stomata in the leaf',
        ],
      );
      final captured = result.matches
          .where((m) => m.verdict == KeyPointVerdict.captured)
          .map((m) => m.keyPointId)
          .toList();
      expect(captured, containsAll(['k1', 'k2', 'k3']));
    });

    test('tolerates a typo in a long word', () {
      final result = matchEssayKeyPoints(
        keyPoints: [kp('k1', 'Photosynthesis occurs in the chloroplast')],
        studentPoints: ['photosynthesys occurs in the chloroplast'],
      );
      expect(result.matches.single.verdict, KeyPointVerdict.captured);
    });

    test('author keyword aliases rescue different vocabulary', () {
      final points = [
        kp('k1', 'The mitochondrion is the site of aerobic respiration',
            keywords: ['powerhouse of the cell', 'produces ATP']),
      ];
      final withAlias = matchEssayKeyPoints(
        keyPoints: points,
        studentPoints: ['it is the powerhouse of the cell'],
      );
      expect(withAlias.matches.single.verdict, KeyPointVerdict.captured);
    });
  });

  group('confident misses', () {
    test('unrelated answers are missed, not uncertain', () {
      final result = matchEssayKeyPoints(
        keyPoints: photosynthesisPoints,
        studentPoints: [
          'The Berlin conference partitioned Africa in 1884',
          'Cameroon gained independence in 1960',
        ],
      );
      expect(result.capturedCount, 0);
      expect(result.needsHumanReview, isFalse,
          reason: 'clearly-wrong answers should not waste a grader\'s time');
    });

    test('an empty answer misses every point', () {
      final result = matchEssayKeyPoints(
        keyPoints: photosynthesisPoints,
        studentPoints: ['', '   '],
      );
      expect(result.capturedCount, 0);
      expect(result.totalKeyPoints, 7);
      expect(result.matches.every((m) => m.verdict == KeyPointVerdict.missed),
          isTrue);
    });
  });

  group('anti-gaming: one-to-one assignment', () {
    test('the same sentence repeated cannot capture many points', () {
      final repeated = 'light energy is converted into chemical energy';
      final result = matchEssayKeyPoints(
        keyPoints: photosynthesisPoints,
        studentPoints: List.filled(7, repeated),
      );
      expect(result.capturedCount, lessThanOrEqualTo(1),
          reason: 'one idea stated seven times is still one captured point');
    });

    test('a kitchen-sink sentence claims at most one key point', () {
      final result = matchEssayKeyPoints(
        keyPoints: photosynthesisPoints,
        studentPoints: [
          'photosynthesis chlorophyll chloroplast carbon dioxide stomata '
              'water roots xylem glucose oxygen temperature light intensity',
        ],
      );
      expect(result.capturedCount, lessThanOrEqualTo(1),
          reason: 'a single blob of keywords must not sweep the whole answer');
    });

    test('topic words shared by every key point do not part-match all', () {
      // Every key point here contains "energy" — writing only "energy"
      // must not spread credit across the whole question.
      final points = [
        kp('e1', 'Kinetic energy depends on mass and velocity'),
        kp('e2', 'Potential energy depends on height and gravity'),
        kp('e3', 'Energy is conserved in a closed system'),
      ];
      final result = matchEssayKeyPoints(
        keyPoints: points,
        studentPoints: ['energy'],
      );
      expect(result.capturedCount, 0);
    });
  });

  group('the uncertain band', () {
    test('a partial overlap is routed to a human rather than guessed', () {
      final result = matchEssayKeyPoints(
        keyPoints: [
          kp('k1',
              'Water is absorbed by the roots and transported up the xylem'),
        ],
        studentPoints: ['water moves up the plant'],
      );
      final match = result.matches.single;
      expect(match.verdict, KeyPointVerdict.uncertain);
      expect(result.needsHumanReview, isTrue);
      expect(result.bestCaseCount, 1);
      expect(result.capturedCount, 0);
    });

    test('uncertain matches still carry the student wording for the grader',
        () {
      final result = matchEssayKeyPoints(
        keyPoints: [
          kp('k1',
              'Water is absorbed by the roots and transported up the xylem'),
        ],
        studentPoints: ['water moves up the plant'],
      );
      expect(result.matches.single.studentText, 'water moves up the plant');
      expect(result.matches.single.studentPointIndex, 0);
    });
  });

  group('result shape', () {
    test('every authored key point gets exactly one match, in order', () {
      final result = matchEssayKeyPoints(
        keyPoints: photosynthesisPoints,
        studentPoints: ['oxygen is released as a by-product'],
      );
      expect(result.matches.length, photosynthesisPoints.length);
      expect(result.matches.map((m) => m.keyPointId).toList(),
          photosynthesisPoints.map((k) => k.id).toList());
    });

    test('no key points yields an empty, fully-automatic result', () {
      final result =
          matchEssayKeyPoints(keyPoints: const [], studentPoints: ['anything']);
      expect(result.totalKeyPoints, 0);
      expect(result.capturedCount, 0);
      expect(result.needsHumanReview, isFalse);
    });
  });

  // The Essay score must feed the XP machinery that already exists rather
  // than any parallel path: "captured 6 of 9" is simply pointsAwarded=6,
  // maxPoints=9 through the same questionXp() every other format uses.
  group('essay score feeds the existing XP machinery', () {
    test('an Essay question is scored out of its key-point count', () {
      final q = TestQuestion(
        id: 'q1',
        type: QuestionType.longForm,
        prompt: 'Discuss photosynthesis',
        points: 10, // deliberately different — must be ignored for Essay
        keyPoints: photosynthesisPoints,
      );
      expect(q.maxPoints, 7);
    });

    test('Essay XP anchors on the plan\'s 55 base rate', () {
      expect(xpSourceForQuestionType(QuestionType.longForm), XpSource.ac);
      expect(XpSource.ac.baseXp, 55);
    });

    test('capturing 6 of 9 points earns the 6/9 share of the rate', () {
      final xp = questionXp(
        type: QuestionType.longForm,
        pointsAwarded: 6,
        maxPoints: 9,
        difficulty: TestDifficulty.medium,
        levelMultiplier: 1.0,
      );
      // 55 base * 115% medium difficulty * (6/9) = 42.17 -> 42
      expect(xp, 42);
    });

    test('capturing every point earns strictly more than capturing some', () {
      int xpFor(int captured) => questionXp(
            type: QuestionType.longForm,
            pointsAwarded: captured,
            maxPoints: 9,
            difficulty: TestDifficulty.hard,
            levelMultiplier: kSeniorSecondaryMultiplier,
          );
      expect(xpFor(9), greaterThan(xpFor(6)));
      expect(xpFor(6), greaterThan(xpFor(0)));
      expect(xpFor(0), 0);
    });

    test('a malformed Essay with no key points scores 0 rather than throwing',
        () {
      final xp = questionXp(
        type: QuestionType.longForm,
        pointsAwarded: 0,
        maxPoints: 0,
        difficulty: TestDifficulty.easy,
        levelMultiplier: 1.0,
      );
      expect(xp, 0);
    });
  });
}
