// lib/repositories/assignment_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class AssignmentRepository {
  AssignmentRepository._();
  static final AssignmentRepository instance = AssignmentRepository._();
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(AppConstants.colSchools).doc(schoolId)
         .collection(AppConstants.colAssignments);

  CollectionReference<Map<String, dynamic>> _subs(String schoolId, String aid) =>
      _col(schoolId).doc(aid).collection(AppConstants.colSubmissions);

  Stream<List<Assignment>> watchForLecturer(String schoolId, String lecturerId) =>
      _col(schoolId).where('lecturerId', isEqualTo: lecturerId)
          .orderBy('dueDate', descending: true).snapshots()
          .map((s) => s.docs.map(Assignment.fromFirestore).toList());

  Stream<List<Assignment>> watchForStudent(String schoolId, List<String> courseIds) {
    if (courseIds.isEmpty) return Stream.value([]);
    return _col(schoolId)
        .where('courseId', whereIn: courseIds.take(10).toList())
        .where('status', isEqualTo: AssignmentStatus.published.name)
        .orderBy('dueDate').snapshots()
        .map((s) => s.docs.map(Assignment.fromFirestore).toList());
  }

  Future<Result<String>> create(Assignment a) async {
    try {
      final ref = await _col(a.schoolId).add(a.toFirestore());
      return Success(ref.id);
    } catch (e) { return Failure('Failed to create assignment', e); }
  }

  Future<Result<void>> delete(String schoolId, String id) async {
    try {
      await _col(schoolId).doc(id).delete();
      return const Success(null);
    } catch (e) { return Failure('Failed to delete assignment', e); }
  }

  Stream<List<AssignmentSubmission>> watchSubmissions(String schoolId, String aid) =>
      _subs(schoolId, aid).orderBy('submittedAt', descending: true).snapshots()
          .map((s) => s.docs.map(AssignmentSubmission.fromFirestore).toList());

  Future<AssignmentSubmission?> getStudentSubmission(
      String schoolId, String aid, String studentId) async {
    final snap = await _subs(schoolId, aid)
        .where('studentId', isEqualTo: studentId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return AssignmentSubmission.fromFirestore(snap.docs.first);
  }

  Future<Result<void>> submit(String schoolId, String aid, AssignmentSubmission sub) async {
    try {
      await _subs(schoolId, aid).doc(sub.studentId).set(sub.toFirestore());
      return const Success(null);
    } catch (e) { return Failure('Failed to submit', e); }
  }

  Future<Result<void>> grade({
    required String schoolId, required String aid,
    required String studentId, required int score, required String feedback,
  }) async {
    try {
      await _subs(schoolId, aid).doc(studentId).update({
        'score': score, 'feedback': feedback,
        'status': SubmissionStatus.graded.name,
        'gradedAt': FieldValue.serverTimestamp(),
      });
      return const Success(null);
    } catch (e) { return Failure('Failed to grade', e); }
  }
}
