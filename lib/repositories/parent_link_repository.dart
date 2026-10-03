// lib/repositories/parent_link_repository.dart
// Spec item 5's parent<->student link. Backed by
// public.academia_parent_student_links, populated automatically by a trigger on
// school_vouchers redemption (see supabase/migrations/
// 20260904000006_parent_student_linking.sql) rather than any manual
// admin step -- a parent-role voucher already carries
// linkedStudentVoucherId (lib/models/school_voucher.dart), this just
// turns that into a lasting relationship once both sides are redeemed.
//
// get_linked_students() is a narrow SECURITY DEFINER RPC, not a raw
// `.from('users')` read: public.users' own RLS policy isn't defined in
// this repo (shared Supabase project with the sibling greenhills_app
// repo this app forked from) so it can't be safely broadened blind, and
// returning only the handful of fields the parent dashboard actually
// needs (not email/vouchers/XP/etc.) is the more conservative choice
// regardless.

import 'package:supabase_flutter/supabase_flutter.dart';


class LinkedStudent {
  final String studentId;
  final String studentName;
  final String classLevel;
  final String? institutionId;
  final String? photoUrl;

  const LinkedStudent({
    required this.studentId,
    required this.studentName,
    required this.classLevel,
    this.institutionId,
    this.photoUrl,
  });

  factory LinkedStudent.fromSupabase(Map<String, dynamic> d) => LinkedStudent(
        studentId: d['student_id']?.toString() ?? '',
        studentName: d['student_name']?.toString() ?? 'Student',
        classLevel: d['class_level']?.toString() ?? '',
        institutionId: d['institution_id']?.toString(),
        photoUrl: d['photo_url']?.toString(),
      );
}

class ParentLinkRepository {
  ParentLinkRepository._();
  static final ParentLinkRepository instance = ParentLinkRepository._();

  final SupabaseClient _db = Supabase.instance.client;

  Future<List<LinkedStudent>> getLinkedStudents(String parentId) async {
    if (parentId.isEmpty) return const [];
    final rows = await _db.rpc('get_linked_students', params: {'p_parent_id': parentId}) as List;
    return rows.map((r) => LinkedStudent.fromSupabase(Map<String, dynamic>.from(r as Map))).toList();
  }
}
