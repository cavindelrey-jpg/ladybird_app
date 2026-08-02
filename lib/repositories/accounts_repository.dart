// lib/repositories/accounts_repository.dart
// Manages school seat lifecycle. No in-memory seed data.
//
// Seat IDs are short, human-typeable sequential codes (e.g. "0007") — not
// Firestore auto-IDs — because a seat ID is half of the serial number a
// student types by hand: {schoolCode}-{seatId}. See resolveSeat() below,
// which is the pre-claim check the serial-number entry screen calls
// before it lets the app re-brand and hand off to account claiming.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class AccountsRepository {
  AccountsRepository._();
  static final AccountsRepository instance = AccountsRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _seats(String schoolId) =>
      _db.collection(AppConstants.colSchools)
         .doc(schoolId)
         .collection(AppConstants.colSeats);

  Stream<List<StudentAccount>> watchAccounts(String schoolId) {
    return _seats(schoolId).snapshots().map((snap) =>
        snap.docs.map((d) => StudentAccount.fromFirestore(d.id, d.data())).toList());
  }

  Future<List<StudentAccount>> getByStatus(
      String schoolId, AccountStatus status) async {
    final snap = await _seats(schoolId)
        .where('status', isEqualTo: status.name)
        .get();
    return snap.docs
        .map((d) => StudentAccount.fromFirestore(d.id, d.data()))
        .toList();
  }

  /// Look up a single seat by its serial-number suffix, for the pre-claim
  /// check the onboarding screen runs before it lets a serial number
  /// through. Does not mutate anything — purely a "is this claimable" read.
  Future<Result<StudentAccount>> resolveSeat({
    required String schoolId,
    required String seatId,
  }) async {
    try {
      final doc = await _seats(schoolId).doc(seatId).get();
      if (!doc.exists) {
        return const Failure(
            'That serial number wasn\'t recognized. Double-check it with your school administrator.',
            null);
      }
      final seat = StudentAccount.fromFirestore(doc.id, doc.data()!);
      if (seat.status == AccountStatus.suspended) {
        return const Failure(
            'This serial number has been suspended. Contact your school administrator.',
            null);
      }
      if (seat.adminAccessRevoked) {
        // Already claimed and personalized by someone else — the
        // temp password has been overwritten, so it can never be
        // re-claimed. Not an error state, just routes to sign-in instead.
        return const Failure(
            'This serial number has already been activated. Sign in with the account\'s email and password instead.',
            null);
      }
      if (seat.status == AccountStatus.unassigned) {
        return const Failure(
            'This serial number hasn\'t been activated by your school yet. Ask your administrator to confirm payment.',
            null);
      }
      return Success(seat);
    } catch (e) {
      return Failure('Could not verify that serial number: $e', e);
    }
  }

  /// Creates [count] new seats, numbered sequentially from however many
  /// seats already exist for this school — so seat IDs stay short
  /// ("0001", "0002"...) instead of long Firestore auto-IDs, because the
  /// seat ID is half of what a student has to type by hand.
  Future<Result<void>> createSeat({
    required String schoolId,
    required String classLevel,
    int count = 1,
  }) async {
    try {
      final existing = await _seats(schoolId).count().get();
      final start = existing.count ?? 0;
      final batch = _db.batch();
      for (int i = 0; i < count; i++) {
        final seatId = (start + i + 1).toString().padLeft(4, '0');
        final ref = _seats(schoolId).doc(seatId);
        batch.set(ref, {
          'classLevel': classLevel,
          'status': AccountStatus.unassigned.name,
          'tempPassword': '',
          'adminAccessRevoked': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to create seats', e);
    }
  }

  Future<Result<void>> assignSeat({
    required String schoolId,
    required String seatId,
    required String studentName,
    required String paymentRef,
  }) async {
    try {
      final tempPass = 'TMP${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}';
      await _seats(schoolId).doc(seatId).update({
        'studentName': studentName,
        'status': AccountStatus.assigned.name,
        'tempPassword': tempPass,
        'paymentRef': paymentRef,
        'assignedAt': FieldValue.serverTimestamp(),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to assign seat', e);
    }
  }

  Future<Result<void>> suspend(String schoolId, String seatId) async {
    try {
      await _seats(schoolId).doc(seatId).update({'status': AccountStatus.suspended.name});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to suspend account', e);
    }
  }

  Future<Result<void>> unsuspend(String schoolId, String seatId) async {
    try {
      await _seats(schoolId).doc(seatId).update({'status': AccountStatus.active.name});
      return const Success(null);
    } catch (e) {
      return Failure('Failed to reactivate account', e);
    }
  }
}
