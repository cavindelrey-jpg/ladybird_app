// lib/repositories/entitlement_repository.dart
// production_plan.md §8/§9 — entitlements, physical-sale purchases and
// gift vouchers.
//
// NO PAYMENT CODE LIVES HERE, BY DESIGN. §9's sale is physical: a parent
// hands cash to a sales agent in person, and the agent afterwards records
// what happened. `recordPurchaseAndIssueVoucher` therefore writes a
// RECORD of a completed external transaction — it never moves money,
// never contacts a payment provider, and cannot fail for "payment"
// reasons because no payment is attempted.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';
import '../models/app_user.dart';
import '../models/entitlement.dart';
import '../models/purchase.dart';
import '../models/voucher.dart';

/// Outcome of a successful redemption — what the UI needs to confirm to
/// the user without re-reading anything.
class RedemptionOutcome {
  final Voucher voucher;
  final Entitlement entitlement;

  /// True when the user already had premium and this voucher extended it
  /// rather than starting a fresh window.
  final bool wasExtension;

  const RedemptionOutcome({
    required this.voucher,
    required this.entitlement,
    required this.wasExtension,
  });
}

class EntitlementRepository {
  EntitlementRepository._();
  static final EntitlementRepository instance = EntitlementRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Duration _opTimeout = Duration(seconds: 20);

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(AppConstants.colUsers).doc(uid);
  DocumentReference<Map<String, dynamic>> _voucherDoc(String id) =>
      _db.collection(AppConstants.colVouchers).doc(id);
  CollectionReference<Map<String, dynamic>> get _vouchers =>
      _db.collection(AppConstants.colVouchers);
  CollectionReference<Map<String, dynamic>> get _purchases =>
      _db.collection(AppConstants.colPurchases);

  // ══ Sales agent side (§9 Purchase + Voucher) ═══════════════════════════

  /// Records an already-completed offline sale and issues its voucher.
  ///
  /// Both documents are written in ONE batch: a purchase whose voucher
  /// never got created would be money taken with nothing handed back, and
  /// a voucher with no purchase behind it is unauditable. They must land
  /// together or not at all.
  ///
  /// [amount] is what the agent actually collected — it is typed in, not
  /// derived from the package, because real physical sales involve
  /// negotiated and promotional pricing (see EntitlementPackage's comment
  /// on why no price is hardcoded).
  Future<Result<Voucher>> recordPurchaseAndIssueVoucher({
    required AppUser agent,
    required num amount,
    required PaymentMethod paymentMethod,
    required EntitlementPackage package,
    required String purchaseSource,
    String buyerName = '',
    String note = '',
    String currency = 'FCFA',
    PurchaseStatus status = PurchaseStatus.completed,
  }) async {
    if (agent.id.isEmpty) {
      return const Failure('Not signed in', null);
    }
    if (amount < 0) {
      return const Failure('Amount cannot be negative', null);
    }
    try {
      final code = await _generateUniqueCode();
      final normalized = Voucher.normalizeCode(code);
      final now = DateTime.now();

      final purchaseRef = _purchases.doc();
      final voucherRef = _voucherDoc(normalized);

      final voucher = Voucher(
        id: normalized,
        code: code,
        purchaseId: purchaseRef.id,
        durationDays: package.durationDays,
        packageLabel: package.label,
        createdAt: now,
        createdByUid: agent.id,
      );

      final purchase = Purchase(
        id: purchaseRef.id,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        package: package,
        voucherId: normalized,
        voucherCode: code,
        createdAt: now,
        salesAgentId: agent.id,
        salesAgentName: agent.name,
        purchaseSource: purchaseSource,
        status: status,
        buyerName: buyerName,
        note: note,
      );

      final batch = _db.batch()
        ..set(purchaseRef, purchase.toFirestore())
        ..set(voucherRef, voucher.toFirestore());
      await batch.commit().timeout(_opTimeout);

      return Success(voucher);
    } catch (e) {
      return Failure('Could not record the purchase', e);
    }
  }

