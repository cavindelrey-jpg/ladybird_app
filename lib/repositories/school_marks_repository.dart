// lib/repositories/school_marks_repository.dart
// Student marks/report cards. No Postgres table yet — zero real data at
// migration time; an honest stub (empty streams/lists, real Failure on
// write) rather than a fabricated schema.

import '../core/result.dart';
import '../models/school_mark.dart';

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

  static const String _notAvailable = 'School marks aren\'t available yet.';

  Stream<List<SchoolMark>> watchForSequence(String studentId, AcademicSequence sequence) =>
      Stream.value(const []);

  Future<List<SchoolMark>> getForSequenceOnce(String studentId, AcademicSequence sequence) async => const [];

  /// The full 6-sequence history for one subject, in chronological order.
  Future<Map<AcademicSequence, SchoolMark>> subjectHistory(String studentId, String subject) async => {};

  Future<Result<void>> upsert(SchoolMark mark) async => const Failure(_notAvailable, null);

  Future<Result<void>> delete(String markId) async => const Failure(_notAvailable, null);

  /// Every distinct student the caller (a teacher/admin) has entered
  /// marks for in [schoolId] -- powers the staff entry page's student
  /// picker.
  Future<List<String>> distinctStudentIds(String schoolId, String classLevel) async => const [];
}
