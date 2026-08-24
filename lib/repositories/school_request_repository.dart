// lib/repositories/school_request_repository.dart
// Real Firestore-backed School Connect requests -- school_requests/{id}.
// New collection; see firestore.rules for the matching new rule block
// (school_requests/{id}, added alongside this file).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/result.dart';
import '../models/school_request.dart';

class SchoolRequestRepository {
  SchoolRequestRepository._();
  static final SchoolRequestRepository instance = SchoolRequestRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('school_requests');

  /// A student's own requests, newest first.
  Stream<List<SchoolRequest>> watchForStudent(String studentId) {
    if (studentId.isEmpty) return Stream.value(const []);
    return _col.where('studentId', isEqualTo: studentId).snapshots().map((snap) {
      final list = snap.docs.map(SchoolRequest.fromFirestore).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Every request for a school -- staff inbox. Optionally filtered to
  /// only the still-open ones.
  Stream<List<SchoolRequest>> watchForSchool(String schoolId, {bool openOnly = false}) {
    if (schoolId.isEmpty) return Stream.value(const []);
    Query<Map<String, dynamic>> q = _col.where('schoolId', isEqualTo: schoolId);
    return q.snapshots().map((snap) {
      var list = snap.docs.map(SchoolRequest.fromFirestore).toList();
      if (openOnly) {
        list = list.where((r) => r.status != SchoolRequestStatus.resolved).toList();
      }
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Future<Result<void>> submit(SchoolRequest request) async {
    try {
      await _col.add(request.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to submit request', e);
    }
  }

  /// Staff responding to a request -- a targeted field update, NOT
  /// request.toFirestore() (which would stamp a fresh serverTimestamp
  /// over the original createdAt).
  Future<Result<void>> respond(String requestId, {required String response, required SchoolRequestStatus status}) async {
    try {
      await _col.doc(requestId).update({
        'staffResponse': response,
        'status': status.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save response', e);
    }
  }
}