  /// Finds an unused code. Collisions are astronomically unlikely at
  /// 31^12, but "unlikely" isn't "impossible" and a silent collision
  /// would overwrite a voucher someone already paid for — so it's checked
  /// rather than assumed. Bounded retries so a persistent read failure
  /// surfaces as an error instead of spinning.
  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = Voucher.generateCode();
      final snap = await _voucherDoc(Voucher.normalizeCode(code))
          .get()
          .timeout(_opTimeout);
      if (!snap.exists) return code;
    }
    throw Exception('Could not generate a unique voucher code');
  }

  /// All vouchers, newest first — the sales desk list. Real documents
  /// only; there is no placeholder/demo row anywhere in this stream.
  Stream<List<Voucher>> watchVouchers({int limit = 50}) => _vouchers
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Voucher.fromFirestore(d.id, d.data()))
          .toList());

  /// Recorded purchases, newest first.
  Stream<List<Purchase>> watchPurchases({int limit = 50}) => _purchases
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Purchase.fromFirestore(d.id, d.data()))
          .toList());

  /// Kills a voucher (refund, fraud, mis-issue).
  ///
  /// Deliberately does NOT strip premium from an account that already
  /// redeemed it — clawing back access someone is mid-term using is a
  /// support decision with real user impact, not something a list-row
  /// menu should do silently. Revoking an UNUSED voucher (the common
  /// case: a refund before the code was gifted) fully prevents access.
  Future<Result<void>> revokeVoucher(String voucherId, String reason) async {
    try {
      await _voucherDoc(voucherId).update({
        'status': VoucherStatus.revoked.name,
        'revokedAt': DateTime.now().toIso8601String(),
        'revokedReason': reason,
      }).timeout(_opTimeout);
      return const Success(null);
    } catch (e) {
      return Failure('Could not revoke the voucher', e);
    }
  }

  // ══ Redeemer side (§9 redemption -> §8 entitlement) ════════════════════

  /// Redeems [rawCode] for [user], atomically.
  ///
  /// Race-condition safety follows the pattern already established by
  /// `XpRepository.awardXp()` and this session's fix to
  /// `AuthService.recordDailyActivity()`: the check and the write happen
  /// inside ONE `runTransaction`, reading fresh server state rather than
  /// trusting a snapshot read earlier. Two devices redeeming the same
  /// code simultaneously both read `status == unused` if the check sits
  /// outside a transaction, and both grant premium — one voucher, two
  /// accounts upgraded, money lost. Inside the transaction, whichever
  /// write commits second sees the updated status and fails cleanly.
  ///
  /// This is also why the voucher's document id IS its normalized code
  /// (see Voucher.id): the client SDK cannot run a query inside a
  /// transaction, so a `where('code', ...)` lookup would have to happen
  /// outside it and reopen the same hole.
  ///
  /// Both writes — flipping the voucher and granting the entitlement —
  /// are in the same transaction, so a voucher can never be consumed
  /// without the account actually receiving premium.
  Future<Result<RedemptionOutcome>> redeemVoucher({
    required AppUser user,
    required String rawCode,
  }) async {
    if (user.id.isEmpty) {
      return const Failure('You need to be signed in to redeem a voucher', null);
    }
    if (!Voucher.isPlausibleCode(rawCode)) {
      return const Failure(
          'That code doesn\'t look right — check it and try again', null);
    }
    final normalized = Voucher.normalizeCode(rawCode);

    try {
      final outcome = await _db.runTransaction<RedemptionOutcome>((tx) async {
        final vSnap = await tx.get(_voucherDoc(normalized));
        if (!vSnap.exists) {
          throw _RedeemException('No voucher found with that code');
        }
        final voucher = Voucher.fromFirestore(normalized, vSnap.data()!);

        switch (voucher.status) {
          case VoucherStatus.revoked:
            throw _RedeemException('This voucher has been cancelled');
          case VoucherStatus.redeemed:
          case VoucherStatus.active:
          case VoucherStatus.expired:
            throw _RedeemException('This voucher has already been redeemed');
          case VoucherStatus.unused:
            break; // the only redeemable state
        }

        // Read the user's CURRENT entitlement from the server inside the
        // transaction too — the caller's AppUser could be a stale
        // snapshot, and stacking onto a stale expiry would quietly
        // shorten access the user already paid for.
        final uSnap = await tx.get(_userDoc(user.id));
        if (!uSnap.exists) throw _RedeemException('Account not found');
        final current =
            Entitlement.fromUserMap(uSnap.data()!,
                legacyIsPremium: uSnap.data()!['isPremium'] ?? false);

        final now = DateTime.now();
        // Stack rather than overwrite: someone who redeems a second
        // voucher while still premium should get the time added, not
        // have their remaining days thrown away.
        final wasExtension = current.isActive && current.expiresAt != null;
        final base = wasExtension ? current.expiresAt! : now;
        final expiresAt = base.add(Duration(days: voucher.durationDays));

        final granted = Entitlement(
          tier: EntitlementTier.premium,
          source: EntitlementSource.gift,
          startAt: current.isActive ? (current.startAt ?? now) : now,
          expiresAt: expiresAt,
          sourceRef: voucher.id,
        );

        tx.update(_voucherDoc(normalized), {
          'status': VoucherStatus.redeemed.name,
          'recipientUserId': user.id,
          'recipientName': user.name,
          'redeemedAt': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
        });

        tx.update(_userDoc(user.id), {
          ...granted.toUserMap(),
          // Keep the legacy mirror truthful for anything still reading it.
          'isPremium': true,
        });

        return RedemptionOutcome(
          voucher: voucher,
          entitlement: granted,
          wasExtension: wasExtension,
        );
      }).timeout(_opTimeout);

      return Success(outcome);
    } on _RedeemException catch (e) {
      // Expected, user-facing failure (bad code, already used) — surfaced
      // as a clean Failure message, not an exception, per the Result
      // convention in core/result.dart.
      return Failure(e.message, null);
    } catch (e) {
      return Failure('Could not redeem the voucher', e);
    }
  }

  /// The vouchers this account has redeemed — lets Profile show a real
  /// history instead of just a current-status line.
  Stream<List<Voucher>> watchMyVouchers(String uid) => _vouchers
      .where('recipientUserId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Voucher.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) =>
            (b.redeemedAt ?? b.createdAt).compareTo(a.redeemedAt ?? a.createdAt)));
}

/// Internal marker so expected redemption failures can unwind the
/// transaction (Firestore needs a throw to abort it) while still being
/// distinguishable from genuine infrastructure errors in the catch.
class _RedeemException implements Exception {
  final String message;
  _RedeemException(this.message);
}
