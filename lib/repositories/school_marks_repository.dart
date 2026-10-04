// lib/repositories/school_marks_repository.dart
// Student marks/report cards. Backed by public.school_marks (see
// supabase/migrations/20260901031000_school_marks.sql) -- one row per
// (student, subject, sequence, academic year); upsert() corrects an
// existing entry rather than duplicating it, keyed on that same tuple.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/marks_csv.dart' show RosterStudent;
import '../core/offline_cache.dart';
import '../core/result.dart';
import '../models/school_mark.dart';
import '../models/student_record.dart';
import '../core/realtime_tolerant.dart';
import 'student_roster_repository.dart';

/// Overall grade for a whole sequence -- same percentage scale as a
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
        .realtimeTolerant()
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
      toJson: (list) => OfflineCache.listToJson(list, (m) => _toRow(m)),
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
      await OfflineCache.instance.remove('all_marks_${mark.studentId}');
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

  /// Every student enrolled in [classLevel] at [schoolId], sorted by
  /// name -- the marks grid's row source. One query per class instead
  /// of a name search per student. RLS (users_select_self_or_institution)
  /// already lets same-school staff read these rows.
  Future<Result<List<RosterStudent>>> classRoster(String schoolId, String classLevel) async {
    if (schoolId.isEmpty || classLevel.isEmpty) return const Success([]);
    try {
      List<dynamic> rows;
      try {
        rows = await _db
            .from('users')
            .select('id, name, class_level')
            .eq('institution_id', schoolId)
            .eq('class_level', classLevel)
            .eq('role', 'student');
      } catch (_) {
        rows = await _db
            .from('users')
            .select('id, name, class_level')
            .eq('institution_id', schoolId)
            .eq('class_level', classLevel);
      }

      final students = <RosterStudent>[
        for (final r in rows)
          RosterStudent(
            id: r['id'] as String,
            name: (r['name'] as String?)?.trim().isNotEmpty == true ? r['name'] as String : 'Unnamed student',
            classLevel: r['class_level']?.toString() ?? classLevel,
          ),
      ];

      // Include any students registered in the school roster
      try {
        final rosterRes = await StudentRosterRepository.instance.getStudents(schoolId, classLevel: classLevel);
        if (rosterRes is Success<List<StudentRecord>>) {
          final existingIds = students.map((s) => s.id).toSet();
          final existingNames = students.map((s) => s.name.trim().toLowerCase()).toSet();
          for (final sr in rosterRes.value) {
            if (!existingIds.contains(sr.id) && !existingNames.contains(sr.name.trim().toLowerCase())) {
              students.add(RosterStudent(
                id: sr.id,
                name: sr.name,
                classLevel: sr.classLevel,
              ));
              existingIds.add(sr.id);
              existingNames.add(sr.name.trim().toLowerCase());
            }
          }
        }
      } catch (_) {}

      // If no students registered in users yet, check previously graded students in school_marks
      if (students.isEmpty) {
        try {
          final markRows = await _marks
              .select('student_id, teacher_name')
              .eq('school_id', schoolId)
              .eq('class_level', classLevel);
          final seen = <String>{};
          for (final m in markRows) {
            final sid = m['student_id'] as String;
            if (seen.add(sid)) {
              students.add(RosterStudent(
                id: sid,
                name: 'Student ${sid.length > 8 ? sid.substring(0, 8) : sid}',
                classLevel: classLevel,
              ));
            }
          }
        } catch (_) {}
      }

      students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Success(students);
    } catch (e) {
      return Failure('Couldn\'t load the $classLevel class list. Check your connection and try again.', e);
    }
  }

  /// Existing marks for one (class, subject, sequence, year), keyed by
  /// student id -- prefills the grid and feeds CSV export.
  Future<Result<Map<String, SchoolMark>>> marksForClass({
    required String schoolId,
    required String classLevel,
    required String subject,
    required AcademicSequence sequence,
    required String academicYear,
  }) async {
    try {
      final rows = await _marks
          .select()
          .eq('school_id', schoolId)
          .eq('class_level', classLevel)
          .eq('subject', subject)
          .eq('sequence', sequence.name)
          .eq('academic_year', academicYear);
      return Success({for (final r in rows) r['student_id'] as String: _fromRow(r)});
    } catch (e) {
      return Failure('Couldn\'t load existing marks. Check your connection and try again.', e);
    }
  }

  /// Saves many marks in as few round trips as possible. Each chunk is
  /// one bulk upsert; if a chunk is rejected (one bad row fails the
  /// whole statement) it's retried row by row so only the genuinely bad
  /// rows fail. Returns the student ids that did NOT save, with a reason.
  Future<Map<String, String>> upsertMany(List<SchoolMark> marks, {int chunkSize = 100}) async {
    final failures = <String, String>{};
    for (var i = 0; i < marks.length; i += chunkSize) {
      final chunk = marks.sublist(i, (i + chunkSize).clamp(0, marks.length));
      try {
        await _marks.upsert(chunk.map(_toRow).toList(), onConflict: 'student_id,subject,sequence,academic_year');
        for (final m in chunk) {
          OfflineCache.instance.remove('all_marks_${m.studentId}');
        }
      } on PostgrestException {
        // The server rejected something in the chunk -- retry row by row
        // so only the genuinely bad rows fail.
        for (final m in chunk) {
          try {
            await _marks.upsert(_toRow(m), onConflict: 'student_id,subject,sequence,academic_year');
            OfflineCache.instance.remove('all_marks_${m.studentId}');
          } on PostgrestException catch (e) {
            failures[m.studentId] = _friendly(e);
          } catch (e) {
            failures[m.studentId] = 'Not saved — no connection.';
          }
        }
      } catch (_) {
        // Connection failure: no point retrying 60 rows one by one.
        for (final m in chunk) {
          failures[m.studentId] = 'Not saved — no connection.';
        }
      }
    }
    return failures;
  }

  static String _friendly(PostgrestException e) {
    final msg = e.message;
    if (msg.contains('school_marks_score_range')) return 'Score is outside 0–max.';
    if (msg.contains('row-level security')) return 'You\'re not allowed to record this subject for this class.';
    if (msg.contains('isn\'t enrolled') || msg.contains('isn\'t in')) return msg;
    return 'Not saved: $msg';
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
