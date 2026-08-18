// lib/core/xp_rules.dart
// Pure XP-calculation rules for the Testing & Quiz system, plus the
// daily-login streak. Deliberately separated from models/xp_transaction.dart
// (which just defines the ledger/enum) so every "how much XP" decision
// lives in one auditable place instead of being scattered across
// TestRepository call sites.
//
// Nothing here talks to Firestore — every function is a pure calculation,
// so it's trivial to unit-test and to tune later without touching any
// repository logic.
//
// ── The four XP rules from the spec, and where each lives ────────────────
//   A1. "Getting correct answers"      -> questionXp() ratio term
//   A2. "Achieving high scores"        -> completionBonusXp() score tiers
//   A3. "Completing difficult tests"   -> difficultyMultiplierPercent()
//   A4. "Completing a test" (itself)   -> completionBonusXp() base award,
//                                          which is > 0 even at the lowest
//                                          scoring tier once kMinScoreForBonus
//                                          is met — see comment there.
//   C.  Daily login / streak milestones -> kStreakDailyXp / streakMilestoneBonusXp()

import 'dart:math';
import '../models/test.dart';
import '../models/xp_transaction.dart';

/// Difficulty multiplier, expressed as a whole-number percentage to avoid
/// floating point drift when compounded with the points ratio below.
/// Modest range on purpose (100–130%) — difficulty rewards effort, it
/// doesn't replace the underlying per-question rates.
int difficultyMultiplierPercent(TestDifficulty difficulty) {
  switch (difficulty) {
    case TestDifficulty.easy:   return 100;
    case TestDifficulty.medium: return 115;
    case TestDifficulty.hard:   return 130;
  }
}

// ── Academic-level XP multiplier (production_plan.md §4.2) ───────────────
// The plan's own worked example ("Senior Secondary Structural: 30 × 80% ×
// 1.6 = 38.4 XP") only shows Base × Correct% × Level — it doesn't mention
// difficulty at all. Rather than silently drop the pre-existing difficulty
// multiplier above (a working feature this plan simply doesn't discuss),
// questionXp() below applies both: the plan's exact level multiplier on
// top of the existing difficulty multiplier. Actual awarded XP for a
// non-easy test will therefore run higher than the plan's own bare
// example — flagging that explicitly as a deliberate choice to preserve a
// working feature rather than a deviation from the spec's core formula.

const double kJuniorSecondaryMultiplier = 1.0;
const double kSeniorSecondaryMultiplier = 1.6;
const double kAdvancedLevelMultiplier = 2.2;

enum AcademicTier { juniorSecondary, seniorSecondary, advanced }

/// Maps [AppUser.educationLevel] (a fixed dropdown list — see
/// EducationLevels.all in models/app_user.dart) to the plan's three-tier
/// classification. Form 1-3 → Junior Secondary; Form 4-5 → Senior
/// Secondary; Lower/Upper Sixth (Cameroon's actual "Advanced Level") →
/// the Advanced tier. University/Professional/Independent Learner/Other
/// don't map to any school form at all — bucketed into the Advanced tier
/// too, on the reasoning that a post-secondary or self-directed learner
/// is tackling at-least-advanced-level material, not that they're
/// literally in Sixth Form. Unrecognized/empty values fall back to the
/// lowest tier rather than the highest — a conservative default so an
/// unset profile field under-rewards instead of over-rewards. Shared by
/// [academicLevelMultiplier] (§4.2's quiz XP multiplier) and
/// [quizDailyXpCapForLevel] (§4.4's daily quiz cap) so the two never
/// drift out of sync with each other.
AcademicTier academicTierFor(String educationLevel) {
  switch (educationLevel) {
    case 'Form 1':
    case 'Form 2':
    case 'Form 3':
      return AcademicTier.juniorSecondary;
    case 'Form 4':
    case 'Form 5':
      return AcademicTier.seniorSecondary;
    case 'Lower Sixth Arts':
    case 'Lower Sixth Science':
    case 'Upper Sixth Arts':
    case 'Upper Sixth Science':
    case 'University':
    case 'Professional / Working Adult':
    case 'Independent Learner':
    case 'Other':
      return AcademicTier.advanced;
    default:
      return AcademicTier.juniorSecondary;
  }
}

