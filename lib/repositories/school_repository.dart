import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/result.dart';
import '../models/school.dart';
import '../core/realtime_tolerant.dart';

class SchoolRepository {
  SchoolRepository._();
  static final SchoolRepository instance = SchoolRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Add memory cache
  final Map<String, School> _idCache = {};
  final Map<String, School> _codeCache = {};

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
      final school = School.fromSupabase(row);
      _idCache[school.id] = school;
      _codeCache[school.code.toUpperCase()] = school;
      return Success(school);
    } catch (e) {
      return Failure('Failed to register school', e);
    }
  }

  Future<School?> getByCodeOnce(String code, {bool forceRefresh = false}) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;
    
    if (!forceRefresh && _codeCache.containsKey(normalizedCode)) {
      return _codeCache[normalizedCode];
    }
    
    final row = await _supabase
        .from('institutions')
        .select()
        .eq('school_code', normalizedCode)
        .maybeSingle();
    if (row == null) return null;
    
    final school = School.fromSupabase(row);
    _codeCache[normalizedCode] = school;
    _idCache[school.id] = school;
    return school;
  }

  Future<School?> getByIdOnce(String schoolId, {bool forceRefresh = false}) async {
    if (schoolId.isEmpty) return null;
    
    if (!forceRefresh && _idCache.containsKey(schoolId)) {
      return _idCache[schoolId];
    }

    final row = await _supabase.from('institutions').select().eq('id', schoolId).maybeSingle();
    if (row == null) return null;
    
    final school = School.fromSupabase(row);
    _idCache[schoolId] = school;
    _codeCache[school.code.toUpperCase()] = school;
    return school;
  }

  Stream<List<School>> watchAll() => _supabase
      .from('institutions')
      .stream(primaryKey: ['id'])
      .order('school_name', ascending: true)
      .realtimeTolerant()
      .map((rows) {
        final schools = rows.map(School.fromSupabase).toList();
        for (final s in schools) {
          _idCache[s.id] = s;
          _codeCache[s.code.toUpperCase()] = s;
        }
        return schools;
      });

  Future<Result<List<String>>> getSubjects(String schoolId) async {
    try {
      final rows = await _supabase.from('school_subjects').select('name').eq('school_id', schoolId).order('name', ascending: true);
      final list = (rows as List).map((r) => r['name'] as String).toList();
      return Success(list);
    } catch (e) {
      return Failure('Failed to load subjects', e);
    }
  }

  Future<Result<void>> addSubject(String schoolId, String name) async {
    try {
      await _supabase.from('school_subjects').insert({
        'school_id': schoolId,
        'name': name,
      });
      return const Success(null);
    } catch (e) {
      return Failure('Failed to add subject', e);
    }
  }
}
