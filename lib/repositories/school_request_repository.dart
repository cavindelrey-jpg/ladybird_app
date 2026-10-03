// lib/repositories/school_request_repository.dart
// School Connect requests (Report an Issue, Leave Request, Fee Inquiry,
// School Request, Give Feedback). No Postgres table yet — zero real data
// at migration time; an honest stub rather than a fabricated schema.

import '../core/result.dart';

import '../models/school_request.dart';

class SchoolRequestRepository {
  SchoolRequestRepository._();
  static final SchoolRequestRepository instance = SchoolRequestRepository._();

  /// A student's own requests, newest first.
  Stream<List<SchoolRequest>> watchForStudent(String studentId) => Stream.value(const []);

  /// Every request for a school -- staff inbox. Optionally filtered to
  /// only the still-open ones.
  Stream<List<SchoolRequest>> watchForSchool(String schoolId, {bool openOnly = false}) =>
      Stream.value(const []);

  Future<Result<void>> submit(SchoolRequest request) async =>
      const Failure('School requests aren\'t available yet.', null);

  /// Staff responding to a request.
  Future<Result<void>> respond(String requestId,
          {required String response, required SchoolRequestStatus status}) async =>
      const Failure('School requests aren\'t available yet.', null);
}
