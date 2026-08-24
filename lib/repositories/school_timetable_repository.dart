// lib/repositories/school_timetable_repository.dart
// CRUD + reads for the official School Timetable --
// schools/{schoolId}/timetable/{id}, scoped by classLevel client-side
// (a class's timetable is read by every student in it, filtered from
// the whole school's slot list rather than a separate collection per
// class -- keeps the write side simple: one collection per school).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/result.dart';
import '../models/school_timetable_slot.dart';

class SchoolTimetableRepository {
  SchoolTimetableRepository._();
  static final SchoolTimetableRepository instance = SchoolTimetableRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) => _db
      .collection(AppConstants.colSchools)
      .doc(schoolId)
      .collection('timetable');

  /// Every slot for [classLevel] in [schoolId], ordered for display --
  /// by day first, then start time within each day.
  Stream<List<SchoolTimetableSlot>> watchForClass(String schoolId, String classLevel) {
    if (schoolId.isEmpty || classLevel.isEmpty) return Stream.value(const []);
    return _col(schoolId)
        .where('classLevel', isEqualTo: classLevel)
        .snapshots()
        .map((snap) {
      final slots = snap.docs
          .map((d) => SchoolTimetableSlot.fromFirestore(d, schoolId))
          .toList()
        ..sort((a, b) {
          final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
          if (byDay != 0) return byDay;
          return a.startTime.compareTo(b.startTime);
        });
      return slots;
    });
  }

  /// Today's slots only, for [classLevel] -- powers a Home-style "today's
  /// periods" view the same way PersonalStudyRepository.watchToday does
  /// for the personal Study Plan.
  Stream<List<SchoolTimetableSlot>> watchTodayForClass(String schoolId, String classLevel) {
    final today = DateTime.now().weekday;
    return watchForClass(schoolId, classLevel)
        .map((slots) => slots.where((s) => s.dayOfWeek == today).toList());
  }

  Future<Result<void>> add(SchoolTimetableSlot slot) async {
    try {
      await _col(slot.schoolId).add(slot.toFirestore());
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add timetable slot', e);
    }
  }

  Future<Result<void>> update(SchoolTimetableSlot slot) async {
    try {
      await _col(slot.schoolId).doc(slot.id).set(slot.toFirestore(), SetOptions(merge: true));
      return const Success(null);
    } catch (e) {
      return Failure('Failed to update timetable slot', e);
    }
  }

  Future<Result<void>> delete(String schoolId, String slotId) async {
    try {
      await _col(schoolId).doc(slotId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete timetable slot', e);
    }
  }
}
