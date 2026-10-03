// lib/repositories/school_access_repository.dart
// The redemption half of the voucher-as-authorization-token design: a
// school app must only be accessible to someone holding a valid voucher
// for THAT school AND that app (tenant check), never to any signed-in
// Academia account. Issuance is a direct insert (RLS'
// school_vouchers_insert_staff policy enforces the staff/own-school
// check); redemption goes through the redeem_school_voucher() RPC, since
// RLS deliberately doesn't expose a client-side select-by-code path for
// this table (see
// supabase/migrations/20260831000000_unified_voucher_authorization.sql).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/branding.dart';
import '../core/result.dart';
import '../models/school.dart';
import '../models/school_voucher.dart';
import 'school_repository.dart';

class SchoolRedemptionOutcome {
  final School school;
  final SchoolRole role;
  final VoucherPremiumTier? premiumTier;
  const SchoolRedemptionOutcome({required this.school, required this.role, this.premiumTier});
}

class SchoolAccessRepository {
  SchoolAccessRepository._();
  static final SchoolAccessRepository instance = SchoolAccessRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Staff-only (enforced by RLS' school_vouchers_insert_staff policy —
  /// the caller must independently confirm `canManageUsers` / school-
  /// admin-of-this-school before showing this in the UI).
  ///
  /// [premiumTier] is the issuer's choice ONLY for [SchoolRole.student] —
  /// every other role is forced Gold per the fixed premium rules
  /// (redesign item 6), and the argument is ignored for them. When [role]
  /// is student, a linked PARENT voucher (role.parent, premium 'none') is
  /// auto-generated and inserted alongside each student code (redesign
  /// item 4 — School -> Student -> Parent) rather than parent being a
  /// separately issuable role.
  Future<Result<List<SchoolVoucher>>> issueVouchers({
    required School school,
    required SchoolRole role,
    required String issuedByUid,
    int count = 1,
    VoucherPremiumTier premiumTier = VoucherPremiumTier.silver,
  }) async {
    if (count < 1 || count > 200) {
      return const Failure('Generate between 1 and 200 codes at a time', null);
    }
    if (role == SchoolRole.parent) {
      return const Failure(
          'Parent codes are generated automatically alongside student codes — issue a Student code instead',
          null);
    }
    try {
      final effectivePremium = role.isAlwaysGold ? VoucherPremiumTier.gold : premiumTier;
      final issued = <SchoolVoucher>[];
      final rows = <Map<String, dynamic>>[];
      final now = DateTime.now();
      for (var i = 0; i < count; i++) {
        // Collision odds are astronomically low (31^6 random chars per
        // school+role+premium prefix) — a plain generate-and-write is
        // safe without a pre-check, same trust level Voucher.generateCode
        // already operates at.
        final code = SchoolVoucher.generateCode(
            schoolCode: school.code, role: role, premiumTier: effectivePremium);
        final voucher = SchoolVoucher(
          id: code,
          schoolId: school.id,
          schoolCode: school.code,
          role: role,
          premiumTier: effectivePremium,
          createdAt: now,
          createdByUid: issuedByUid,
        );
        rows.add(voucher.toSupabase());
        issued.add(voucher);

        if (role == SchoolRole.student) {
          final parentCode = SchoolVoucher.generateCode(
              schoolCode: school.code, role: SchoolRole.parent, premiumTier: null);
          final parentVoucher = SchoolVoucher(
            id: parentCode,
            schoolId: school.id,
            schoolCode: school.code,
            role: SchoolRole.parent,
            premiumTier: null,
            linkedStudentVoucherId: code,
            createdAt: now,
            createdByUid: issuedByUid,
          );
          rows.add(parentVoucher.toSupabase());
          issued.add(parentVoucher);
        }
      }
      await _supabase.from('school_vouchers').insert(rows);
      return Success(issued);
    } catch (e) {
      return Failure('Failed to generate voucher codes', e);
    }
  }

  /// Every code issued for [schoolId], newest first, with who redeemed
  /// each one. RLS (school_vouchers_select_staff) limits this to that
  /// school's own admins and super admins.
  Future<Result<List<IssuedVoucher>>> listVouchers(String schoolId) async {
    if (schoolId.isEmpty) return const Success([]);
    try {
      final rows = await _supabase
          .from('school_vouchers')
          .select()
          .eq('school_id', schoolId)
          .order('created_at')
          .limit(2000);
      final redeemerIds = {
        for (final r in rows)
          if (r['redeemed_by_user_id'] != null) r['redeemed_by_user_id'] as String,
      };
      final names = <String, String>{};
      if (redeemerIds.isNotEmpty) {
        final users = await _supabase.from('users').select('id, name').inFilter('id', redeemerIds.toList());
        for (final u in users) {
          names[u['id'] as String] = (u['name'] as String?) ?? '';
        }
      }
      return Success([
        for (final r in rows)
          IssuedVoucher(
            voucher: SchoolVoucher.fromSupabase(r),
            redeemedByName: names[r['redeemed_by_user_id']],
            redeemedAt: DateTime.tryParse(r['redeemed_at']?.toString() ?? ''),
          ),
      ]);
    } catch (e) {
      return Failure('Couldn\'t load issued codes. Check your connection and try again.', e);
    }
  }

  /// [classLevel] folds "which class am I in" into the same redemption
  /// step for student vouchers, rather than granting access and then
  /// presenting a separate wall right after.
  ///
  /// Passes this app's fixed [Branding.current.voucherPrefix] (GH for
  /// greenhills_app, LB for ladybird_app) as the RPC's tenant check —
  /// server-side enforcement that a Green Hills code can never be
  /// redeemed through the Ladybird app or vice versa (redesign item 7).
  Future<Result<SchoolRedemptionOutcome>> redeemSchoolVoucher({
    required String userId,
    required String rawCode,
    String? classLevel,
  }) async {
    if (userId.isEmpty) {
      return const Failure('You need to be signed in to link a school', null);
    }
    if (!SchoolVoucher.isPlausibleCode(rawCode)) {
      return const Failure('That code doesn\'t look right — check it and try again', null);
    }
    final normalized = SchoolVoucher.normalizeCode(rawCode);

    try {
      final rows = await _supabase.rpc('redeem_school_voucher', params: {
        'p_code': normalized,
        'p_expected_prefix': Branding.current.voucherPrefix,
        'p_class_level': classLevel,
      }) as List;
      final result = rows.first as Map<String, dynamic>;
      final schoolId = result['out_school_id'] as String;
      final role = SchoolRoleX.fromName(result['out_role']?.toString() ?? '') ?? SchoolRole.student;
      final premiumTier = _premiumFromRpc(result['out_premium_tier']?.toString());

      final school = await SchoolRepository.instance.getByIdOnce(schoolId);
      if (school == null) {
        return const Failure('School code was valid but the school record is missing — contact support', null);
      }
      return Success(SchoolRedemptionOutcome(school: school, role: role, premiumTier: premiumTier));
    } on PostgrestException catch (e) {
      return Failure(e.message, e);
    } catch (e) {
      return Failure('Failed to link your school account', e);
    }
  }

  static VoucherPremiumTier? _premiumFromRpc(String? v) {
    if (v == null || v == 'free') return null;
    return VoucherPremiumTier.values.firstWhere((t) => t.name == v, orElse: () => VoucherPremiumTier.silver);
  }
}

class IssuedVoucher {
  final SchoolVoucher voucher;
  final String? redeemedByName;
  final DateTime? redeemedAt;
  const IssuedVoucher({required this.voucher, this.redeemedByName, this.redeemedAt});
  bool get isUsed => voucher.status == SchoolVoucherStatus.redeemed;
}
