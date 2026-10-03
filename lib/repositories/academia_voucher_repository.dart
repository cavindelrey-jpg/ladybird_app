// lib/repositories/academia_voucher_repository.dart
// Issuance/redemption for AC-prefixed Academia vouchers — the school-less
// counterpart to school_access_repository.dart. See
// supabase/migrations/20260831000000_unified_voucher_authorization.sql
// for the redeem_academia_voucher() RPC this calls.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/branding.dart';
import '../core/result.dart';
import '../models/academia_voucher.dart';
import '../models/school_voucher.dart' show VoucherPremiumTier;

class AcademiaRedemptionOutcome {
  final AcademiaRole role;
  final VoucherPremiumTier premiumTier;
  const AcademiaRedemptionOutcome({required this.role, required this.premiumTier});
}

class AcademiaVoucherRepository {
  AcademiaVoucherRepository._();
  static final AcademiaVoucherRepository instance = AcademiaVoucherRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Super-admin-only (enforced by RLS' academia_vouchers_insert_super_admin
  /// policy — issuing an Academia-brand code is platform-level, there's no
  /// institution to scope it to). [premiumTier] is the issuer's choice only
  /// for [AcademiaRole.user]; `superAdmin` is forced Gold.
  Future<Result<List<AcademiaVoucher>>> issueVouchers({
    required AcademiaRole role,
    required String issuedByUid,
    int count = 1,
    VoucherPremiumTier premiumTier = VoucherPremiumTier.silver,
  }) async {
    if (count < 1 || count > 200) {
      return const Failure('Generate between 1 and 200 codes at a time', null);
    }
    try {
      final effectivePremium = role.isAlwaysGold ? VoucherPremiumTier.gold : premiumTier;
      final issued = <AcademiaVoucher>[];
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < count; i++) {
        final code = AcademiaVoucher.generateCode(role: role, premiumTier: effectivePremium);
        final voucher = AcademiaVoucher(
          id: code,
          role: role,
          premiumTier: effectivePremium,
          createdAt: DateTime.now(),
          createdByUid: issuedByUid,
        );
        rows.add(voucher.toSupabase());
        issued.add(voucher);
      }
      await _supabase.from('academia_vouchers').insert(rows);
      return Success(issued);
    } catch (e) {
      return Failure('Failed to generate voucher codes', e);
    }
  }

  /// Passes this build's fixed [Branding.current.voucherPrefix] as the
  /// RPC's tenant check — a school app (GH/LB/...) will never pass 'AC',
  /// so an Academia code can never be redeemed through a school app.
  Future<Result<AcademiaRedemptionOutcome>> redeemVoucher({
    required String userId,
    required String rawCode,
  }) async {
    if (userId.isEmpty) {
      return const Failure('You need to be signed in to redeem a code', null);
    }
    if (!AcademiaVoucher.isPlausibleCode(rawCode)) {
      return const Failure('That code doesn\'t look right — check it and try again', null);
    }
    final normalized = AcademiaVoucher.normalizeCode(rawCode);

    try {
      final rows = await _supabase.rpc('redeem_academia_voucher', params: {
        'p_code': normalized,
        'p_expected_prefix': Branding.current.voucherPrefix,
      }) as List;
      final result = rows.first as Map<String, dynamic>;
      final role = AcademiaRoleX.fromName(result['out_role']?.toString() ?? '') ?? AcademiaRole.user;
      final premiumTier = VoucherPremiumTier.values.firstWhere(
          (t) => t.name == result['out_premium_tier']?.toString(),
          orElse: () => VoucherPremiumTier.silver);
      return Success(AcademiaRedemptionOutcome(role: role, premiumTier: premiumTier));
    } on PostgrestException catch (e) {
      return Failure(e.message, e);
    } catch (e) {
      return Failure('Failed to redeem your code', e);
    }
  }
}