double academicLevelMultiplier(String educationLevel) {
  switch (academicTierFor(educationLevel)) {
    case AcademicTier.juniorSecondary: return kJuniorSecondaryMultiplier;
    case AcademicTier.seniorSecondary: return kSeniorSecondaryMultiplier;
    case AcademicTier.advanced:        return kAdvancedLevelMultiplier;
  }
}

// ── Daily quiz XP cap (production_plan.md §4.4) ───────────────────────────

const int kJuniorSecondaryDailyQuizCap = 120;
const int kSeniorSecondaryDailyQuizCap = 160;
const int kAdvancedDailyQuizCap = 200;

/// Overall quiz XP ceiling, authoritative even over a level's own cap
/// (though in practice no level cap above exceeds this anyway — the
/// highest, Advanced's 200, is already below it. Written down because
/// the plan states it as an independent rule, not because it currently
/// changes any actual number.)
const int kOverallDailyQuizXpCap = 280;

/// The plan's §4.4 per-level daily QUIZ XP cap — separate from
/// XpRepository's general kDailyXpCap, which every XP source (quiz,
/// magazine, streak, club) shares. See XpRepository.awardXp() for how
/// quiz sources are additionally metered against this, on top of (not
/// instead of) the general cap.
int quizDailyXpCapForLevel(String educationLevel) {
  final capForLevel = switch (academicTierFor(educationLevel)) {
    AcademicTier.juniorSecondary => kJuniorSecondaryDailyQuizCap,
    AcademicTier.seniorSecondary => kSeniorSecondaryDailyQuizCap,
    AcademicTier.advanced => kAdvancedDailyQuizCap,
  };
  return capForLevel < kOverallDailyQuizXpCap ? capForLevel : kOverallDailyQuizXpCap;
}

// ── Past Paper XP pricing (production_plan.md §4.6/§4.7) ─────────────────
// "A past paper is a past paper" — one fixed price per LEARNER LEVEL,
// regardless of question format/subject/length. Priced by the paper's
// OWN level classification (AcademicContent.level, kAcademicLevels in
// models/academic_content.dart — a different fixed list than
// EducationLevels.all, so this gets its own tier mapping rather than
// reusing academicTierFor()), not the buyer's own educationLevel.

const int kJuniorSecondaryPaperPrice = 90;
const int kSeniorSecondaryPaperPrice = 200;
const int kAdvancedPaperPrice = 360;

/// Multi-paper pack price = 1.8x the fixed single-paper price at the
/// same level (§4.7) — not yet wired to a real "pack" purchase flow
/// anywhere in the app (no grouping of past papers into a purchasable
/// bundle exists in the content model yet), but the pricing rule itself
/// is ready for when that UI is built.
const double kPastPaperPackMultiplier = 1.8;

/// Maps a past paper's own AcademicContent.level (kAcademicLevels: Form
/// 1-5, Lower/Upper Sixth, Undergraduate, or the level-agnostic "All
/// Levels" catch-all) to its fixed price. Unlike the XP-reward tier
/// defaults elsewhere in this file (which fall back to the LOWEST tier
/// to under-reward on ambiguity), an unrecognized/"All Levels" paper
/// price also falls back to the cheapest tier — here that's the safe
/// default in the opposite direction: under-charging a student is the
/// harmless failure mode, over-charging isn't.
int pastPaperPriceForContentLevel(String level) {
  switch (level) {
    case 'Form 1':
    case 'Form 2':
    case 'Form 3':
      return kJuniorSecondaryPaperPrice;
    case 'Form 4':
    case 'Form 5':
      return kSeniorSecondaryPaperPrice;
    case 'Lower Sixth':
    case 'Upper Sixth':
    case 'Undergraduate':
      return kAdvancedPaperPrice;
    default:
      return kJuniorSecondaryPaperPrice;
  }
}

int pastPaperPackPriceForContentLevel(String level) =>
    (pastPaperPriceForContentLevel(level) * kPastPaperPackMultiplier).round();

