// lib/repositories/xp_repository.dart
// Award/spend XP for the platform-wide economy (quizzes, tests, streaks,
// and magazine reads on the earn side, past-paper/bundle unlocks on the
// spend side). Both awardXp() and spendXp() run inside Firestore
// transactions — not just spendXp as literally specified — because the
// daily-cap check in awardXp has the exact same read-then-write race
// condition spendXp does (two rapid concurrent answers could both read
// "150/200 used today" and both award their full amount, blowing past
// the cap). Same integrity bug, same fix.
//
// production_plan.md §4.4/§4.5: quiz XP (per-academic-level cap, 120/160/
// 200, itself capped at an overall 280/day) and magazine XP (100/day) are
// each their OWN pool, tracked in separate quizXpEarnedToday/
// magazineXpEarnedToday fields — metered ON TOP OF, not instead of, the
// general kDailyXpCap every source still shares. A source not in either
// category (streak, club Q&A) is metered by the general cap alone, same
// as before this categorization existed.
//
// This is now the SINGLE entry point for all XP awards in the app —
// AuthService.addXp() (magazine settlement, daily challenge) delegates
// here too, so there is exactly one capped, logged ledger instead of the
// two that used to exist. See models/xp_transaction.dart's file comment
// for that history.
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
import '../core/xp_rules.dart';

/// production_plan.md §4.4/§4.5: quiz and magazine XP each have their own
/// daily allowance, separate from each other and from every other source
/// (streak, club Q&A) — not one shared pool. Sources not listed here fall
/// back to being metered by the general kDailyXpCap alone, same as before
/// this categorization existed.
bool _isQuizXpSource(XpSource s) =>
    s == XpSource.mcq || s == XpSource.structural || s == XpSource.ac || s == XpSource.testCompletion;
bool _isMagazineXpSource(XpSource s) => s == XpSource.magazineRead;

class XpRepository {
  XpRepository._();
  static final XpRepository instance = XpRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _db.collection(AppConstants.colUsers).doc(userId);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Awards XP for one earn event. [rawAmount] is the already-computed
  /// amount for this award (e.g. `source.baseXp` for a flat-rate answer,
  /// or a dynamically computed test-completion/streak-milestone bonus —
  /// see core/xp_rules.dart for how each is derived). [refId] is an
  /// optional pointer back to whatever produced this award (a
  /// testAttempts/{id}, an article id via [articleId], etc.) purely for
  /// audit-trail / history display — it never affects the award itself.
  ///
  /// Returns the amount actually awarded, which may be less than
  /// [rawAmount] (or zero) if the daily cap was hit — check the returned
  /// value against [rawAmount] in the UI to show a "daily cap reached"
  /// state rather than treating every award as fully successful.
  Future<Result<int>> awardXp(
    String userId,
    XpSource source,
    int rawAmount, {
    String? articleId,
    String? refId,
  }) async {
    if (rawAmount <= 0) return const Success(0);
    if (userId.isEmpty) return const Success(0);
    try {
      final awarded = await _db.runTransaction<int>((tx) async {
        final snap = await tx.get(_userDoc(userId));
        if (!snap.exists) throw Exception('User not found');
        final data = snap.data()!;
        final now = DateTime.now();

        final storedDate = (data['xpEarnedTodayDate'] as Timestamp?)?.toDate();
        final isNewDay = storedDate == null || !_isSameDay(storedDate, now);
        final earnedToday = isNewDay ? 0 : ((data['xpEarnedToday'] as num?)?.toInt() ?? 0);
        var room = kDailyXpCap - earnedToday;

        // §4.4/§4.5 category-specific pools, additionally metered on top
        // of (never instead of) the general pool above.
        final isQuiz = _isQuizXpSource(source);
        final isMagazine = _isMagazineXpSource(source);
        int? categoryEarnedToday;
        String? categoryEarnedField, categoryDateField;
        if (isQuiz) {
          categoryEarnedField = 'quizXpEarnedToday';
          categoryDateField = 'quizXpEarnedTodayDate';
          final capForLevel = quizDailyXpCapForLevel(data['educationLevel'] ?? '');
          final storedCatDate = (data[categoryDateField] as Timestamp?)?.toDate();
          final catNewDay = storedCatDate == null || !_isSameDay(storedCatDate, now);
          categoryEarnedToday = catNewDay ? 0 : ((data[categoryEarnedField] as num?)?.toInt() ?? 0);
          final catRoom = capForLevel - categoryEarnedToday;
          if (catRoom < room) room = catRoom;
        } else if (isMagazine) {
          categoryEarnedField = 'magazineXpEarnedToday';
          categoryDateField = 'magazineXpEarnedTodayDate';
          final storedCatDate = (data[categoryDateField] as Timestamp?)?.toDate();
          final catNewDay = storedCatDate == null || !_isSameDay(storedCatDate, now);
          categoryEarnedToday = catNewDay ? 0 : ((data[categoryEarnedField] as num?)?.toInt() ?? 0);
          final catRoom = kMagazineDailyXpCap - categoryEarnedToday;
          if (catRoom < room) room = catRoom;
        }

        final toAward = rawAmount.clamp(0, room > 0 ? room : 0);
        if (toAward <= 0) return 0;

        final update = <String, dynamic>{
          'xpBalance': FieldValue.increment(toAward),
          'lifetimeXP': FieldValue.increment(toAward),
          'xpEarnedToday': earnedToday + toAward,
          'xpEarnedTodayDate': Timestamp.fromDate(now),
        };
        if (categoryEarnedField != null) {
          update[categoryEarnedField] = categoryEarnedToday! + toAward;
          update[categoryDateField!] = Timestamp.fromDate(now);
        }
        tx.update(_userDoc(userId), update);

        final txnRef = _db.collection(AppConstants.colXpTransactions).doc();
        tx.set(txnRef, XpTransaction(
          id: '', userId: userId, type: XpTransactionType.earn,
          source: source, amount: toAward, articleId: articleId,
          refId: refId, timestamp: now,
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

  /// Live version of getBalance — for a persistent header badge and the
  /// XP dashboard.
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

  /// Recent XP ledger entries for a user, newest first — powers the XP
  /// dashboard's earning history list. Real transactions only, sourced
  /// straight from the same collection every award/spend writes to.
  Stream<List<XpTransaction>> watchHistory(String userId, {int limit = 50}) => _db
      .collection(AppConstants.colXpTransactions)
      .where('userId', isEqualTo: userId)
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(XpTransaction.fromFirestore).toList());

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
