// lib/models/xp_transaction.dart
// Backs the platform-wide XP economy. Two earn sides, one spendable
// currency:
//   - Quiz answers (mcq / structural / ac) — tiered so harder answer
//     formats earn faster; a student who only ever does MCQs can still
//     reach any unlock, just slower.
//   - Magazine reads (magazineRead) — an article's AUTHOR earns XP when
//     a genuinely new reader opens their piece. See
//     MagazineRepository.recordRead() for the uniqueness gating that
//     stops this being farmable by just reopening your own article.
//
// XP spends on past papers, marking schemes, and full subject bundles —
// a free alternative to the 5,000 FCFA/year Premium subscription (which
// unlocks everything instantly, no grind needed — see AppUser.isPremium).
// XP is never redeemable for real money in either direction; it is a
// closed-loop, platform-internal currency only.
//
// Deliberately NOT in this economy: course creation. Courses are
// team/AI-sourced content, not a student-earn surface — video production
// has too much friction (equipment, time, editing) to be a fair "any
// student, anywhere" earn source the way quizzes and writing are, so it
// was scoped out rather than half-built.
//
// Two ledgers per user, both on AppUser itself (models/app_user.dart):
//   xpBalance   — spendable, decreases on unlock
//   lifetimeXP  — never decreases, leaderboard/rank display only, so
//                 spending XP never hurts a student's rank
//
// Honest scope note: there is no quiz feature in this codebase yet.
// XpRepository.awardXp() is fully real and ready to be called — it just
// doesn't have a caller yet for the quiz sources, because nothing that
// grades an MCQ/structural/AC answer exists. The magazineRead source,
// by contrast, IS wired up end-to-end (MagazineRepository.recordRead()
// calls it live). Quiz grading remains the missing half of the feature.

import 'package:cloud_firestore/cloud_firestore.dart';

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
enum XpSource { mcq, structural, ac, paperUnlock, magazineRead }

extension XpSourceExt on XpSource {
  /// Raw XP awarded per correct answer / per unique read, before any
  /// multiplier. Only meaningful for the earn sources — paperUnlock is a
  /// spend, its amount is the paper's actual cost, not a fixed rate.
  int get baseXp {
    switch (this) {
      case XpSource.mcq:         return 10;
      case XpSource.structural:  return 25;
      case XpSource.ac:          return 45;
      case XpSource.paperUnlock: return 0;
      case XpSource.magazineRead:return kMagazineReadXp;
    }
  }

  String get label {
    switch (this) {
      case XpSource.mcq:         return 'MCQ';
      case XpSource.structural:  return 'Structural';
      case XpSource.ac:          return 'AC';
      case XpSource.paperUnlock: return 'Paper Unlock';
      case XpSource.magazineRead:return 'Article Read';
    }
  }
}

const int kDailyXpCap = 200;
const int kPaperUnlockCost = 150;
const int kMarkingSchemeAddOnCost = 75;
const int kFullBundleCost = 800;

// Small on purpose — this is metered engagement income, not a quiz
// reward. A viral article (thousands of unique reads) still only earns
// its author up to kDailyXpCap per day, same ceiling as everyone else;
// the daily cap in XpRepository.awardXp() is what actually prevents a
// viral spike from minting runaway currency, not this per-read amount.
const int kMagazineReadXp = 2;

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
  final DateTime timestamp;

  const XpTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.source,
    required this.amount,
    this.paperId,
    this.articleId,
    required this.timestamp,
  });

  factory XpTransaction.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return XpTransaction(
      id: doc.id,
      userId: d['userId'] ?? '',
      type: XpTransactionType.values.firstWhere(
          (t) => t.name == d['type'], orElse: () => XpTransactionType.earn),
      source: XpSource.values.firstWhere(
          (s) => _sourceKey(s) == d['source'], orElse: () => XpSource.mcq),
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      paperId: d['paperId'],
      articleId: d['articleId'],
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'type': type.name,
        'source': _sourceKey(source),
        'amount': amount,
        'paperId': paperId,
        'articleId': articleId,
        'timestamp': Timestamp.fromDate(timestamp),
      };

  static String _sourceKey(XpSource s) {
    switch (s) {
      case XpSource.mcq:         return 'mcq';
      case XpSource.structural:  return 'structural';
      case XpSource.ac:          return 'ac';
      case XpSource.paperUnlock: return 'paper_unlock';
      case XpSource.magazineRead:return 'magazine_read';
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

  factory UnlockedPaper.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UnlockedPaper(
      userId: d['userId'] ?? '',
      paperId: d['paperId'] ?? '',
      unlockedVia: (d['unlockedVia'] == 'paid_subscription')
          ? UnlockedVia.paidSubscription : UnlockedVia.xp,
      unlockedAt: (d['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'paperId': paperId,
        'unlockedVia': unlockedVia == UnlockedVia.paidSubscription ? 'paid_subscription' : 'xp',
        'unlockedAt': Timestamp.fromDate(unlockedAt),
      };
}
