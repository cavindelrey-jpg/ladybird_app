// lib/repositories/xp_repository.dart
// Award/spend XP for the past-paper unlock economy. Both awardXp() and
// spendXp() run inside Firestore transactions — not just spendXp as
// literally specified — because the daily-cap check in awardXp has the
// exact same read-then-write race condition spendXp does (two rapid
// concurrent answers could both read "150/200 used today" and both
// award their full amount, blowing past the cap). Same integrity bug,
// same fix.
//
// Honest limitation: the daily-cap "is this a new day yet" check compares
// against the device's clock (DateTime.now()), not a server-anchored
// value — Firestore has no cheap way to ask "what calendar day is it
// server-side" without a Cloud Function. A motivated user changing their
// device clock could manipulate the reset timing. Firestore rules
// (see firestore.rules) add a second layer — they reject any single
// award exceeding known per-source maximums — but full server-authoritative
// enforcement really wants a Cloud Function long-term. Flagging rather
// than pretending this is airtight.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/xp_transaction.dart';
import '../core/constants.dart';
import '../core/result.dart';

class XpRepository {
  XpRepository._();
  static final XpRepository instance = XpRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _db.collection(AppConstants.colUsers).doc(userId);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Awards XP for one correct answer. [rawAmount] is normally
  /// `source.baseXp` — passed explicitly (per spec) rather than derived
  /// internally, leaving room for a future streak/difficulty multiplier
  /// applied by the caller before this is invoked.
  ///
  /// Returns the amount actually awarded, which may be less than
  /// [rawAmount] (or zero) if the daily cap was hit — check the returned
  /// value against [rawAmount] in the UI to show a "daily cap reached"
  /// state rather than treating every award as fully successful.
  Future<Result<int>> awardXp(String userId, XpSource source, int rawAmount) async {
    if (rawAmount <= 0) return const Success(0);
    try {
      final awarded = await _db.runTransaction<int>((tx) async {
        final snap = await tx.get(_userDoc(userId));
        if (!snap.exists) throw Exception('User not found');
        final data = snap.data()!;

        final storedDate = (data['xpEarnedTodayDate'] as Timestamp?)?.toDate();
        final now = DateTime.now();
        final isNewDay = storedDate == null || !_isSameDay(storedDate, now);
        final earnedToday = isNewDay ? 0 : ((data['xpEarnedToday'] as num?)?.toInt() ?? 0);

        final room = kDailyXpCap - earnedToday;
        final toAward = rawAmount.clamp(0, room > 0 ? room : 0);
        if (toAward <= 0) return 0;

        tx.update(_userDoc(userId), {
          'xpBalance': FieldValue.increment(toAward),
          'lifetimeXP': FieldValue.increment(toAward),
          'xpEarnedToday': earnedToday + toAward,
          'xpEarnedTodayDate': Timestamp.fromDate(now),
        });

        final txnRef = _db.collection(AppConstants.colXpTransactions).doc();
        tx.set(txnRef, XpTransaction(
          id: '', userId: userId, type: XpTransactionType.earn,
          source: source, amount: toAward, timestamp: now,
        ).toFirestore());

        return toAward;
      });
      return Success(awarded);
    } catch (e) {
      return Failure('Failed to award XP', e);
    }
  }

  /// Spends XP to unlock a paper. Fails cleanly (no partial state) if
  /// the balance is insufficient — transaction guarantees the balance
  /// check and the deduction happen atomically, so two rapid taps on
  /// "Unlock" can't both succeed against a balance that only covers one.
  Future<Result<void>> spendXp({
    required String userId, required String paperId, required int cost,
  }) async {
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_userDoc(userId));
        if (!snap.exists) throw Exception('User not found');
        final balance = ((snap.data()!['xpBalance'] as num?) ?? 0).toInt();
        if (balance < cost) {
          throw Exception('Not enough XP — need $cost, have $balance');
        }

        tx.update(_userDoc(userId), {
          'xpBalance': FieldValue.increment(-cost),
          // lifetimeXP is deliberately untouched — spending never hurts rank.
        });

        final unlock = UnlockedPaper(
          userId: userId, paperId: paperId,
          unlockedVia: UnlockedVia.xp, unlockedAt: DateTime.now(),
        );
        tx.set(_db.collection(AppConstants.colUnlockedPapers).doc(unlock.docId), unlock.toFirestore());

        final txnRef = _db.collection(AppConstants.colXpTransactions).doc();
        tx.set(txnRef, XpTransaction(
          id: '', userId: userId, type: XpTransactionType.spend,
          source: XpSource.paperUnlock, amount: cost, paperId: paperId,
          timestamp: DateTime.now(),
        ).toFirestore());
      });
      return const Success(null);
    } catch (e) {
      return Failure(e.toString().replaceFirst('Exception: ', ''), e);
    }
  }

  /// (spendable balance, lifetime XP) — one-shot read.
  Future<(int, int)> getBalance(String userId) async {
    final doc = await _userDoc(userId).get();
    final d = doc.data() ?? {};
    return (((d['xpBalance'] as num?) ?? 0).toInt(), ((d['lifetimeXP'] as num?) ?? 0).toInt());
  }

  /// Live version of getBalance — for a persistent header badge.
  Stream<(int, int)> watchBalance(String userId) => _userDoc(userId).snapshots().map((doc) {
        final d = doc.data() ?? {};
        return (((d['xpBalance'] as num?) ?? 0).toInt(), ((d['lifetimeXP'] as num?) ?? 0).toInt());
      });

  /// Today's earn progress toward the daily cap, live — for a progress
  /// bar during quiz sessions. Returns 0 if the stored date is stale
  /// (a new day has started) even before awardXp() gets a chance to
  /// formally reset it server-side.
  Stream<int> watchXpEarnedToday(String userId) => _userDoc(userId).snapshots().map((doc) {
        final d = doc.data() ?? {};
        final storedDate = (d['xpEarnedTodayDate'] as Timestamp?)?.toDate();
        if (storedDate == null || !_isSameDay(storedDate, DateTime.now())) return 0;
        return ((d['xpEarnedToday'] as num?) ?? 0).toInt();
      });

  /// Checks unlock status. Premium subscribers unlock everything
  /// implicitly (per spec, no per-paper record written for them unless
  /// you want offline/bookmark tracking — this only checks isPremium
  /// first, cheaply, before touching Firestore for an XP-unlock record).
  Future<bool> isPaperUnlocked(AppUser user, String paperId) async {
    if (user.isPremium) return true;
    final doc = await _db.collection(AppConstants.colUnlockedPapers).doc('${user.id}_$paperId').get();
    return doc.exists;
  }

  Stream<bool> watchIsPaperUnlocked(AppUser user, String paperId) {
    if (user.isPremium) return Stream.value(true);
    return _db.collection(AppConstants.colUnlockedPapers).doc('${user.id}_$paperId')
        .snapshots().map((d) => d.exists);
  }
}
