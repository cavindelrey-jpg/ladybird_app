// lib/repositories/school_repository.dart
// CRUD for the school registry (see models/school.dart — backed by
// public.institutions, the same table academia-cameroon's Institution
// model uses). Creating a school is a platform-level action — RLS
// (institutions_write_super_admin) restricts inserts to super_admin,
// same tier "Register a School" was already documented at.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';
import '../models/school.dart';

class SchoolRepository {
  SchoolRepository._();
  static final SchoolRepository instance = SchoolRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Result<School>> registerSchool({
    required String name,
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (name.trim().isEmpty || normalizedCode.isEmpty) {
      return const Failure('School name and code are required', null);
    }
    try {
      final existing = await _supabase
          .from('institutions')
          .select('id')
          .eq('school_code', normalizedCode)
          .maybeSingle();
      if (existing != null) {
        return Failure('School code "$normalizedCode" is already in use', null);
      }
      final row = await _supabase
          .from('institutions')
          .insert({'school_code': normalizedCode, 'school_name': name.trim()})
          .select()
          .single();
      return Success(School.fromSupabase(row));
    } catch (e) {
      return Failure('Failed to register school', e);
    }
  }

  Future<School?> getByCodeOnce(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;
    final row = await _supabase
        .from('institutions')
        .select()
        .eq('school_code', normalizedCode)
        .maybeSingle();
    return row == null ? null : School.fromSupabase(row);
  }

  Future<School?> getByIdOnce(String schoolId) async {
    if (schoolId.isEmpty) return null;
    final row = await _supabase.from('institutions').select().eq('id', schoolId).maybeSingle();
    return row == null ? null : School.fromSupabase(row);
  }

  Stream<List<School>> watchAll() => _supabase
      .from('institutions')
      .stream(primaryKey: ['id'])
      .order('school_name')
      .map((rows) => rows.map(School.fromSupabase).toList());
}
