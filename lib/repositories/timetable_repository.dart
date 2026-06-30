// lib/repositories/timetable_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class TimetableRepository {
  TimetableRepository._();
  static final TimetableRepository instance = TimetableRepository._();
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(AppConstants.colSchools).doc(schoolId)
         .collection(AppConstants.colTimetable);

  Stream<List<TimetableSlot>> watchAll(String schoolId) =>
      _col(schoolId).orderBy('dayOfWeek').snapshots()
          .map((s) => s.docs.map(TimetableSlot.fromFirestore).toList());

  Stream<List<TimetableSlot>> watchForClass(String schoolId, String classGroup) =>
      _col(schoolId).where('classGroup', isEqualTo: classGroup)
          .orderBy('dayOfWeek').snapshots()
          .map((s) => s.docs.map(TimetableSlot.fromFirestore).toList());

  Stream<List<TimetableSlot>> watchForLecturer(String schoolId, String lecturerId) =>
      _col(schoolId).where('lecturerId', isEqualTo: lecturerId)
          .orderBy('dayOfWeek').snapshots()
          .map((s) => s.docs.map(TimetableSlot.fromFirestore).toList());

  Future<Result<void>> add(TimetableSlot slot) async {
    try {
      await _col(slot.schoolId).add(slot.toFirestore());
      return const Success(null);
    } catch (e) { return Failure('Failed to add slot', e); }
  }

  Future<Result<void>> delete(String schoolId, String slotId) async {
    try {
      await _col(schoolId).doc(slotId).delete();
      return const Success(null);
    } catch (e) { return Failure('Failed to delete slot', e); }
  }
}
