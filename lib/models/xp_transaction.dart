// lib/models/xp_transaction.dart
// Backs the platform-wide XP economy. Earn sides, one spendable currency:
//   - Quiz answers (mcq / structural / ac) — tiered so harder answer
//     formats earn faster; a student who only ever does MCQs can still
//     reach any unlock, just slower. See core/xp_rules.dart for how a
//     question's actual XP is derived from these flat rates.
//   - Magazine reads (magazineRead) — an article's AUTHOR earns XP when
//     a genuinely new reader opens their piece. See
//     MagazineRepository.recordRead() for the uniqueness gating that
//     stops this being farmable by just reopening your own article.
//   - Test completion (testCompletion) — a one-time bonus per fully-
//     graded test attempt, on top of the per-question XP above. See
//     core/xp_rules.dart:completionBonusXp().
//   - Streak (streakDaily / streakMilestone) — daily-usage reward. See
//     AuthService.recordDailyActivity() and core/xp_rules.dart.
//
// XP spends on past papers, marking schemes, and full subject bundles —
// a free alternative to the 5,000 FCFA/year Premium subscription (which
// unlocks everything instantly, no grind needed — see AppUser.isPremium).
// XP is never redeemable for real money in either direction; it is a
// closed-loop, platform-internal currency only.
//
// Deliberately NOT in this economy: course creation. Courses are
// team/AI-sourced content, not a student-earn surface — video production
// has too much friction (equipment, time, editing) to be a fair \"any
// student, anywhere\" earn source the way quizzes and writing are, so it
// was scoped out rather than half-built.
//
// Two ledgers per user, both on AppUser itself (models/app_user.dart):
//   xpBalance   — spendable, decreases on unlock
//   lifetimeXP  — never decreases, leaderboard/rank display only, so
//                 spending XP never hurts a student's rank
//
// AppUser.xpTotal is a THIRD, now-deprecated field. It used to be
// written directly by AuthService.addXp() — a parallel, cap-less ledger
// that never talked to xpBalance/lifetimeXP or this transaction log at
// all. That's now fixed: AuthService.addXp() delegates to
// XpRepository.awardXp() (see services/auth_service.dart), so every XP
// source — magazine, daily challenge, tests, streaks — flows through one
// capped, logged ledger. `xpTotal` is left in the model for backward
// compatibility with any already-stored data, but nothing new writes to
// it and no UI should read it — read XpRepository.watchBalance()
// instead. Flagging this rather than quietly leaving two numbers that
// can drift apart.

enum XpTransactionType { earn, spend }

// magazineRead: earned by an ARTICLE'S AUTHOR (not the reader) each time
// a distinct new reader opens their article — see
// MagazineRepository.recordRead(). Deliberately the only Magazine earn
// source: no XP for posting comments, no XP for publish-count. Rewarding
// reach rather than upload volume or self-assessed effort means a single
// well-marketed article that reaches 10,000 readers earns more than fifty
// articles nobody reads — quantity alone buys nothing, same principle
// YouTube uses for watch-time over upload count. The only gate is
// originality/licensing (enforced editorially, not by this repository),
// never a subjective "quality" judgment.
//
// testCompletion / streakDaily / streakMilestone all have baseXp == 0
// below because their amount is computed dynamically per-award (test
// score/difficulty, or streak length) rather than a flat per-item rate —
// same reasoning as paperUnlock already had for spends.
enum XpSource {
  mcq,
  structural,
  ac,
  paperUnlock,
  magazineRead,
  testCompletion,
  streakDaily,
  streakMilestone,
  clubQuestion,
  clubAnswer,
  clubBestAnswer,
  dailyLearning,
}

extension XpSourceExt on XpSource {
  /// Raw XP awarded per correct answer / per unique read, before any
  /// multiplier. Only meaningful for the flat-rate earn sources —
  /// paperUnlock is a spend, testCompletion/streakMilestone are dynamic
  /// bonuses, and streakDaily's real value lives in
  /// core/xp_rules.dart:kStreakDailyXp (kept there, not here, since it's
  /// a streak-system constant rather than a per-answer rate).
  int get baseXp {
    switch (this) {
      // Matches production_plan.md §4.2 exactly: MCQ 15 / Structural 30 /
      // Essay 55. "ac" (long-form) is this codebase's existing name for
      // what the plan calls "Essay".
      case XpSource.mcq:             return 15;
      case XpSource.structural:      return 30;
      case XpSource.ac:              return 55;
      case XpSource.paperUnlock:     return 0;
      case XpSource.magazineRead:    return kMagazineReadXp;
      case XpSource.testCompletion:  return 0;
      case XpSource.streakDaily:     return 0;
      case XpSource.streakMilestone: return 0;
      // Matches the Clubs Discussions mockup exactly: +10 XP for asking,
      // +10 XP for answering, +25 XP bonus when your answer is marked best.
      case XpSource.clubQuestion:    return 10;
      case XpSource.clubAnswer:      return 10;
      case XpSource.clubBestAnswer:  return 25;
      // Daily Learning (Home's "Challenge" tile -- Etymology is the first
      // course) quiz questions are MCQ-shaped, same rate as Testing's own
      // mcq source.
      case XpSource.dailyLearning:   return 15;
    }
  }

