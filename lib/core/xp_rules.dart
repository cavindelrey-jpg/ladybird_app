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

/// Maps a question's format to the XP source whose flat `baseXp` rate
/// (10 / 25 / 45 — decided rates, already live in xp_transaction.dart)
/// anchors this question's XP.
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
}) {
  if (maxPoints <= 0) return 0;
  final ratio = pointsAwarded.clamp(0, maxPoints) / maxPoints;
  final base = xpSourceForQuestionType(type).baseXp;
  final withDifficulty = base * difficultyMultiplierPercent(difficulty) / 100;
  return (withDifficulty * ratio).round();
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
  var level = 1;
  while (xpRequiredForLevel(level + 1) <= lifetimeXp) {
    level++;
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