/// Maps a question's format to the XP source whose flat `baseXp` rate
/// (MCQ 15 / Structural 30 / Essay 55 — production_plan.md §4.2, live in
/// xp_transaction.dart) anchors this question's XP. The comment here used
/// to quote 10 / 25 / 45, which were the pre-§4.2 rates; the code was
/// already correct, only this note was stale.
XpSource xpSourceForQuestionType(QuestionType type) {
  switch (type) {
    case QuestionType.mcq:        return XpSource.mcq;
    case QuestionType.structured: return XpSource.structural;
    case QuestionType.longForm:   return XpSource.ac;
  }
}

/// XP for ONE graded question. [pointsAwarded]/[maxPoints] is the
/// correctness ratio (1.0 for a fully-correct MCQ; a fraction for a
/// partially-credited structured/long-form answer). The question's own
/// point-weight never changes the *rate* — only how much of that flat
/// rate the person actually earned — so a 40-point question isn't worth
/// more XP than a 10-point question of the same format and correctness.
///
/// Returns 0 for a malformed question (maxPoints <= 0) rather than
/// throwing — grading UI should prevent this case, but XP math should
/// never crash a submission.
int questionXp({
  required QuestionType type,
  required int pointsAwarded,
  required int maxPoints,
  required TestDifficulty difficulty,
  required double levelMultiplier,
}) {
  if (maxPoints <= 0) return 0;
  final ratio = pointsAwarded.clamp(0, maxPoints) / maxPoints;
  final base = xpSourceForQuestionType(type).baseXp;
  final withDifficulty = base * difficultyMultiplierPercent(difficulty) / 100;
  return (withDifficulty * ratio * levelMultiplier).round();
}

/// A single question's Base XP scaled by [levelMultiplier] only (no
/// difficulty, no correctness ratio) — the unit production_plan.md §4.2's
/// minimum-completion-reward is 25% of. Used to compute the floor an
/// attempt's total XP must reach; see [minimumCompletionFloor].
int baseXpAtLevel(QuestionType type, double levelMultiplier) =>
    (xpSourceForQuestionType(type).baseXp * levelMultiplier).round();

/// production_plan.md §4.2: "A completed quiz must provide a minimum
/// reward even when the student's score is very low — 25% of Base XP."
/// Applied once per fully-graded ATTEMPT (not per question) — same
/// altitude as [completionBonusXp] below, and the only reading that
/// doesn't create a farm-by-skipping incentive (a per-question floor
/// would pay out for blank/skipped answers too). [answeredQuestionTypes]
/// should list every question the test actually contains (their base
/// rate at the student's level is what the 25% floor is computed
/// against), regardless of how they scored.
int minimumCompletionFloor(List<QuestionType> answeredQuestionTypes, double levelMultiplier) {
  if (answeredQuestionTypes.isEmpty) return 0;
  final totalBaseAtLevel = answeredQuestionTypes
      .map((t) => baseXpAtLevel(t, levelMultiplier))
      .fold(0, (a, b) => a + b);
  return (totalBaseAtLevel * 0.25).round();
}

// ── Attempt-cooldown dampening (production_plan.md §4.3) ─────────────────
// "The same quiz cannot be used as an unlimited XP farm." Applies to the
// SAME test, per user, within a rolling window — not a global per-user
// limit, so retaking a *different* test at full rate is unaffected.

const Duration kAttemptCooldownWindow = Duration(hours: 72);

/// [priorAttemptsInWindow] = how many times this user already attempted
/// THIS SAME test within the last [kAttemptCooldownWindow], not counting
/// the attempt being scored right now.
double attemptCooldownMultiplier(int priorAttemptsInWindow) {
  if (priorAttemptsInWindow <= 0) return 1.0;   // first eligible attempt
  if (priorAttemptsInWindow == 1) return 0.4;   // second attempt within window
  return 0.0;                                   // third+ within window
}

/// Minimum score percentage for ANY completion bonus. Below this, the
/// person still keeps every per-question XP they earned (rule A1) — they
/// just don't get the extra "you finished well" bonus (rule A2/A4).
const double kMinScoreForBonus = 40.0;

