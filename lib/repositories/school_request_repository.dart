// lib/repositories/school_request_repository.dart
// Firestore reads/writes for School Connect submissions. Same shape as
// every other school-scoped repository in this codebase (announcement,
// calendar, timetable): schools/{schoolId}/school_requests/{id}.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/school_request.dart';
import '../core/constants.dart';
import '../core/result.dart';

class SchoolRequestRepository {
  SchoolRequestRepository._();
  static final SchoolRequestRepository instance = SchoolRequestRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) => _db
      .collection(AppConstants.colSchools)
      .doc(schoolId)
      .collection(AppConstants.colSchoolRequests);

  Future<Result<void>> submit(SchoolRequest request) async {
    try {
      await _col(request.schoolId).add(request.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Could not submit this — please try again.', e);
    }
  }

  /// A student's own submissions, newest first — powers School Connect's
  /// "Your Requests" section so every submitted tile has a visible,
  /// trackable outcome instead of vanishing into a write-only form.
  Stream<List<SchoolRequest>> watchMine({
    required String schoolId,
    required String studentId,
  }) {
    if (schoolId.isEmpty || studentId.isEmpty) {
      return Stream<List<SchoolRequest>>.empty();
    }
    return _col(schoolId)
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map(SchoolRequest.fromFirestore).toList());
  }
}
