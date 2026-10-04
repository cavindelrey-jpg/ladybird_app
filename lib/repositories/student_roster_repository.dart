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

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseQueryBuilder? get _table => _db?.from('school_students');

  Future<Result<List<StudentRecord>>> getStudents(String schoolId, {String? classLevel}) async {
    if (schoolId.isEmpty) return const Success([]);
    final cacheKey = 'roster_${schoolId}_${classLevel ?? 'all'}';

    try {
      // 1. Check local cache first to ensure imported records are never lost
      final cached = await OfflineCache.instance.get<List<StudentRecord>>(
        cacheKey,
        (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
      );

      final list = await OfflineCache.instance.fetch<List<StudentRecord>>(
        cacheKey,
        () async {
          final tableQuery = _table;
          if (tableQuery != null) {
            try {
              var query = tableQuery.select().eq('school_id', schoolId);
              if (classLevel != null && classLevel.isNotEmpty) {
                query = query.eq('class_level', classLevel);
              }
              final rows = await query.order('student_name', ascending: true);
              final remoteStudents = (rows as List).map((r) => StudentRecord.fromMap(r as Map<String, dynamic>)).toList();
              // Merge with local cache so imported records are never lost
              final mergedMap = {for (final s in (cached ?? <StudentRecord>[])) s.id: s};
              for (final s in remoteStudents) {
                mergedMap[s.id] = s;
              }
              return mergedMap.values.toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            } catch (_) {}
          }

          // If local cache has data, use it directly instead of falling back to user accounts
          if (cached != null && cached.isNotEmpty) {
            return cached;
          }

          // Fallback: check users table for enrolled student accounts
          final db = _db;
          if (db != null) {
            try {
              var uQuery = db
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
            } catch (_) {}
          }

          return cached ?? <StudentRecord>[];
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
    final tableQuery = _table;
    if (tableQuery != null) {
      try {
        var stream = tableQuery
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
      } catch (_) {}
    }
    return Stream.fromFuture(getStudents(schoolId, classLevel: classLevel).then((r) =>
        r is Success<List<StudentRecord>> ? r.value : const <StudentRecord>[]));
  }

  Future<Result<void>> addStudent(StudentRecord student) async {
    await _saveLocalFallback(student);
    final tableQuery = _table;
    if (tableQuery != null) {
      try {
        await tableQuery.insert(student.toMap());
      } catch (_) {}
    }
    return const Success(null);
  }

  Future<Result<void>> batchUpsert(String schoolId, List<StudentRecord> students) async {
    if (students.isEmpty) return const Success(null);

    // 1. Immediately persist locally so 100% of imported students appear in the UI
    await _saveAllLocalFallback(schoolId, students);

    // 2. Sync to Supabase
    final tableQuery = _table;
    if (tableQuery != null) {
      try {
        final rows = students.map((s) => s.toMap()).toList();
        await tableQuery.upsert(rows);
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<Result<void>> deleteStudent(String studentId, String schoolId) async {
    // 1. Remove from local cache
    try {
      const classes = [
        'Form 1', 'Form 2', 'Form 3', 'Form 4', 'Form 5',
        'Lower Sixth', 'Upper Sixth',
        'Lower Sixth Arts', 'Lower Sixth Science',
        'Upper Sixth Arts', 'Upper Sixth Science',
        'Undergraduate', 'All Levels', 'all',
      ];
      for (final c in classes) {
        final key = 'roster_${schoolId}_$c';
        final cached = await OfflineCache.instance.get<List<StudentRecord>>(
          key,
          (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
        );
        if (cached != null) {
          final next = cached.where((s) => s.id != studentId).toList();
          await OfflineCache.instance.put(key, OfflineCache.listToJson(next, (s) => s.toMap()));
        }
      }
    } catch (_) {}

    // 2. Delete from Supabase
    final tableQuery = _table;
    if (tableQuery != null) {
      try {
        await tableQuery.delete().eq('id', studentId);
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<void> _saveLocalFallback(StudentRecord student) async {
    await _saveAllLocalFallback(student.schoolId, [student]);
  }

  Future<void> _saveAllLocalFallback(String schoolId, List<StudentRecord> students) async {
    // 1. Group by class
    final byClass = <String, List<StudentRecord>>{};
    for (final s in students) {
      byClass.putIfAbsent(s.classLevel, () => []).add(s);
    }
    // 2. For each class, read existing cached list, merge by id, and put back
    for (final entry in byClass.entries) {
      final cls = entry.key;
      final key = 'roster_${schoolId}_$cls';
      final existing = await OfflineCache.instance.get<List<StudentRecord>>(
        key,
        (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
      ) ?? [];
      final map = {for (final s in existing) s.id: s};
      for (final s in entry.value) {
        map[s.id] = s;
      }
      final merged = map.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await OfflineCache.instance.put(key, OfflineCache.listToJson(merged, (s) => s.toMap()));
    }
    // 3. Also update 'roster_${schoolId}_all'
    final allKey = 'roster_${schoolId}_all';
    final existingAll = await OfflineCache.instance.get<List<StudentRecord>>(
      allKey,
      (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
    ) ?? [];
    final allMap = {for (final s in existingAll) s.id: s};
    for (final s in students) {
      allMap[s.id] = s;
    }
    final mergedAll = allMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await OfflineCache.instance.put(allKey, OfflineCache.listToJson(mergedAll, (s) => s.toMap()));
  }
}
