// lib/repositories/teacher_management_repository.dart
// Backs the admin Teacher Management screen: finding staff and setting
// their (subject, classLevel) teaching assignments + class-master status.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/core.dart';
import '../models/app_user.dart';
import '../models/teaching_assignment.dart';
import '../core/offline_cache.dart';

class TeacherManagementRepository {
  TeacherManagementRepository._();
  static final TeacherManagementRepository instance = TeacherManagementRepository._();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Staff at [schoolId] whose name contains [query].
  Future<List<AppUser>> searchStaff(String schoolId, String query) async {
    if (schoolId.isEmpty || query.trim().isEmpty) return const [];
    final allStaff = await staffOnce(schoolId);
    final q = query.trim().toLowerCase();
    return allStaff.where((u) => u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)).toList();
  }

  /// Every staff member (lecturer or above) at [schoolId].
  /// Merges local OfflineCache and Supabase users table so imported teachers are preserved.
  Future<List<AppUser>> staffOnce(String schoolId) async {
    if (schoolId.isEmpty) return const [];
    final cached = await _getLocalStaff(schoolId);

    final db = _db;
    if (db != null) {
      try {
        final rows = await db
            .from('users')
            .select()
            .eq('institution_id', schoolId)
            .not('role', 'in', '(student,guest)')
            .order('name_lower', ascending: true);
        final remote = rows.map(AppUser.fromSupabase).toList();

        // Merge remote with local cache so newly provisioned teachers are never lost
        final map = {for (final u in cached) u.id: u};
        for (final u in remote) {
          map[u.id] = u;
        }
        final merged = map.values.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        await _setLocalStaff(schoolId, merged);
        return merged;
      } catch (_) {}
    }
    return cached;
  }

  /// Every staff member at [schoolId] who already has at least one teaching
  /// assignment or is a class master.
  Future<List<AppUser>> assignedStaffOnce(String schoolId) async {
    final staff = await staffOnce(schoolId);
    return staff.where((u) => u.teachingAssignments.isNotEmpty || u.classMasterOfClass != null).toList();
  }

  Future<Result<void>> createOrRegisterStaff({
    required String schoolId,
    required String id,
    required String name,
    required String email,
    required List<TeachingAssignment> assignments,
    String? classMasterOfClass,
  }) async {
    final user = AppUser(
      id: id,
      name: name,
      email: email,
      role: UserRole.lecturer,
      roleName: 'Teacher',
      schoolId: schoolId,
      teachingAssignments: assignments,
      classMasterOfClass: classMasterOfClass,
    );

    // Save locally immediately
    final existing = await _getLocalStaff(schoolId);
    final map = {for (final u in existing) u.id: u};
    map[id] = user;
    await _setLocalStaff(schoolId, map.values.toList());

    final db = _db;
    if (db != null) {
      try {
        await db.from('users').upsert({
          'id': id,
          'name': name,
          'name_lower': name.toLowerCase(),
          'email': email,
          'role': 'lecturer',
          'institution_id': schoolId,
          'teaching_assignments': assignments.map((a) => a.toMap()).toList(),
          if (classMasterOfClass != null) 'class_master_of_class': classMasterOfClass,
        });
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<Result<void>> setTeachingAssignments(String userId, List<TeachingAssignment> assignments) async {
    final db = _db;
    if (db != null) {
      try {
        await db.from('users').update({
          'teaching_assignments': assignments.map((a) => a.toMap()).toList(),
        }).eq('id', userId);
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<Result<void>> setClassMasterOfClass(String userId, String? classLevel) async {
    final db = _db;
    if (db != null) {
      try {
        await db.from('users').update({'class_master_of_class': classLevel}).eq('id', userId);
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<List<AppUser>> _getLocalStaff(String schoolId) async {
    try {
      final key = 'staff_$schoolId';
      final existing = await OfflineCache.instance.get<List<AppUser>>(
        key,
        (json) => OfflineCache.listFromJson(json, (j) => AppUser.fromSupabase(j as Map<String, dynamic>)),
      );
      if (existing != null) return existing;
    } catch (_) {}
    return [];
  }

  Future<void> _setLocalStaff(String schoolId, List<AppUser> list) async {
    try {
      final key = 'staff_$schoolId';
      await OfflineCache.instance.put(
        key,
        OfflineCache.listToJson(list, (u) => (u as AppUser).toSupabase()),
      );
    } catch (_) {}
  }
}
