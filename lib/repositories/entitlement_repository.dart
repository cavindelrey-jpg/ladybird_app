// lib/repositories/entitlement_repository.dart
// production_plan.md §8/§9 — entitlements, physical-sale purchases and
// gift vouchers.
//
// DEFERRED as part of this migration pass: the "core app first" scoping
// decision explicitly treats the voucher/entitlement monetization system
// as a separate, focused follow-up given its business criticality,
// rather than porting it at the same pace as everything else. This file
// is therefore an honest stub — same public signatures every call site
// (redeem_voucher_page.dart, sales_desk_page.dart) already expects, but
// no Postgres table/RPC backs it yet. Every method fails or returns
// empty rather than fabricating a voucher/purchase. Build the real
// schema (mirroring school_vouchers' redeem-via-RPC shape — see
// supabase/migrations/20260829370000_school_vouchers.sql for the
// established pattern) when this becomes the active task.

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

  static const String _notAvailable =
      'Voucher purchases aren\'t available yet — check back soon.';

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
  }) async =>
      const Failure(_notAvailable, null);

  Stream<List<Voucher>> watchVouchers({int limit = 50}) => Stream.value(const []);

  Stream<List<Purchase>> watchPurchases({int limit = 50}) => Stream.value(const []);

  Future<Result<void>> revokeVoucher(String voucherId, String reason) async =>
      const Failure(_notAvailable, null);

  Future<Result<RedemptionOutcome>> redeemVoucher({
    required AppUser user,
    required String rawCode,
  }) async =>
      const Failure(_notAvailable, null);
}
