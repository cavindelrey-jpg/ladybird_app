// lib/models/xp_transaction.dart
// Backs the XP economy — earn XP by answering quiz questions correctly,
// spend it to unlock past papers as a free alternative to the 5,000
// FCFA/year Premium subscription (which unlocks everything instantly,
// no XP needed — see AppUser.isPremium).
//
// Two ledgers per user, both on AppUser itself (models/app_user.dart):
//   xpBalance   — spendable, decreases on unlock
//   lifetimeXP  — never decreases, leaderboard/rank display only, so
//                 spending XP never hurts a student's rank
//
// Honest scope note: there is no quiz feature in this codebase yet.
// XpRepository.awardXp() is fully real and ready to be called — it just
// doesn't have a caller yet, because nothing that grades an MCQ/
// structural/AC answer exists. This is the missing half of the feature,
// not a bug in what's built here.

import 'package:cloud_firestore/cloud_firestore.dart';

enum XpTransactionType { earn, spend }

enum XpSource { mcq, structural, ac, paperUnlock }

extension XpSourceExt on XpSource {
  /// Raw XP awarded per correct answer, before any multiplier. Only
  /// meaningful for the three "earn" sources — paperUnlock is a spend,
  /// its amount is the paper's actual cost, not a fixed per-source rate.
  int get baseXp {
    switch (this) {
      case XpSource.mcq:        return 10;
      case XpSource.structural: return 25;
      case XpSource.ac:         return 45;
      case XpSource.paperUnlock:return 0;
    }
  }

  String get label {
    switch (this) {
      case XpSource.mcq:        return 'MCQ';
      case XpSource.structural: return 'Structural';
      case XpSource.ac:         return 'AC';
      case XpSource.paperUnlock:return 'Paper Unlock';
    }
  }
}

const int kDailyXpCap = 200;
const int kPaperUnlockCost = 150;
const int kMarkingSchemeAddOnCost = 75;
const int kFullBundleCost = 800;

class XpTransaction {
  final String id;
  final String userId;
  final XpTransactionType type;
  final XpSource source;
  final int amount;
  final String? paperId;
  final DateTime timestamp;

  const XpTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.source,
    required this.amount,
    this.paperId,
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
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'type': type.name,
        'source': _sourceKey(source),
        'amount': amount,
        'paperId': paperId,
        'timestamp': Timestamp.fromDate(timestamp),
      };

  static String _sourceKey(XpSource s) {
    switch (s) {
      case XpSource.mcq:         return 'mcq';
      case XpSource.structural:  return 'structural';
      case XpSource.ac:          return 'ac';
      case XpSource.paperUnlock: return 'paper_unlock';
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
