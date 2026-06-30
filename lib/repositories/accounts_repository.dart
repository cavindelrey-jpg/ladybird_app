// lib/repositories/accounts_repository.dart
// Manages school seat lifecycle. No in-memory seed data.

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

  Future<Result<void>> createSeat({
    required String schoolId,
    required String classLevel,
    int count = 1,
  }) async {
    try {
      final batch = _db.batch();
      for (int i = 0; i < count; i++) {
        final ref = _seats(schoolId).doc();
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
