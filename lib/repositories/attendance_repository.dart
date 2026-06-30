// lib/repositories/attendance_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class AttendanceRepository {
  AttendanceRepository._();
  static final AttendanceRepository instance = AttendanceRepository._();
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(AppConstants.colSchools).doc(schoolId)
         .collection(AppConstants.colAttendance);

  Future<List<AttendanceRecord>> getForDate({
    required String schoolId, required String courseId, required DateTime date,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end   = start.add(const Duration(days: 1));
    final snap  = await _col(schoolId)
        .where('courseId', isEqualTo: courseId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map(AttendanceRecord.fromFirestore).toList();
  }

  Stream<List<AttendanceRecord>> watchStudentAttendance({
    required String schoolId, required String courseId, required String studentId,
  }) => _col(schoolId)
      .where('courseId', isEqualTo: courseId)
      .where('studentId', isEqualTo: studentId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AttendanceRecord.fromFirestore).toList());

  Future<Result<void>> markBatch({
    required String schoolId, required List<AttendanceRecord> records,
  }) async {
    try {
      final batch = _db.batch();
      for (final r in records) {
        // compound key ensures one record per student per course per date
        final key = '${r.courseId}_${r.studentId}_${r.date.toIso8601String().substring(0,10)}';
        batch.set(_col(schoolId).doc(key), r.toFirestore(), SetOptions(merge: true));
      }
      await batch.commit();
      return const Success(null);
    } catch (e) { return Failure('Failed to save attendance', e); }
  }

  Future<AttendanceSummary> getSummary({
    required String schoolId, required String courseId, required String studentId,
  }) async {
    final snap = await _col(schoolId)
        .where('courseId', isEqualTo: courseId)
        .where('studentId', isEqualTo: studentId).get();
    final recs = snap.docs.map(AttendanceRecord.fromFirestore).toList();
    return AttendanceSummary(
      total:   recs.length,
      present: recs.where((r) => r.status == AttendanceStatus.present).length,
      absent:  recs.where((r) => r.status == AttendanceStatus.absent).length,
      late:    recs.where((r) => r.status == AttendanceStatus.late).length,
      excused: recs.where((r) => r.status == AttendanceStatus.excused).length,
    );
  }
}
