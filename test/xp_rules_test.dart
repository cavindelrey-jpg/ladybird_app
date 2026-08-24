// test/xp_rules_test.dart
// Exhaustive tests for lib/core/xp_rules.dart -- every function here is
// pure (no Firestore, no widgets), so this is written as strict
// input/output contract tests: normal cases, every boundary, and
// adversarial/malformed input, per the "attack the code" testing brief.
// This file previously had zero coverage despite computing the entire
// XP economy (quiz rewards, streak bonuses, level curve, past-paper
// pricing).

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/core/xp_rules.dart';
import 'package:academia_app/models/test.dart';
import 'package:academia_app/models/xp_transaction.dart';

void main() {
  group('difficultyMultiplierPercent', () {
    test('easy is 100%, medium 115%, hard 130%', () {
      expect(difficultyMultiplierPercent(TestDifficulty.easy), 100);
      expect(difficultyMultiplierPercent(TestDifficulty.medium), 115);
      expect(difficultyMultiplierPercent(TestDifficulty.hard), 130);
    });
  });

  group('academicTierFor', () {
    test('Form 1-3 map to juniorSecondary', () {
      for (final f in ['Form 1', 'Form 2', 'Form 3']) {
        expect(academicTierFor(f), AcademicTier.juniorSecondary, reason: f);
      }
    });

    test('Form 4-5 map to seniorSecondary', () {
      for (final f in ['Form 4', 'Form 5']) {
        expect(academicTierFor(f), AcademicTier.seniorSecondary, reason: f);
      }
    });

    test('Sixth form, University, and adult-learner labels map to advanced', () {
      for (final f in [
        'Lower Sixth Arts', 'Lower Sixth Science',
        'Upper Sixth Arts', 'Upper Sixth Science',
        'University', 'Professional / Working Adult',
        'Independent Learner', 'Other',
      ]) {
        expect(academicTierFor(f), AcademicTier.advanced, reason: f);
      }
    });

    test('unrecognized value falls back to the lowest tier, not the highest', () {
      expect(academicTierFor('Nonsense Value'), AcademicTier.juniorSecondary);
    });

    test('empty string falls back to the lowest tier', () {
      expect(academicTierFor(''), AcademicTier.juniorSecondary);
    });

    test('is case- and whitespace-sensitive -- a mismatched "Form 4" silently '
        'falls back to the LOWEST tier instead of its real (higher) tier', () {
      // 'Form 4' canonically maps to seniorSecondary -- using it (rather
      // than a Form-1-family string, which maps to juniorSecondary either
      // way) actually proves the fallback is happening, not coincidence.
      expect(academicTierFor('Form 4'), AcademicTier.seniorSecondary); // sanity check
      expect(academicTierFor('form 4'), AcademicTier.juniorSecondary); // silently wrong tier
      expect(academicTierFor(' Form 4'), AcademicTier.juniorSecondary);
      expect(academicTierFor('Form 4 '), AcademicTier.juniorSecondary);
    });
  });

  group('academicLevelMultiplier', () {
    test('matches the tier multipliers exactly', () {
      expect(academicLevelMultiplier('Form 1'), 1.0);
      expect(academicLevelMultiplier('Form 4'), 1.6);
      expect(academicLevelMultiplier('University'), 2.2);
    });
  });

  group('quizDailyXpCapForLevel', () {
    test('returns the per-level cap when it is below the overall cap', () {
      expect(quizDailyXpCapForLevel('Form 1'), 120);
      expect(quizDailyXpCapForLevel('Form 4'), 160);
      expect(quizDailyXpCapForLevel('University'), 200);
    });

    test('never exceeds the overall 280 ceiling even for an unrecognized level', () {
      expect(quizDailyXpCapForLevel('garbage'), lessThanOrEqualTo(280));
    });
  });

  group('pastPaperPriceForContentLevel', () {
    test('prices each content level tier correctly', () {
      expect(pastPaperPriceForContentLevel('Form 1'), 90);
      expect(pastPaperPriceForContentLevel('Form 5'), 200);
      expect(pastPaperPriceForContentLevel('Upper Sixth'), 360);
      expect(pastPaperPriceForContentLevel('Undergraduate'), 360);
    });

    test('"All Levels" and unrecognized values fall back to the CHEAPEST tier '
        '(under-charging, not over-charging, is the safe default)', () {
      expect(pastPaperPriceForContentLevel('All Levels'), 90);
      expect(pastPaperPriceForContentLevel(''), 90);
      expect(pastPaperPriceForContentLevel('nonsense'), 90);
    });
  });

  group('pastPaperPackPriceForContentLevel', () {
    test('is exactly 1.8x the single-paper price, rounded', () {
      expect(pastPaperPackPriceForContentLevel('Form 1'), 162); // 90*1.8
      expect(pastPaperPackPriceForContentLevel('Form 5'), 360); // 200*1.8
      expect(pastPaperPackPriceForContentLevel('Upper Sixth'), 648); // 360*1.8
    });
  });

  group('xpSourceForQuestionType', () {
    test('maps every question type to its own XP source', () {
      expect(xpSourceForQuestionType(QuestionType.mcq), XpSource.mcq);
      expect(xpSourceForQuestionType(QuestionType.structured), XpSource.structural);
      expect(xpSourceForQuestionType(QuestionType.longForm), XpSource.ac);
    });
  });

  group('questionXp', () {
    test('full marks, easy, junior-secondary MCQ earns exactly the base rate', () {
      final xp = questionXp(
        type: QuestionType.mcq, pointsAwarded: 10, maxPoints: 10,
        difficulty: TestDifficulty.easy, levelMultiplier: 1.0,
      );
      expect(xp, 15); // XpSource.mcq.baseXp
    });

    test('zero correct answers earns zero XP even at max difficulty/level', () {
      final xp = questionXp(
        type: QuestionType.longForm, pointsAwarded: 0, maxPoints: 40,
        difficulty: TestDifficulty.hard, levelMultiplier: 2.2,
      );
      expect(xp, 0);
    });

    test('maxPoints <= 0 returns 0 rather than dividing by zero', () {
      expect(questionXp(type: QuestionType.mcq, pointsAwarded: 0, maxPoints: 0,
          difficulty: TestDifficulty.easy, levelMultiplier: 1.0), 0);
      expect(questionXp(type: QuestionType.mcq, pointsAwarded: 5, maxPoints: -3,
          difficulty: TestDifficulty.easy, levelMultiplier: 1.0), 0);
    });

    test('pointsAwarded above maxPoints is clamped, not over-counted '
        '(defends a grading bug elsewhere from paying out >100%)', () {
      final overAwarded = questionXp(
        type: QuestionType.mcq, pointsAwarded: 999, maxPoints: 10,
        difficulty: TestDifficulty.easy, levelMultiplier: 1.0,
      );
      final fullMarks = questionXp(
        type: QuestionType.mcq, pointsAwarded: 10, maxPoints: 10,
        difficulty: TestDifficulty.easy, levelMultiplier: 1.0,
      );
      expect(overAwarded, fullMarks);
    });

    test('negative pointsAwarded is clamped to zero, not negative XP', () {
      final xp = questionXp(
        type: QuestionType.mcq, pointsAwarded: -5, maxPoints: 10,
        difficulty: TestDifficulty.easy, levelMultiplier: 1.0,
      );
      expect(xp, 0);
    });

    test('difficulty and level multipliers compound correctly '
        '(hard + advanced structured, full marks)', () {
      // base(30) * 130% * (10/10 ratio) * 2.2 = 85.8 -> rounds to 86
      final xp = questionXp(
        type: QuestionType.structured, pointsAwarded: 10, maxPoints: 10,
        difficulty: TestDifficulty.hard, levelMultiplier: 2.2,
      );
      expect(xp, 86);
    });

    test('partial credit scales proportionally', () {
      // base(55, longForm) * 100% (easy) * (5/20 ratio=0.25) * 1.0 = 13.75 -> 14
      final xp = questionXp(
        type: QuestionType.longForm, pointsAwarded: 5, maxPoints: 20,
        difficulty: TestDifficulty.easy, levelMultiplier: 1.0,
      );
      expect(xp, 14);
    });

    test('KNOWN GAP: a negative levelMultiplier is not rejected and produces '
        'negative XP -- downstream XpRepository.awardXp() treats any '
        'rawAmount <= 0 as a no-op, which is the only thing currently '
        'preventing this from being harmful. Documents the actual '
        'behavior so a future refactor of the guard does not silently '
        'reopen this.', () {
      final xp = questionXp(
        type: QuestionType.mcq, pointsAwarded: 10, maxPoints: 10,
        difficulty: TestDifficulty.easy, levelMultiplier: -1.0,
      );
      expect(xp, lessThan(0));
    });
  });

  group('baseXpAtLevel', () {
    test('scales the flat base rate by the level multiplier only', () {
      expect(baseXpAtLevel(QuestionType.mcq, 1.0), 15);
      expect(baseXpAtLevel(QuestionType.mcq, 1.6), 24); // 15*1.6=24.0
      expect(baseXpAtLevel(QuestionType.longForm, 2.2), 121); // 55*2.2=121.0
    });
  });

  group('minimumCompletionFloor', () {
    test('empty question list floors to zero', () {
      expect(minimumCompletionFloor(const [], 1.0), 0);
    });

    test('is 25% of the summed base XP across every answered question type', () {
      // 3 MCQ questions at level 1.0: base total = 15*3 = 45; floor = 25% = 11.25 -> 11
      final floor = minimumCompletionFloor(
        const [QuestionType.mcq, QuestionType.mcq, QuestionType.mcq], 1.0,
      );
      expect(floor, 11);
    });

    test('mixed question types sum their own base rates before flooring', () {
      // mcq(15) + structured(30) + ac(55) = 100 at level 1.0; 25% = 25
      final floor = minimumCompletionFloor(
        const [QuestionType.mcq, QuestionType.structured, QuestionType.longForm], 1.0,
      );
      expect(floor, 25);
    });

    test('a single-element list still computes correctly', () {
      expect(minimumCompletionFloor(const [QuestionType.mcq], 1.0), 4); // 15*0.25=3.75->4
    });

    test('a very large question list does not throw or overflow', () {
      final many = List.filled(5000, QuestionType.mcq);
      expect(() => minimumCompletionFloor(many, 1.0), returnsNormally);
      expect(minimumCompletionFloor(many, 1.0), (15 * 5000 * 0.25).round());
    });
  });

  group('attemptCooldownMultiplier', () {
    test('first attempt (zero prior) earns full rate', () {
      expect(attemptCooldownMultiplier(0), 1.0);
    });

    test('negative prior-attempt count is treated as no prior attempts, '
        'not rejected -- defensive default for a value that should never '
        'legitimately be negative', () {
      expect(attemptCooldownMultiplier(-1), 1.0);
      expect(attemptCooldownMultiplier(-1000), 1.0);
    });

    test('exactly one prior attempt dampens to 40%', () {
      expect(attemptCooldownMultiplier(1), 0.4);
    });

    test('two or more prior attempts in the window earns zero', () {
      expect(attemptCooldownMultiplier(2), 0.0);
      expect(attemptCooldownMultiplier(3), 0.0);
      expect(attemptCooldownMultiplier(1000), 0.0);
    });
  });

  group('completionBonusXp', () {
    test('below the minimum score threshold earns no bonus', () {
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 39.9), 0);
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 0), 0);
    });

    test('exactly at the minimum threshold (40%) DOES earn the lowest-tier bonus '
        '-- the threshold is inclusive', () {
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 40.0), 5);
    });

    test('zero XP earned so far means no bonus even at a perfect score '
        '(nothing to take a percentage of)', () {
      expect(completionBonusXp(totalQuestionXpEarned: 0, scorePercent: 100), 0);
    });

    test('negative totalQuestionXpEarned is treated as "nothing earned"', () {
      expect(completionBonusXp(totalQuestionXpEarned: -50, scorePercent: 100), 0);
    });

    test('each score tier boundary uses the correct multiplier', () {
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 40), 5);
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 59.9), 5);
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 60), 15);
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 79.9), 15);
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 80), 30);
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 99.9), 30);
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 100), 50);
    });

    test('a score above 100% (should never happen, but not validated) '
        'is still treated as the top tier rather than throwing', () {
      expect(completionBonusXp(totalQuestionXpEarned: 100, scorePercent: 150), 50);
    });

    test('KNOWN GAP: NaN scorePercent silently falls through every '
        'comparison (IEEE754: all comparisons with NaN are false) and '
        'lands in the lowest bonus tier instead of being rejected. A '
        'score of NaN can only occur from a 0/0 division upstream, but '
        'if that ever happens this pays out a bonus instead of erroring.', () {
      final bonus = completionBonusXp(totalQuestionXpEarned: 100, scorePercent: double.nan);
      // Documents the actual (surprising) current behavior.
      expect(bonus, 5, reason:
          'NaN bypasses the `< kMinScoreForBonus` guard AND every `>=` tier '
          'check, falling through to the 40-59%% (0.05x) tier by accident.');
    });
  });

  group('streakMilestoneBonusXp', () {
    test('non-milestone days earn nothing', () {
      for (final d in [1, 2, 3, 5, 6, 8, 13, 15, 20]) {
        expect(streakMilestoneBonusXp(d), 0, reason: 'day $d');
      }
    });

    test('day zero and negative streaks earn nothing', () {
      expect(streakMilestoneBonusXp(0), 0);
      expect(streakMilestoneBonusXp(-7), 0);
    });

    test('every 7-day milestone grows linearly: 7->50, 14->100, 21->150, 28->200', () {
      expect(streakMilestoneBonusXp(7), 50);
      expect(streakMilestoneBonusXp(14), 100);
      expect(streakMilestoneBonusXp(21), 150);
      expect(streakMilestoneBonusXp(28), 200);
    });

    test('the formula never runs out for an extremely long streak', () {
      expect(streakMilestoneBonusXp(7000), 50000); // 1000 weeks
    });
  });

  group('xpRequiredForLevel', () {
    test('level 1 requires zero XP', () {
      expect(xpRequiredForLevel(1), 0);
    });

    test('level 0 and negative levels also floor to zero, not negative', () {
      expect(xpRequiredForLevel(0), 0);
      expect(xpRequiredForLevel(-5), 0);
    });

    test('matches the documented curve for the first several levels', () {
      expect(xpRequiredForLevel(2), 100);
      expect(xpRequiredForLevel(3), 300);
      expect(xpRequiredForLevel(4), 600);
      expect(xpRequiredForLevel(5), 1000);
    });

    test('is strictly increasing -- every level costs more than the last', () {
      var prev = xpRequiredForLevel(1);
      for (var level = 2; level <= 100; level++) {
        final cur = xpRequiredForLevel(level);
        expect(cur, greaterThan(prev), reason: 'level $level');
        prev = cur;
      }
    });
  });

  group('levelForXp', () {
    test('zero or negative lifetime XP is level 1', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(-100), 1);
    });

    test('one XP short of a level threshold stays at the lower level', () {
      expect(levelForXp(99), 1);   // level 2 needs 100
      expect(levelForXp(299), 2);  // level 3 needs 300
    });

    test('exactly at a level threshold reaches that level, not the one below', () {
      expect(levelForXp(100), 2);
      expect(levelForXp(300), 3);
      expect(levelForXp(600), 4);
    });

    test('one XP past a threshold stays at that level (not the next)', () {
      expect(levelForXp(101), 2);
      expect(levelForXp(301), 3);
    });

    test('round-trips through xpRequiredForLevel for every level up to 200 -- '
        'this is the real correctness property: for every level L, the XP '
        'exactly at its threshold must resolve back to L, and one less '
        'must resolve to L-1', () {
      for (var level = 1; level <= 200; level++) {
        final threshold = xpRequiredForLevel(level);
        expect(levelForXp(threshold), level, reason: 'level $level, threshold $threshold');
        if (level > 1) {
          expect(levelForXp(threshold - 1), level - 1,
              reason: 'level $level threshold - 1');
        }
      }
    });

    test('a very large XP total still resolves correctly and terminates '
        '(the float estimate + integer correction loop must not hang or '
        'drift for large inputs)', () {
      const huge = 50000000; // 50M XP
      final level = levelForXp(huge);
      expect(xpRequiredForLevel(level), lessThanOrEqualTo(huge));
      expect(xpRequiredForLevel(level + 1), greaterThan(huge));
    });
  });

  group('levelProgress', () {
    test('a brand-new account is 0 into level 1, span equal to level 2\'s threshold', () {
      final p = levelProgress(0);
      expect(p.into, 0);
      expect(p.span, 100);
    });

    test('into is always less than span (never shows >100% on a progress bar)', () {
      for (final xp in [0, 1, 99, 100, 101, 299, 300, 5000, 999999]) {
        final p = levelProgress(xp);
        expect(p.into, greaterThanOrEqualTo(0), reason: 'xp=$xp');
        expect(p.into, lessThan(p.span), reason: 'xp=$xp');
      }
    });

    test('into + the level floor reconstructs the original lifetime XP', () {
      const xp = 456;
      final p = levelProgress(xp);
      final level = levelForXp(xp);
      final floor = xpRequiredForLevel(level);
      expect(floor + p.into, xp);
    });
  });
}
