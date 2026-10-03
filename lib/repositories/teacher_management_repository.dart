// lib/repositories/teacher_management_repository.dart
// Backs the admin Teacher Management screen: finding staff and setting
// their (subject, classLevel) teaching assignments + class-master status.
//
// Writing teachingAssignments/classMasterOfClass needs no new RPC or RLS
// policy -- "users_update_admin" (academia-cameroon's
// 20260828060100_rls_policies.sql) already lets any has_min_role
// ('department_admin') caller update any users row. This repository just
// scopes that broad policy to "the admin's own school" client-side, the
// same looseness SchoolAdminPage already lives with for voucher issuance.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/core.dart';
import '../models/app_user.dart';
import '../models/teaching_assignment.dart';

class TeacherManagementRepository {
  TeacherManagementRepository._();
  static final TeacherManagementRepository instance = TeacherManagementRepository._();

  final SupabaseClient _db = Supabase.instance.client;

  /// Staff at [schoolId] whose name contains [query]. Queried within the
  /// school -- it used to run the platform-wide 30-result name search and
  /// filter afterwards, so a teacher could be pushed out of the results
  /// by users of other schools sharing the name prefix.
  Future<List<AppUser>> searchStaff(String schoolId, String query) async {
    if (schoolId.isEmpty || query.trim().isEmpty) return const [];
    final rows = await _db
        .from('users')
        .select()
        .eq('institution_id', schoolId)
        .ilike('name_lower', '%${query.trim().toLowerCase()}%')
        .not('role', 'in', '(student,guest)')
        .order('name_lower', ascending: true)
        .limit(50);
    return rows.map(AppUser.fromSupabase).toList();
  }

  /// Every staff member (lecturer or above) at [schoolId], fresh each call.
  Future<List<AppUser>> staffOnce(String schoolId) async {
    if (schoolId.isEmpty) return const [];
    final rows = await _db
        .from('users')
        .select()
        .eq('institution_id', schoolId)
        .not('role', 'in', '(student,guest)')
        .order('name_lower', ascending: true);
    return rows.map(AppUser.fromSupabase).toList();
  }

  /// Every staff member at [schoolId] who already has at least one teaching
  /// assignment or is a class master -- powers the management list without
  /// requiring the admin to search by name first. NOT memoized: it was,
  /// so the list never reflected an edit made a moment ago on this page.
  Future<List<AppUser>> assignedStaffOnce(String schoolId) async {
    final staff = await staffOnce(schoolId);
    return staff.where((u) => u.teachingAssignments.isNotEmpty || u.classMasterOfClass != null).toList();
  }

  Future<Result<void>> setTeachingAssignments(String userId, List<TeachingAssignment> assignments) async {
    try {
      await _db.from('users').update({
        'teaching_assignments': assignments.map((a) => a.toMap()).toList(),
      }).eq('id', userId);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t update that teacher\'s assignments', e);
    }
  }

  Future<Result<void>> setClassMasterOfClass(String userId, String? classLevel) async {
    try {
      await _db.from('users').update({'class_master_of_class': classLevel}).eq('id', userId);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t update that teacher\'s class-master status', e);
    }
  }
}
