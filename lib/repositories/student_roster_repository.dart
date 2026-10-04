// lib/repositories/student_roster_repository.dart
// Manages school student roster records and class lists.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/offline_cache.dart';
import '../core/realtime_tolerant.dart';
import '../core/result.dart';
import '../models/student_record.dart';

class StudentRosterRepository {
  StudentRosterRepository._();
  static final StudentRosterRepository instance = StudentRosterRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _table => _db.from('school_students');

  Future<Result<List<StudentRecord>>> getStudents(String schoolId, {String? classLevel}) async {
    if (schoolId.isEmpty) return const Success([]);
    final cacheKey = 'roster_${schoolId}_${classLevel ?? 'all'}';

    try {
      final list = await OfflineCache.instance.fetch<List<StudentRecord>>(
        cacheKey,
        () async {
          try {
            var query = _table.select().eq('school_id', schoolId);
            if (classLevel != null && classLevel.isNotEmpty) {
              query = query.eq('class_level', classLevel);
            }
            final rows = await query.order('student_name', ascending: true);
            return (rows as List).map((r) => StudentRecord.fromMap(r as Map<String, dynamic>)).toList();
          } catch (_) {
            // Fallback: check users table for enrolled students
            var uQuery = _db
                .from('users')
                .select('id, name, class_level, phone')
                .eq('institution_id', schoolId)
                .eq('role', 'student');
            if (classLevel != null && classLevel.isNotEmpty) {
              uQuery = uQuery.eq('class_level', classLevel);
            }
            final uRows = await uQuery.order('name', ascending: true);
            return (uRows as List).map((r) => StudentRecord(
              id: r['id'] as String,
              schoolId: schoolId,
              name: (r['name'] as String?) ?? 'Student',
              classLevel: (r['class_level'] as String?) ?? (classLevel ?? ''),
              parentContact: r['phone'] as String?,
            )).toList();
          }
        },
        toJson: (items) => OfflineCache.listToJson(items, (s) => s.toMap()),
        fromJson: (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
      );
      return Success(list);
    } catch (e) {
      return Failure('Could not load student roster', e);
    }
  }

  Stream<List<StudentRecord>> watchStudents(String schoolId, {String? classLevel}) {
    if (schoolId.isEmpty) return Stream.value(const []);
    try {
      var stream = _table
          .stream(primaryKey: ['id'])
          .eq('school_id', schoolId)
          .realtimeTolerant();

      return stream.map((rows) {
        var list = rows.map((r) => StudentRecord.fromMap(r)).toList();
        if (classLevel != null && classLevel.isNotEmpty) {
          list = list.where((s) => s.classLevel == classLevel).toList();
        }
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });
    } catch (_) {
      return Stream.fromFuture(getStudents(schoolId, classLevel: classLevel).then((r) =>
          r is Success<List<StudentRecord>> ? r.value : const <StudentRecord>[]));
    }
  }

  Future<Result<void>> addStudent(StudentRecord student) async {
    try {
      await _table.insert(student.toMap());
      await _bustCache(student.schoolId);
      return const Success(null);
    } catch (e) {
      // Local fallback for offline mode
      await _saveLocalFallback(student);
      return const Success(null);
    }
  }

  Future<Result<void>> batchUpsert(String schoolId, List<StudentRecord> students) async {
    if (students.isEmpty) return const Success(null);
    try {
      final rows = students.map((s) => s.toMap()).toList();
      await _table.upsert(rows);
      await _bustCache(schoolId);
      return const Success(null);
    } catch (e) {
      for (final s in students) {
        await _saveLocalFallback(s);
      }
      return const Success(null);
    }
  }

  Future<Result<void>> deleteStudent(String studentId, String schoolId) async {
    try {
      await _table.delete().eq('id', studentId);
      await _bustCache(schoolId);
      return const Success(null);
    } catch (e) {
      return Failure('Could not delete student: $e', e);
    }
  }

  Future<void> _bustCache(String schoolId) async {
    const classes = [
      'Form 1', 'Form 2', 'Form 3', 'Form 4', 'Form 5',
      'Lower Sixth Arts', 'Lower Sixth Science',
      'Upper Sixth Arts', 'Upper Sixth Science',
    ];
    for (final c in classes) {
      await OfflineCache.instance.remove('roster_${schoolId}_$c');
    }
    await OfflineCache.instance.remove('roster_${schoolId}_all');
  }

  Future<void> _saveLocalFallback(StudentRecord student) async {
    final key = 'roster_${student.schoolId}_${student.classLevel}';
    final current = await OfflineCache.instance.fetch<List<StudentRecord>>(
      key,
      () async => [student],
      toJson: (items) => OfflineCache.listToJson(items, (s) => s.toMap()),
      fromJson: (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
    );
    final next = [...current.where((s) => s.id != student.id), student];
    await OfflineCache.instance.put(
      key,
      OfflineCache.listToJson(next, (s) => s.toMap()),
    );
  }
}
