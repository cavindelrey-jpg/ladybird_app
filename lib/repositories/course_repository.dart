// lib/repositories/course_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class CourseRepository {
  CourseRepository._();
  static final CourseRepository instance = CourseRepository._();
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(AppConstants.colSchools).doc(schoolId)
         .collection(AppConstants.colCourses);

  Stream<List<Course>> watchAll(String schoolId) =>
      _col(schoolId).orderBy('name').snapshots()
          .map((s) => s.docs.map(Course.fromFirestore).toList());

  Stream<List<Course>> watchForLecturer(String schoolId, String lecturerId) =>
      _col(schoolId).where('lecturerId', isEqualTo: lecturerId)
          .snapshots().map((s) => s.docs.map(Course.fromFirestore).toList());

  Future<List<Course>> getByIds(String schoolId, List<String> ids) async {
    if (ids.isEmpty) return [];
    final docs = await Future.wait(ids.map((id) => _col(schoolId).doc(id).get()));
    return docs.where((d) => d.exists).map(Course.fromFirestore).toList();
  }

  Future<Result<String>> create(Course c) async {
    try {
      final ref = await _col(c.schoolId).add(c.toFirestore());
      return Success(ref.id);
    } catch (e) { return Failure('Failed to create course', e); }
  }

  Future<Result<void>> update(Course c) async {
    try {
      // toFirestore() always stamps a fresh createdAt — strip it here so
      // editing a course doesn't silently overwrite its original creation
      // date (which sorting/audit trails may rely on).
      final data = c.toFirestore()..remove('createdAt');
      await _col(c.schoolId).doc(c.id).update(data);
      return const Success(null);
    } catch (e) { return Failure('Failed to update course', e); }
  }

  /// Live single-course stream, for the detail page — updates instantly
  /// if a lecturer/admin edits it while a student has it open.
  Stream<Course?> watchOne(String schoolId, String courseId) =>
      _col(schoolId).doc(courseId).snapshots()
          .map((d) => d.exists ? Course.fromFirestore(d) : null);

  /// Live count of enrolled students — courseIds is stored as an array on
  /// each user doc, so this is a collection-group-style array-contains
  /// query, not a stored counter (fine at school scale; revisit with a
  /// denormalized counter if a school's roll grows very large).
  Stream<int> watchEnrollmentCount(String courseId) => _db
      .collection(AppConstants.colUsers)
      .where('courseIds', arrayContains: courseId)
      .snapshots()
      .map((s) => s.docs.length);

  Future<Result<void>> delete(String schoolId, String id) async {
    try {
      await _col(schoolId).doc(id).delete();
      return const Success(null);
    } catch (e) { return Failure('Failed to delete course', e); }
  }

  Future<Result<void>> enrollStudent(String schoolId, String courseId, String uid) async {
    try {
      await _db.collection(AppConstants.colUsers).doc(uid)
          .update({'courseIds': FieldValue.arrayUnion([courseId])});
      return const Success(null);
    } catch (e) { return Failure('Failed to enroll', e); }
  }

  Future<Result<void>> unenrollStudent(String schoolId, String courseId, String uid) async {
    try {
      await _db.collection(AppConstants.colUsers).doc(uid)
          .update({'courseIds': FieldValue.arrayRemove([courseId])});
      return const Success(null);
    } catch (e) { return Failure('Failed to unenroll', e); }
  }
}
