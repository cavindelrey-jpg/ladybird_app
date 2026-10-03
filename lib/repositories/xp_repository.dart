// lib/repositories/xp_repository.dart
// Award/spend XP for the platform-wide economy. awardXp()/spendXp() are
// SECURITY DEFINER RPCs (award_xp/spend_xp — see
// supabase/migrations/20260829250000_xp_rpcs.sql) using `select ... for
// update` row locks, replacing the Firestore transactions that closed the
// same read-then-write race (two concurrent awards both reading "150/200
// used today" and both landing under the cap).
//
// Honest limitation carried over unchanged: the daily-cap reset compares
// against Postgres's own `now()` (server-side, unlike the old device-clock
// comparison) — that part is actually now MORE correct than the Firestore
// version. What's still not airtight is per-source amount validation
// (RLS/rules can't easily cap "this MCQ award must be <=10 XP" without a
// static lookup) — same caveat as before, just re-homed.

import '../models/app_user.dart';

import '../models/xp_transaction.dart';
import '../core/result.dart';
import '../config/branding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/content_cache_service.dart';
import 'dart:async';
import '../core/realtime_tolerant.dart';

class XpRepository {
  XpRepository._();
  static final XpRepository instance = XpRepository._();

  final SupabaseClient _db = Supabase.instance.client;

  /// Awards XP for one earn event. Returns the amount actually awarded,
  /// which may be less than [rawAmount] (or zero) if the daily cap was hit.
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
      final awarded = await _db.rpc('award_xp', params: {
        'p_user_id': userId,
        'p_source': XpTransaction.sourceKey(source),
        'p_raw_amount': rawAmount,
        'p_daily_cap': kDailyXpCap,
        'p_article_id': articleId,
        'p_ref_id': refId,
      }) as int;
      return Success(awarded);
    } catch (e) {
      return Failure('Failed to award XP', e);
    }
  }

  /// Spends XP to unlock a paper. Fails cleanly if the balance is
  /// insufficient.
  Future<Result<void>> spendXp({
    required String userId, required String paperId, required int cost,
  }) async {
    try {
      await _db.rpc('spend_xp', params: {'p_user_id': userId, 'p_paper_id': paperId, 'p_cost': cost});
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(e.message, e);
    } catch (e) {
      return Failure(e.toString(), e);
    }
  }

  /// (spendable balance, lifetime XP) — one-shot read.
  Future<(int, int)> getBalance(String userId) async {
    final row = await _db.from('users').select('xp_balance,lifetime_xp').eq('id', userId).maybeSingle();
    return ((row?['xp_balance'] as num?)?.toInt() ?? 0, (row?['lifetime_xp'] as num?)?.toInt() ?? 0);
  }

  /// Live version of getBalance — for a persistent header badge and the
  /// XP dashboard.
  Stream<(int, int)> watchBalance(String userId) {
    final controller = StreamController<(int, int)>();
    StreamSubscription? liveSub;
    controller.onListen = () async {
      final cacheKey = 'xp_$userId';
      final cached = await ContentCacheService.instance.getList(cacheKey);
      if (cached != null && cached.isNotEmpty && !controller.isClosed) {
        controller.add((cached.first['xp_balance'] as int, cached.first['lifetime_xp'] as int));
      }
      liveSub = _db
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', userId)
          .realtimeTolerant()
          .listen((rows) {
        if (controller.isClosed) return;
        if (rows.isEmpty) return;
        final d = rows.first;
        final xp = (d['xp_balance'] as num?)?.toInt() ?? 0;
        final lifetime = (d['lifetime_xp'] as num?)?.toInt() ?? 0;
        unawaited(ContentCacheService.instance.putList(cacheKey, [{'xp_balance': xp, 'lifetime_xp': lifetime}]));
        controller.add((xp, lifetime));
      }, onError: (e) {
        if (cached == null && !controller.isClosed) controller.addError(e);
      });
    };
    controller.onCancel = () => liveSub?.cancel();
    return controller.stream;
  }

  /// Today's earn progress toward the daily cap, live.
  Stream<int> watchXpEarnedToday(String userId) => _db
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .realtimeTolerant()
      .map((rows) {
    if (rows.isEmpty) return 0;
    final d = rows.first;
    final storedDate = DateTime.tryParse(d['xp_earned_today_date']?.toString() ?? '');
    final now = DateTime.now();
    if (storedDate == null ||
        storedDate.year != now.year || storedDate.month != now.month || storedDate.day != now.day) {
      return 0;
    }
    return (d['xp_earned_today'] as num?)?.toInt() ?? 0;
  });

  /// Recent XP ledger entries for a user, newest first.
  Stream<List<XpTransaction>> watchHistory(String userId, {int limit = 50}) => _db
      .from('xp_transactions')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('occurred_at', ascending: false)
      .limit(limit)
      .realtimeTolerant()
      .map((rows) => rows.map(XpTransaction.fromSupabase).toList());

  /// Checks unlock status. Premium subscribers unlock everything
  /// implicitly, and so does every white-label school build (Green
  /// Hills, Legitbell, ...) — the XP/paywall economy is Academia-only,
  /// see Branding.xpEconomyEnabled.
  Future<bool> isPaperUnlocked(AppUser user, String paperId) async {
    if (user.isPremium || !Branding.current.xpEconomyEnabled) return true;
    final row = await _db
        .from('unlocked_papers')
        .select()
        .eq('user_id', user.id)
        .eq('paper_id', paperId)
        .maybeSingle();
    return row != null;
  }

  Stream<bool> watchIsPaperUnlocked(AppUser user, String paperId) {
    if (user.isPremium || !Branding.current.xpEconomyEnabled) return Stream.value(true);
    return _db
        .from('unlocked_papers')
        .stream(primaryKey: ['user_id', 'paper_id'])
        .eq('user_id', user.id)
        .realtimeTolerant()
        .map((rows) => rows.any((r) => r['paper_id'] == paperId));
  }
}
