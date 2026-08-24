// lib/repositories/school_access_repository.dart
// The redemption half of architecture brief items 2-6: a school app must
// only be accessible to someone holding a valid voucher for THAT school,
// never to any signed-in Academia account. Mirrors
// entitlement_repository.dart's redeemVoucher() transaction shape closely
// on purpose — same proven pattern (doc-id-keyed lookup so the whole
// check-then-write happens inside one transaction, no query-then-race
// gap), applied to school membership instead of premium entitlement.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';
import '../models/app_user.dart';
import '../models/school.dart';
import '../models/school_voucher.dart';
import 'school_repository.dart';

class SchoolRedemptionOutcome {
  final School school;
  final SchoolRole role;
  const SchoolRedemptionOutcome({required this.school, required this.role});
}

class _RedeemException implements Exception {
  final String message;
  _RedeemException(this.message);
}

class SchoolAccessRepository {
  SchoolAccessRepository._();
  static final SchoolAccessRepository instance = SchoolAccessRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _voucherDoc(String code) =>
      _db.collection('school_vouchers').doc(code);

  /// Staff-only (enforced by firestore.rules `school_vouchers/{code}`
  /// create rule — the caller must independently confirm `canManageUsers`
  /// / school-admin-of-this-school before showing this in the UI, same
  /// division of labor as EntitlementRepository's voucher issuance).
  Future<Result<List<SchoolVoucher>>> issueVouchers({
    required School school,
    required SchoolRole role,
    required String issuedByUid,
    int count = 1,
  }) async {
    if (count < 1 || count > 200) {
      return const Failure('Generate between 1 and 200 codes at a time', null);
    }
    try {
      final batch = _db.batch();
      final issued = <SchoolVoucher>[];
      for (var i = 0; i < count; i++) {
        // Collision odds are astronomically low (31^8 suffixes per
        // school+role prefix) — a plain generate-and-write is safe
        // without a pre-check, same trust level Voucher.generateCode
        // already operates at.
        final code = SchoolVoucher.generateCode(schoolCode: school.code, role: role);
        final voucher = SchoolVoucher(
          id: code,
          code: SchoolVoucher.formatCode(code),
          schoolId: school.id,
          schoolCode: school.code,
          role: role,
          createdAt: DateTime.now(),
          createdByUid: issuedByUid,
        );
        batch.set(_voucherDoc(code), voucher.toFirestore());
        issued.add(voucher);
      }
      await batch.commit();
      return Success(issued);
    } catch (e) {
      return Failure('Failed to generate voucher codes', e);
    }
  }

  /// [classLevel] folds item 19's "which class am I in" step into the same
  /// redemption flow for student vouchers, rather than granting access
  /// and then presenting a separate "your class isn't set" wall
  /// immediately after. Optional for every other role.
  Future<Result<SchoolRedemptionOutcome>> redeemSchoolVoucher({
    required AppUser user,
    required String rawCode,
    String? classLevel,
  }) async {
    if (user.id.isEmpty) {
      return const Failure('You need to be signed in to link a school', null);
    }
    if (!SchoolVoucher.isPlausibleCode(rawCode)) {
      return const Failure('That code doesn\'t look right — check it and try again', null);
    }
    final normalized = SchoolVoucher.normalizeCode(rawCode);

    try {
      final voucher = await _db.runTransaction<SchoolVoucher>((tx) async {
        final vSnap = await tx.get(_voucherDoc(normalized));
        if (!vSnap.exists) {
          throw _RedeemException('No school code found matching that entry');
        }
        final v = SchoolVoucher.fromFirestore(normalized, vSnap.data()!);
        if (v.status == SchoolVoucherStatus.revoked) {
          throw _RedeemException('This code has been cancelled');
        }
        if (v.status == SchoolVoucherStatus.redeemed) {
          throw _RedeemException('This code has already been used');
        }

        tx.update(_voucherDoc(normalized), {
          'status': SchoolVoucherStatus.redeemed.name,
          'redeemedAt': DateTime.now().toIso8601String(),
          'redeemedByUserId': user.id,
        });

        final userRef = _db.collection(AppConstants.colUsers).doc(user.id);
        final userUpdates = <String, dynamic>{
          'schoolId': v.schoolId,
          'schoolRole': v.role.name,
          'schoolVoucherRef': normalized,
        };
        // Only ever raises content privilege, never lowers it — a
        // platform admin redeeming a student code stays a platform admin.
        if (!user.hasMinRole(v.role.contentRole)) {
          userUpdates['role'] = v.role.contentRole.name;
        }
        if (v.role == SchoolRole.classMaster && classLevel != null && classLevel.isNotEmpty) {
          userUpdates['classMasterOfClass'] = classLevel;
        }
        if (classLevel != null && classLevel.isNotEmpty) {
          userUpdates['classLevel'] = classLevel;
        }
        tx.update(userRef, userUpdates);

        return v;
      });

      final school = await SchoolRepository.instance.getByIdOnce(voucher.schoolId);
      if (school == null) {
        return const Failure('School code was valid but the school record is missing — contact support', null);
      }
      return Success(SchoolRedemptionOutcome(school: school, role: voucher.role));
    } on _RedeemException catch (e) {
      return Failure(e.message, e);
    } catch (e) {
      return Failure('Failed to link your school account', e);
    }
  }
}
