// lib/repositories/school_marks_repository.dart
// Student marks/report cards. Backed by public.school_marks (see
// supabase/migrations/20260901031000_school_marks.sql) -- one row per
// (student, subject, sequence, academic year); upsert() corrects an
// existing entry rather than duplicating it, keyed on that same tuple.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local_database.dart';
import '../services/connectivity_service.dart';

import '../core/result.dart';
import '../models/school_mark.dart';

/// Overall grade for a whole sequence -- same percentage scale as a
import "../core/offline_cache.dart";
/// single SchoolMark.grade, applied to the AVERAGE percentage across
/// every subject rather than one subject's own score.
String overallGradeFor(double averagePercentage) {
  if (averagePercentage >= 80) return 'A';
  if (averagePercentage >= 70) return 'B';
  if (averagePercentage >= 60) return 'C';
  if (averagePercentage >= 50) return 'D';
  if (averagePercentage >= 40) return 'E';
  return 'F';
}

/// Short human status label for the "overall academic status" line --
/// same tier boundaries as [overallGradeFor], read as English rather
/// than a bare letter.
String academicStatusFor(double averagePercentage) {
  if (averagePercentage >= 80) return 'Excellent';
  if (averagePercentage >= 70) return 'Very Good';
  if (averagePercentage >= 60) return 'Good';
  if (averagePercentage >= 50) return 'Satisfactory';
  if (averagePercentage >= 40) return 'Needs Improvement';
  return 'At Risk';
}

/// Mean percentage across a list of marks -- 0 for an empty list (no
/// marks yet), never a divide-by-zero throw.
double averagePercentage(List<SchoolMark> marks) {
  if (marks.isEmpty) return 0;
  final sum = marks.fold<double>(0, (s, m) => s + m.percentage);
  return sum / marks.length;
}

class SchoolMarksRepository {
  SchoolMarksRepository._();
  static final SchoolMarksRepository instance = SchoolMarksRepository._();

  final SupabaseClient _db = Supabase.instance.client;
  SupabaseQueryBuilder get _marks => _db.from('school_marks');

  Stream<List<SchoolMark>> watchForSequence(String studentId, AcademicSequence sequence) {
    if (studentId.isEmpty) return Stream.value(const []);
    return _marks
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .map((rows) => rows.where((r) => r['sequence'] == sequence.name).map(_fromRow).toList());
  }

  Future<List<SchoolMark>> getForSequenceOnce(String studentId, AcademicSequence sequence) async {
    if (studentId.isEmpty) return const [];
    final rows = await _marks.select().eq('student_id', studentId).eq('sequence', sequence.name);
    return rows.map(_fromRow).toList();
  }

  /// Every mark this student has ever been given, any sequence -- powers
  /// the Home dashboard's "My Marks" preview, which shows whichever
  /// sequence actually has data rather than defaulting to Term 1 ·
  /// Sequence 1 like the full Marks page does.
  Future<List<SchoolMark>> allMarksOnce(String studentId) async {
    if (studentId.isEmpty) return const [];
    return OfflineCache.instance.fetch<List<SchoolMark>>(
      'all_marks_$studentId',
      () async {
        final rows = await _marks.select().eq('student_id', studentId);
        return rows.map(_fromRow).toList();
      },
      toJson: (list) => OfflineCache.listToJson(list, (m) => _toRow(m as SchoolMark)),
      fromJson: (json) => OfflineCache.listFromJson(json, (j) => _fromRow(j)),
    );
  }

  /// The full 6-sequence history for one subject, in chronological order.
  Future<Map<AcademicSequence, SchoolMark>> subjectHistory(String studentId, String subject) async {
    if (studentId.isEmpty) return {};
    final rows = await _marks.select().eq('student_id', studentId).eq('subject', subject);
    final out = <AcademicSequence, SchoolMark>{};
    for (final row in rows) {
      final seq = AcademicSequence.fromKey(row['sequence']?.toString() ?? '');
      if (seq != null) out[seq] = _fromRow(row);
    }
    return out;
  }

  Future<Result<void>> upsert(SchoolMark mark) async {
    try {
      await _marks.upsert(_toRow(mark), onConflict: 'student_id,subject,sequence,academic_year');
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t save that mark', e);
    }
  }

  Future<Result<void>> delete(String markId) async {
    try {
      await _marks.delete().eq('id', markId);
      return const Success(null);
    } catch (e) {
      return Failure('Couldn\'t delete that mark', e);
    }
  }

  /// Every distinct student the caller (a teacher/admin) has entered
  /// marks for in [schoolId] -- powers the staff entry page's student
  /// picker.
  Future<List<String>> distinctStudentIds(String schoolId, String classLevel) async {
    if (schoolId.isEmpty) return const [];
    final rows = await _marks.select('student_id').eq('school_id', schoolId).eq('class_level', classLevel);
    return rows.map((r) => r['student_id'] as String).toSet().toList();
  }

  Map<String, dynamic> _toRow(SchoolMark m) => {
        'school_id': m.schoolId,
        'student_id': m.studentId,
        'class_level': m.classLevel,
        'subject': m.subject,
        'teacher_name': m.teacherName,
        'sequence': m.sequence.name,
        'academic_year': m.academicYear,
        'score': m.score,
        'max_score': m.maxScore,
        'graded_at': (m.gradedAt ?? DateTime.now()).toIso8601String(),
        'graded_by': m.gradedBy,
      };

  SchoolMark _fromRow(Map<String, dynamic> row) => SchoolMark(
        id: row['id']?.toString() ?? '',
        schoolId: row['school_id']?.toString() ?? '',
        studentId: row['student_id']?.toString() ?? '',
        classLevel: row['class_level']?.toString() ?? '',
        subject: row['subject']?.toString() ?? '',
        teacherName: row['teacher_name']?.toString() ?? '',
        sequence: AcademicSequence.fromKey(row['sequence']?.toString() ?? '') ?? AcademicSequence.t1s1,
        academicYear: row['academic_year']?.toString() ?? '',
        score: (row['score'] as num?)?.toDouble() ?? 0,
        maxScore: (row['max_score'] as num?)?.toDouble() ?? 20,
        gradedAt: DateTime.tryParse(row['graded_at']?.toString() ?? ''),
        gradedBy: row['graded_by']?.toString(),
      );
}
