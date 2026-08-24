// lib/repositories/school_marks_repository.dart
// Real Firestore-backed marks -- the existing top-level marks/{id}
// collection, which already had a correct, field-based rule
// (resource.data.studentId == request.auth.uid || staff) sitting
// completely unused (see models/school_mark.dart's file header for why
// the OTHER existing marks/{schoolId}/... nested schema can't be used --
// its own rule comment admits studentId isn't expressible there). No
// firestore.rules changes needed for this collection.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/result.dart';
import '../models/school_mark.dart';

/// Overall grade for a whole sequence -- same percentage scale as a
/// single SchoolMark.grade, applied to the AVERAGE percentage across
/// every subject rather than one subject's own score. Pure, top-level,
/// and separate from SchoolMark.grade (which is per-subject) so each can
/// be unit-tested and read independently.
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

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('marks');

  Stream<List<SchoolMark>> watchForSequence(String studentId, AcademicSequence sequence) {
    if (studentId.isEmpty) return Stream.value(const []);
    return _col
        .where('studentId', isEqualTo: studentId)
        .where('sequence', isEqualTo: sequence.name)
        .snapshots()
        .map((snap) => snap.docs.map(SchoolMark.fromFirestore).toList()
          ..sort((a, b) => a.subject.compareTo(b.subject)));
  }

  Future<List<SchoolMark>> getForSequenceOnce(String studentId, AcademicSequence sequence) async {
    if (studentId.isEmpty) return const [];
    final snap = await _col
        .where('studentId', isEqualTo: studentId)
        .where('sequence', isEqualTo: sequence.name)
        .get();
    return snap.docs.map(SchoolMark.fromFirestore).toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));
  }

  /// The full 6-sequence history for one subject, in chronological order
  /// -- powers "compare with previous sequences" without a separate
  /// round trip per sequence.
  Future<Map<AcademicSequence, SchoolMark>> subjectHistory(String studentId, String subject) async {
    if (studentId.isEmpty) return {};
    final snap = await _col
        .where('studentId', isEqualTo: studentId)
        .where('subject', isEqualTo: subject)
        .get();
    final marks = snap.docs.map(SchoolMark.fromFirestore).toList();
    return {for (final m in marks) m.sequence: m};
  }

  Future<Result<void>> upsert(SchoolMark mark) async {
    try {
      if (mark.id.isEmpty) {
        await _col.add(mark.toFirestore());
      } else {
        await _col.doc(mark.id).set(mark.toFirestore(), SetOptions(merge: true));
      }
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save mark', e);
    }
  }

  Future<Result<void>> delete(String markId) async {
    try {
      await _col.doc(markId).delete();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete mark', e);
    }
  }

  /// Every distinct student the caller (a teacher/admin) has entered
  /// marks for in [schoolId] -- powers the staff entry page's student
  /// picker without needing a separate roster collection.
  Future<List<String>> distinctStudentIds(String schoolId, String classLevel) async {
    final snap = await _col
        .where('schoolId', isEqualTo: schoolId)
        .where('classLevel', isEqualTo: classLevel)
        .get();
    return snap.docs.map((d) => d.data()['studentId'] as String? ?? '').where((s) => s.isNotEmpty).toSet().toList();
  }
}