/// Completion bonus — awarded once, when a test attempt becomes fully
/// graded (instantly for pure-MCQ tests; after the last manual grade for
/// tests with structured/long-form questions). Computed as a percentage
/// of the XP the person already earned from correct/graded answers on
/// THIS attempt, so it scales naturally with both the test's difficulty
/// (already baked into [totalQuestionXpEarned]) and the person's score.
///
/// Tiers are deliberately coarse (not a smooth curve) so the UI can show
/// a clear "Score 80%+ for a bigger finish bonus" goal rather than an
/// opaque formula.
int completionBonusXp({
  required int totalQuestionXpEarned,
  required double scorePercent,
}) {
  if (scorePercent < kMinScoreForBonus || totalQuestionXpEarned <= 0) return 0;
  double mult;
  if (scorePercent >= 100)      mult = 0.50;
  else if (scorePercent >= 80)  mult = 0.30;
  else if (scorePercent >= 60)  mult = 0.15;
  else                          mult = 0.05; // 40–59%: still "completed", small thank-you
  return (totalQuestionXpEarned * mult).round();
}

// ── Daily login / usage streak ────────────────────────────────────────────

/// Flat XP for showing up on a genuinely new calendar day. Small on
/// purpose — this rewards consistency, not attention; the real earning
/// still comes from tests and magazine reads. Awarded at most once per
/// day (see AuthService.recordDailyActivity's existing same-day guard).
const int kStreakDailyXp = 5;

/// Bonus XP on every 7th consecutive day, growing with each milestone
/// ("continue with increasing milestone rewards" — spec). Returns 0 on
/// non-milestone days. Formula, not a lookup table, so it never runs out
/// no matter how long a streak gets: 7d→50, 14d→100, 21d→150, 28d→200 …
int streakMilestoneBonusXp(int streakDays) {
  if (streakDays <= 0 || streakDays % 7 != 0) return 0;
  final weekNumber = streakDays ~/ 7;
  return 50 * weekNumber;
}

// ── Level curve ────────────────────────────────────────────────────────
// Formula-based, not a hardcoded per-level table — so it scales to any
// lifetime XP without a lookup array that eventually runs out (and
// without a maintainer needing to hand-author level 200's threshold).
// Requirement to go from level L to L+1 is `100 * L` XP, so early levels
// come quickly and later ones take progressively longer — a standard
// "levelling curve" shape.

/// Total lifetime XP required to REACH [level] (level 1 = 0 XP).
int xpRequiredForLevel(int level) {
  if (level <= 1) return 0;
  // Sum of 100*1 + 100*2 + ... + 100*(level-1) = 100 * n(n-1)/2
  final n = level - 1;
  return 100 * n * (n + 1) ~/ 2;
}

/// Current level for a given lifetime XP total (never decreases, since
/// lifetimeXP itself never decreases — see XpRepository).
int levelForXp(int lifetimeXp) {
  if (lifetimeXp <= 0) return 1;
  // xpRequiredForLevel(L) = 50*(L-1)*L, so L solves the quadratic
  // 50L² - 50L - lifetimeXp = 0 → L = (1 + sqrt(1 + 0.08*lifetimeXp)) / 2.
  // Used as a fast starting estimate (avoids an unbounded loop for large
  // XP totals) then corrected with the exact integer formula below, since
  // floating-point sqrt can land just under/over an exact level-up
  // boundary — the correction loop runs at most once or twice in
  // practice, not once per level.
  var level = ((1 + sqrt(1 + 0.08 * lifetimeXp)) / 2).floor();
  if (level < 1) level = 1;
  while (xpRequiredForLevel(level + 1) <= lifetimeXp) {
    level++;
  }
  while (level > 1 && xpRequiredForLevel(level) > lifetimeXp) {
    level--;
  }
  return level;
}

/// (xp earned within the current level, xp needed to reach the next
/// level) — everything a progress bar needs, in one call.
({int into, int span}) levelProgress(int lifetimeXp) {
  final level = levelForXp(lifetimeXp);
  final floor = xpRequiredForLevel(level);
  final ceil = xpRequiredForLevel(level + 1);
  return (into: lifetimeXp - floor, span: ceil - floor);
}
