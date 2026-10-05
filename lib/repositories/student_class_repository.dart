// lib/repositories/student_class_repository.dart
// Backs the admin "Student Management" screen: setting which class a
// student belongs to. Nothing else in the app could ever set a
// student's class_level before this -- there's no such field in
// profile_edit_page.dart either, so it stayed empty unless someone
// hand-edited Postgres. That silently blocked marks entry (manual and
// CSV), the Timetable page, Homework, and the daily-program cron for
// every student, since all of them key off class_level. Same RLS
// reasoning as TeacherManagementRepository: users_update_admin already
// lets any has_min_role('department_admin') caller update any users
// row; this just scopes that broad policy to the admin's own school
// client-side.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';
import '../models/app_user.dart';
import 'messaging_repository.dart';

class StudentClassRepository {
  StudentClassRepository._();
  static final StudentClassRepository instance = StudentClassRepository._();

  final SupabaseClient _db = Supabase.instance.client;

  /// Students at [schoolId] whose name starts with [query].
  Future<List<AppUser>> searchStudents(String schoolId, String query) async {
    if (schoolId.isEmpty) return const [];
    final rows = await MessagingRepository.instance.searchUsers(query, limit: 30);
    return rows
        .where((r) => r['institution_id'] == schoolId && r['role'] == 'student')
        .map(AppUser.fromSupabase)
        .toList();
  }

  /// Every student at [schoolId] who already has a class set.
  Future<List<AppUser>> classifiedStudentsOnce(String schoolId) async {
    if (schoolId.isEmpty) return const [];
    final rows = await _db.from('users').select().eq('institution_id', schoolId).eq('role', 'student');
    return rows.map(AppUser.fromSupabase).where((u) => u.classLevel.isNotEmpty).toList();
  }

  /// Every student at [schoolId] with NO class set yet -- the admin's
  /// actual to-do list, since an unclassified student is invisible to
  /// marks/timetable/homework/the daily program until this is set.
  Future<List<AppUser>> unclassifiedStudentsOnce(String schoolId) async {
    if (schoolId.isEmpty) return const [];
    final rows = await _db.from('users').select().eq('institution_id', schoolId).eq('role', 'student');
    return rows.map(AppUser.fromSupabase).where((u) => u.classLevel.isEmpty).toList();
  }

  Future<Result<void>> setClassLevel(String studentId, String classLevel) async {
    try {
      await _db.from('users').update({'class_level': classLevel}).eq('id', studentId);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t update that student\'s class', e);
    }
  }
}
