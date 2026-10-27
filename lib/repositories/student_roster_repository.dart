// lib/repositories/student_roster_repository.dart
// Manages school student roster records and class lists.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/branding.dart';
import '../core/offline_cache.dart';
import '../core/realtime_tolerant.dart';
import '../core/result.dart';
import '../models/student_record.dart';

class StudentRosterRepository {
  StudentRosterRepository._();
  static final StudentRosterRepository instance = StudentRosterRepository._();

  static const Map<String, String> _knownSchoolIds = {
    'cfpmi': '446007a8-4389-40eb-bfa7-5452541b5a1f',
    'cf': '446007a8-4389-40eb-bfa7-5452541b5a1f',
    'ladybird': 'e57702a0-91b1-4dd3-8d31-29bb928d3114',
    'lb': 'e57702a0-91b1-4dd3-8d31-29bb928d3114',
    'green_hill': '93f2afa1-aaa1-4d15-86e8-41a15b1f94c2',
    'gh': '93f2afa1-aaa1-4d15-86e8-41a15b1f94c2',
  };

  static String resolveSchoolId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      final eff = Branding.current.effectiveSchoolId?.toLowerCase() ?? '';
      return _knownSchoolIds[eff] ?? _knownSchoolIds['ladybird'] ?? _knownSchoolIds['cfpmi']!;
    }
    return _knownSchoolIds[trimmed.toLowerCase()] ?? trimmed;
  }

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseQueryBuilder? get _table => _db?.from('school_students');

  Future<Result<List<StudentRecord>>> getStudents(String schoolId, {String? classLevel}) async {
    final resolvedSchoolId = resolveSchoolId(schoolId);
    final cacheKey = 'roster_${resolvedSchoolId}_${classLevel ?? 'all'}';
    final fallbackKey = 'roster_${schoolId}_${classLevel ?? 'all'}';

    try {
      // 1. Check local cache first to ensure imported/added records are never lost
      var cached = await OfflineCache.instance.get<List<StudentRecord>>(
        cacheKey,
        (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
      );
      if (cached == null || cached.isEmpty) {
        cached = await OfflineCache.instance.get<List<StudentRecord>>(
          fallbackKey,
          (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
        );
      }

      final list = await OfflineCache.instance.fetch<List<StudentRecord>>(
        cacheKey,
        () async {
          final tableQuery = _table;
          if (tableQuery != null) {
            try {
              var query = tableQuery.select().eq('school_id', resolvedSchoolId);
              if (classLevel != null && classLevel.isNotEmpty) {
                query = query.eq('class_level', classLevel);
              }
              final rows = await query.order('student_name', ascending: true);
              final remoteStudents = (rows as List).map((r) => StudentRecord.fromMap(r as Map<String, dynamic>)).toList();
              final mergedMap = {for (final s in (cached ?? <StudentRecord>[])) s.id: s};
              for (final s in remoteStudents) {
                mergedMap[s.id] = s;
              }
              return mergedMap.values.toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            } catch (_) {}
          }

          // Fallback: check users table for enrolled student accounts
          final db = _db;
          if (db != null) {
            try {
              var uQuery = db
                  .from('users')
                  .select('id, name, official_name, student_name, username, class_level, phone')
                  .eq('institution_id', resolvedSchoolId)
                  .eq('role', 'student');
              if (classLevel != null && classLevel.isNotEmpty) {
                uQuery = uQuery.eq('class_level', classLevel);
              }
              final uRows = await uQuery.order('name', ascending: true);
              final userStudents = (uRows as List).map((r) {
                final official = (r['official_name'] as String?) ??
                    (r['student_name'] as String?) ??
                    (r['name'] as String?) ??
                    'Student';
                final username = (r['username'] as String?) ?? (r['name'] as String?);
                return StudentRecord(
                  id: r['id'] as String,
                  schoolId: resolvedSchoolId,
                  name: official,
                  username: username,
                  accountId: r['id'] as String,
                  classLevel: (r['class_level'] as String?) ?? (classLevel ?? ''),
                  parentContact: r['phone'] as String?,
                );
              }).toList();

              final mergedMap = {for (final s in (cached ?? <StudentRecord>[])) s.id: s};
              for (final s in userStudents) {
                mergedMap[s.id] = s;
              }
              return mergedMap.values.toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            } catch (_) {}

            // Check student_accounts table
            try {
              var sQuery = db
                  .from('student_accounts')
                  .select('account_id, student_name, class_level')
                  .eq('institution_id', resolvedSchoolId);
              if (classLevel != null && classLevel.isNotEmpty) {
                sQuery = sQuery.eq('class_level', classLevel);
              }
              final sRows = await sQuery.order('student_name', ascending: true);
              final seatStudents = (sRows as List).map((r) => StudentRecord(
                id: r['account_id']?.toString() ?? '',
                schoolId: resolvedSchoolId,
                name: (r['student_name'] as String?) ?? 'Student',
                classLevel: (r['class_level'] as String?) ?? (classLevel ?? ''),
              )).toList();

              final mergedMap = {for (final s in (cached ?? <StudentRecord>[])) s.id: s};
              for (final s in seatStudents) {
                mergedMap[s.id] = s;
              }
              return mergedMap.values.toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
    final resolvedSchoolId = resolveSchoolId(schoolId);
    final tableQuery = _table;
    if (tableQuery != null) {
      try {
        var stream = tableQuery
            .stream(primaryKey: ['id'])
            .eq('school_id', resolvedSchoolId)
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
    final resolvedSchoolId = resolveSchoolId(student.schoolId);
    final normalized = student.copyWith(schoolId: resolvedSchoolId);
    await _saveLocalFallback(normalized);
    if (student.schoolId != resolvedSchoolId) {
      await _saveLocalFallback(student);
    }

    final db = _db;
    if (db != null) {
      try {
        await db.from('student_accounts').insert({
          'institution_id': resolvedSchoolId,
          'student_name': student.name,
          'class_level': student.classLevel,
          'status': 'unassigned',
        });
      } catch (_) {}

      final tableQuery = _table;
      if (tableQuery != null) {
        try {
          await tableQuery.insert(normalized.toMap());
        } catch (_) {}
      }
    }
    return const Success(null);
  }

  /// Automatically places or links a student onto the school's class list
  /// using their separate account username and official student name.
  Future<Result<StudentRecord>> ensureStudentOnClassList({
    required String schoolId,
    required String classLevel,
    required String officialName,
    String? username,
    String? userId,
    String? matricule,
    String? parentContact,
    String? gender,
  }) async {
    final resolvedSchoolId = resolveSchoolId(schoolId);
    final cleanOfficialName = officialName.trim();
    final cleanClass = classLevel.trim();
    if (cleanOfficialName.isEmpty || cleanClass.isEmpty) {
      return const Failure('Official student name and class level are required', null);
    }

    try {
      final db = _db;
      StudentRecord? existingRecord;

      // 1. Check if student already exists on class list by official student name or matricule
      if (db != null) {
        if (matricule != null && matricule.trim().isNotEmpty) {
          final mRows = await db
              .from('school_students')
              .select()
              .eq('school_id', resolvedSchoolId)
              .eq('class_level', cleanClass)
              .eq('matricule', matricule.trim());
          if (mRows is List && mRows.isNotEmpty) {
            existingRecord = StudentRecord.fromMap(mRows.first as Map<String, dynamic>);
          }
        }
        if (existingRecord == null) {
          final allClassRows = await db
              .from('school_students')
              .select()
              .eq('school_id', resolvedSchoolId)
              .eq('class_level', cleanClass);
          if (allClassRows is List) {
            for (final row in allClassRows) {
              final r = StudentRecord.fromMap(row as Map<String, dynamic>);
              if (r.name.trim().toLowerCase() == cleanOfficialName.toLowerCase()) {
                existingRecord = r;
                break;
              }
            }
          }
        }
      }

      final recordId = existingRecord?.id ??
          (userId != null && userId.isNotEmpty
              ? 'stu_$userId'
              : 'stu_${DateTime.now().millisecondsSinceEpoch}_${cleanOfficialName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}');

      final record = StudentRecord(
        id: recordId,
        schoolId: resolvedSchoolId,
        name: cleanOfficialName,
        username: username ?? existingRecord?.username,
        accountId: userId ?? existingRecord?.accountId,
        classLevel: cleanClass,
        matricule: matricule ?? existingRecord?.matricule,
        parentContact: parentContact ?? existingRecord?.parentContact,
        gender: gender ?? existingRecord?.gender,
        createdAt: existingRecord?.createdAt ?? DateTime.now(),
      );

      // Save to Supabase
      if (db != null) {
        await db.from('school_students').upsert(record.toMap());
      }

      // Also ensure local cache has the new/updated record immediately
      final cacheKey = 'roster_${resolvedSchoolId}_$cleanClass';
      final cached = await OfflineCache.instance.get<List<StudentRecord>>(
        cacheKey,
        (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
      ) ?? <StudentRecord>[];

      final map = {for (final s in cached) s.id: s};
      map[record.id] = record;
      final updatedList = map.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      await OfflineCache.instance.put(
        cacheKey,
        OfflineCache.listToJson(updatedList, (s) => s.toMap()),
      );

      return Success(record);
    } catch (e) {
      return Failure('Failed to place student on class list', e);
    }
  }

  Future<Result<void>> batchUpsert(String schoolId, List<StudentRecord> students) async {
    if (students.isEmpty) return const Success(null);
    final resolvedSchoolId = resolveSchoolId(schoolId);
    final normalizedStudents = students.map((s) => s.copyWith(schoolId: resolvedSchoolId)).toList();

    // 1. Immediately persist locally so 100% of imported students appear in the UI
    await _saveAllLocalFallback(resolvedSchoolId, normalizedStudents);
    if (schoolId != resolvedSchoolId) {
      await _saveAllLocalFallback(schoolId, students);
    }

    // 2. Sync to Supabase
    final tableQuery = _table;
    if (tableQuery != null) {
      try {
        final rows = normalizedStudents.map((s) => s.toMap()).toList();
        await tableQuery.upsert(rows);
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<Result<void>> deleteStudent(String studentId, String schoolId) async {
    final resolvedSchoolId = resolveSchoolId(schoolId);
    // 1. Remove from local cache
    try {
      const classes = [
        'Form 1', 'Form 2', 'Form 3', 'Form 4', 'Form 5',
        'Lower Sixth', 'Upper Sixth',
        'Lower Sixth Arts', 'Lower Sixth Science',
        'Upper Sixth Arts', 'Upper Sixth Science',
        'Undergraduate', 'All Levels', 'all',
      ];
      final schoolIds = {schoolId, resolvedSchoolId};
      for (final sid in schoolIds) {
        if (sid.isEmpty) continue;
        for (final c in classes) {
          final key = 'roster_${sid}_$c';
          final cached = await OfflineCache.instance.get<List<StudentRecord>>(
            key,
            (json) => OfflineCache.listFromJson(json, (j) => StudentRecord.fromMap(j)),
          );
          if (cached != null) {
            final next = cached.where((s) => s.id != studentId).toList();
            await OfflineCache.instance.put(key, OfflineCache.listToJson(next, (s) => s.toMap()));
          }
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
    final idsToSave = {schoolId, resolveSchoolId(schoolId)};
    for (final sid in idsToSave) {
      if (sid.isEmpty) continue;
      // 1. Group by class
      final byClass = <String, List<StudentRecord>>{};
      for (final s in students) {
        byClass.putIfAbsent(s.classLevel, () => []).add(s);
      }
      // 2. For each class, read existing cached list, merge by id, and put back
      for (final entry in byClass.entries) {
        final cls = entry.key;
        final key = 'roster_${sid}_$cls';
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
      // 3. Also update 'roster_${sid}_all'
      final allKey = 'roster_${sid}_all';
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
}
