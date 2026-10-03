// lib/repositories/school_timetable_repository.dart
// The official, admin-authored School Timetable. Backed by
// public.school_timetable_slots (see
// supabase/migrations/20260901030000_school_timetable_slots.sql) --
// write access there mirrors AppUser.canManageSchool exactly, the same
// gate TimetableManagerPage already checks before showing its UI.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../models/school_timetable_slot.dart';
import '../core/realtime_tolerant.dart';

class SchoolTimetableRepository {
  SchoolTimetableRepository._();
  static final SchoolTimetableRepository instance = SchoolTimetableRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _slots => _db.from('school_timetable_slots');

  /// Every slot for [classLevel] in [schoolId], ordered for display.
  /// `.stream()` only supports one server-side `.eq()` filter (same
  /// pattern AcademicContentRepository.watch() already uses) -- filters
  /// down to [classLevel] client-side after streaming the whole school.
  Stream<List<SchoolTimetableSlot>> watchForClass(String schoolId, String classLevel) {
    if (schoolId.isEmpty || classLevel.isEmpty) return Stream.value(const []);
    return _slots
        .stream(primaryKey: ['id'])
        .eq('school_id', schoolId)
        .realtimeTolerant()
        .map((rows) {
      final slots = rows.where((r) => r['class_level'] == classLevel).map(_fromRow).toList()
        ..sort((a, b) {
          final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
          return byDay != 0 ? byDay : a.startTime.compareTo(b.startTime);
        });
      return slots;
    });
  }

  /// Every class's slots at [schoolId] -- what conflict checks need
  /// (a teacher or room clash is across classes).
  Stream<List<SchoolTimetableSlot>> watchForSchool(String schoolId) {
    if (schoolId.isEmpty) return Stream.value(const []);
    return _slots.stream(primaryKey: ['id']).eq('school_id', schoolId)
        .realtimeTolerant().map((rows) => rows.map(_fromRow).toList());
  }

  /// Today's slots only, for [classLevel].
  Stream<List<SchoolTimetableSlot>> watchTodayForClass(String schoolId, String classLevel) {
    final today = DateTime.now().weekday;
    return watchForClass(schoolId, classLevel).map((all) => all.where((s) => s.dayOfWeek == today).toList());
  }

  Future<Result<void>> add(SchoolTimetableSlot slot) async {
    try {
      await _slots.insert(_toRow(slot));
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t save that period', e);
    }
  }

  Future<Result<void>> update(SchoolTimetableSlot slot) async {
    try {
      await _slots.update(_toRow(slot)).eq('id', slot.id);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t update that period', e);
    }
  }

  Future<Result<void>> delete(String schoolId, String slotId) async {
    try {
      await _slots.delete().eq('id', slotId).eq('school_id', schoolId);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t delete that period', e);
    }
  }

  Map<String, dynamic> _toRow(SchoolTimetableSlot s) => {
        'school_id': s.schoolId,
        'class_level': s.classLevel,
        'day_of_week': s.dayOfWeek,
        'start_time': s.startTime,
        'end_time': s.endTime,
        'subject': s.subject,
        'teacher_name': s.teacherName,
        'room': s.room,
      };

  SchoolTimetableSlot _fromRow(Map<String, dynamic> row) => SchoolTimetableSlot(
        id: row['id']?.toString() ?? '',
        schoolId: row['school_id']?.toString() ?? '',
        classLevel: row['class_level']?.toString() ?? '',
        dayOfWeek: (row['day_of_week'] as num?)?.toInt() ?? 1,
        startTime: row['start_time']?.toString() ?? '',
        endTime: row['end_time']?.toString() ?? '',
        subject: row['subject']?.toString() ?? '',
        teacherName: row['teacher_name']?.toString() ?? '',
        room: row['room']?.toString(),
      );
}
