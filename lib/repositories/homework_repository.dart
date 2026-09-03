// lib/repositories/homework_repository.dart
// Teacher-created homework. Backed by public.homework (see
// supabase/migrations/20260903160000_homework_and_calendar_events.sql) --
// write access there is the first DB-enforced per-(subject, classLevel)
// teacher permission in this project, mirroring
// AppUser.canManageHomeworkFor client-side.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';
import '../models/homework.dart';

class HomeworkRepository {
  HomeworkRepository._();
  static final HomeworkRepository instance = HomeworkRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _homework => _db.from('homework');

  /// Every homework entry for [classLevel] in [schoolId], newest due first
  /// -- powers a student's "My Homework" list.
  Stream<List<Homework>> watchForClass(String schoolId, String classLevel) {
    if (schoolId.isEmpty || classLevel.isEmpty) return Stream.value(const []);
    return _homework.stream(primaryKey: ['id']).eq('school_id', schoolId).map((rows) {
      final list = rows.where((r) => r['class_level'] == classLevel).map(_fromRow).toList()
        ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
      return list;
    });
  }

  /// Everything one teacher has assigned, across every class/subject they
  /// teach -- powers the "Recently Assigned" list in Homework Management.
  Stream<List<Homework>> watchByTeacher(String teacherId) {
    if (teacherId.isEmpty) return Stream.value(const []);
    return _homework.stream(primaryKey: ['id']).eq('teacher_id', teacherId).map((rows) {
      final list = rows.map(_fromRow).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<Result<void>> create(Homework homework) async {
    try {
      await _homework.insert(_toRow(homework));
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t save that homework', e);
    }
  }

  Future<Result<void>> update(Homework homework) async {
    try {
      await _homework.update(_toRow(homework)).eq('id', homework.id);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t update that homework', e);
    }
  }

  Future<Result<void>> delete(String id) async {
    try {
      await _homework.delete().eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t delete that homework', e);
    }
  }

  Map<String, dynamic> _toRow(Homework h) => {
        'school_id': h.schoolId,
        'class_level': h.classLevel,
        'subject': h.subject,
        'teacher_id': h.teacherId,
        'title': h.title,
        'description': h.description,
        'homework_type': h.homeworkType,
        'due_at': h.dueAt.toIso8601String(),
        'attachment_url': h.attachmentUrl,
        'attachment_name': h.attachmentName,
        'required_materials': h.requiredMaterials,
        'notify': h.notify,
      };

  Homework _fromRow(Map<String, dynamic> row) => Homework.fromSupabase(row);
}