  String get label {
    switch (this) {
      case XpSource.mcq:             return 'MCQ';
      case XpSource.structural:      return 'Structural';
      case XpSource.ac:              return 'Long Form';
      case XpSource.paperUnlock:     return 'Paper Unlock';
      case XpSource.magazineRead:    return 'Article Read';
      case XpSource.testCompletion:  return 'Test Completed';
      case XpSource.streakDaily:     return 'Daily Login';
      case XpSource.streakMilestone: return 'Streak Milestone';
      case XpSource.clubQuestion:    return 'Group Question';
      case XpSource.clubAnswer:      return 'Group Answer';
      case XpSource.clubBestAnswer:  return 'Best Answer';
      case XpSource.dailyLearning:   return 'Daily Learning';
    }
  }
}

const int kDailyXpCap = 200;
const int kPaperUnlockCost = 150;
const int kMarkingSchemeAddOnCost = 75;
const int kFullBundleCost = 800;

// DEPRECATED — the old flat "2 XP per unique read" rate. Superseded by
// production_plan.md §4.5's formula (see kMagazinePerPostXpCap below and
// MagazineRepository.settleMagazineXpIfDue()); XpSource.magazineRead's
// baseXp getter still returns this only because every other XpSource
// needs a baseXp value and nothing currently reads magazineRead.baseXp
// for the actual award amount — the formula computes and passes its own
// amount directly to XpRepository.awardXp() instead.
const int kMagazineReadXp = 2;

/// production_plan.md §4.5: per-post cap on the ONE-TIME, 24h-delayed
/// formula-based settlement (views/50 + likes*2 + comments*5 + shares*4).
const int kMagazinePerPostXpCap = 80;

/// The plan's separate 100XP/day magazine allowance is enforced server-side
/// in the award_xp() RPC (see
/// supabase/migrations/20260829420000_award_xp_category_caps.sql), on top
/// of (never instead of) the shared kDailyXpCap every other source draws
/// from. Mirrored here as a constant so the intended value is easy to find
/// from the client side too — keep both in sync if it ever changes.
const int kMagazineDailyXpCap = 100;

class XpTransaction {
  final String id;
  final String userId;
  final XpTransactionType type;
  final XpSource source;
  final int amount;
  final String? paperId;
  /// Populated for [XpSource.magazineRead] earn records — the article
  /// that was read, so a "why did I get 2 XP?" audit trail is possible.
  final String? articleId;
  /// Populated for [XpSource.mcq]/[structural]/[ac]/[testCompletion] —
  /// the testAttempts/{id} this XP came from, so test history can show
  /// its exact XP breakdown.
  final String? refId;
  final DateTime timestamp;

  const XpTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.source,
    required this.amount,
    this.paperId,
    this.articleId,
    this.refId,
    required this.timestamp,
  });

  factory XpTransaction.fromSupabase(Map<String, dynamic> d) {
    return XpTransaction(
      id: d['id'] as String,
      userId: d['user_id'] ?? '',
      type: XpTransactionType.values.firstWhere(
          (t) => t.name == d['type'], orElse: () => XpTransactionType.earn),
      source: XpSource.values.firstWhere(
          (s) => sourceKey(s) == d['source'], orElse: () => XpSource.mcq),
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      paperId: d['paper_id'],
      articleId: d['article_id'],
      refId: d['ref_id'],
      timestamp: DateTime.tryParse(d['occurred_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static String sourceKey(XpSource s) {
    switch (s) {
      case XpSource.mcq:             return 'mcq';
      case XpSource.structural:      return 'structural';
      case XpSource.ac:              return 'ac';
      case XpSource.paperUnlock:     return 'paper_unlock';
      case XpSource.magazineRead:    return 'magazine_read';
      case XpSource.testCompletion:  return 'test_completion';
      case XpSource.streakDaily:     return 'streak_daily';
      case XpSource.streakMilestone: return 'streak_milestone';
      case XpSource.clubQuestion:    return 'club_question';
      case XpSource.clubAnswer:      return 'club_answer';
      case XpSource.clubBestAnswer:  return 'club_best_answer';
      case XpSource.dailyLearning:   return 'daily_learning';
    }
  }
}

enum UnlockedVia { xp, paidSubscription }

class UnlockedPaper {
  final String userId;
  final String paperId;
  final UnlockedVia unlockedVia;
  final DateTime unlockedAt;

  const UnlockedPaper({
    required this.userId,
    required this.paperId,
    required this.unlockedVia,
    required this.unlockedAt,
  });

  String get docId => '${userId}_$paperId';

  factory UnlockedPaper.fromSupabase(Map<String, dynamic> d) {
    return UnlockedPaper(
      userId: d['user_id'] ?? '',
      paperId: d['paper_id'] ?? '',
      unlockedVia: (d['unlocked_via'] == 'paid_subscription')
          ? UnlockedVia.paidSubscription : UnlockedVia.xp,
      unlockedAt: DateTime.tryParse(d['unlocked_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
