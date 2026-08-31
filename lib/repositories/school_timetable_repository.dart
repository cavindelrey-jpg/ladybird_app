// lib/repositories/school_timetable_repository.dart
// The official, admin-authored School Timetable. No Postgres table yet —
// zero real data at migration time; an honest stub rather than a
// fabricated schema.

import '../core/result.dart';
import '../models/school_timetable_slot.dart';

class SchoolTimetableRepository {
  SchoolTimetableRepository._();
  static final SchoolTimetableRepository instance = SchoolTimetableRepository._();

  static const String _notAvailable = 'School timetable isn\'t available yet.';

  /// Every slot for [classLevel] in [schoolId], ordered for display.
  Stream<List<SchoolTimetableSlot>> watchForClass(String schoolId, String classLevel) =>
      Stream.value(const []);

  /// Today's slots only, for [classLevel].
  Stream<List<SchoolTimetableSlot>> watchTodayForClass(String schoolId, String classLevel) =>
      Stream.value(const []);

  Future<Result<void>> add(SchoolTimetableSlot slot) async => const Failure(_notAvailable, null);

  Future<Result<void>> update(SchoolTimetableSlot slot) async => const Failure(_notAvailable, null);

  Future<Result<void>> delete(String schoolId, String slotId) async => const Failure(_notAvailable, null);
}
