// lib/repositories/marks_repository.dart
// Handles all marks read/write operations.
// Added: searchStudentsByName for teacher mark-entry flow.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../core/result.dart';

class MarksRepository {
  MarksRepository._();
  static final MarksRepository instance = MarksRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Student search (for teacher mark entry) ──────────────────────────────

  /// Search users by name prefix within a school. Returns students only.
  Future<List<AppUser>> searchStudents({
    required String schoolId,
    required String query,
  }) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final snap = await _db
        .collection(AppConstants.colUsers)
        .where('schoolId', isEqualTo: schoolId)
        .where('role', isEqualTo: 'student')
        .limit(30)
        .get();
    return snap.docs
        .map((d) => AppUser.fromFirestore(d.id, d.data()))
        .where((u) => u.name.toLowerCase().contains(q))
        .toList();
  }

  // ─── Sequence report ──────────────────────────────────────────────────────

  Future<SequenceReport?> getSequenceReport({
    required String schoolId,
    required String studentId,
    required String sequenceId,
  }) async {
    final seqRef = _db
        .collection(AppConstants.colMarks)
        .doc(schoolId)
        .collection(studentId)
        .doc(AppConstants.colSequences)
        .collection(sequenceId);

    final snap = await seqRef.get();
    if (snap.docs.isEmpty) return null;

    final subjects = snap.docs.map((doc) {
      return SubjectMark.fromFirestore(doc.id, doc.data());
    }).toList();

    return SequenceReport(
      sequenceId: sequenceId,
      studentId: studentId,
      schoolId: schoolId,
      subjects: subjects,
    );
  }

  /// Live stream of a student's sequence report.
  Stream<SequenceReport?> watchSequenceReport({
    required String schoolId,
    required String studentId,
    required String sequenceId,
  }) {
    return _db
        .collection(AppConstants.colMarks)
        .doc(schoolId)
        .collection(studentId)
        .doc(AppConstants.colSequences)
        .collection(sequenceId)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final subjects =
          snap.docs.map((d) => SubjectMark.fromFirestore(d.id, d.data())).toList();
      return SequenceReport(
        sequenceId: sequenceId,
        studentId: studentId,
        schoolId: schoolId,
        subjects: subjects,
      );
    });
  }

  Future<Result<void>> saveSubjectMark({
    required String schoolId,
    required String studentId,
    required String sequenceId,
    required SubjectMark mark,
  }) async {
    try {
      final batch = _db.batch();

      final markRef = _db
          .collection(AppConstants.colMarks)
          .doc(schoolId)
          .collection(studentId)
          .doc(AppConstants.colSequences)
          .collection(sequenceId)
          .doc(mark.subjectName);

      batch.set(markRef, mark.toFirestore(), SetOptions(merge: true));

      final indexRef = _db
          .collection(AppConstants.colMarks)
          .doc(schoolId)
          .collection(studentId)
          .doc(AppConstants.colSequences);

      batch.set(indexRef, {
        'availableSequences': FieldValue.arrayUnion([sequenceId]),
      }, SetOptions(merge: true));

      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save mark', e);
    }
  }

  Future<List<String>> getAvailableSequences({
    required String schoolId,
    required String studentId,
  }) async {
    final docSnap = await _db
        .collection(AppConstants.colMarks)
        .doc(schoolId)
        .collection(studentId)
        .doc(AppConstants.colSequences)
        .get();

    if (!docSnap.exists) return [];
    final data = docSnap.data();
    if (data == null || !data.containsKey('availableSequences')) return [];
    final List<dynamic> list = data['availableSequences'] as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }

  /// List of standard GCE sequences.
  static const List<String> standardSequences = [
    'Sequence 1',
    'Sequence 2',
    'Sequence 3',
    'Sequence 4',
    'Sequence 5',
    'Sequence 6',
  ];

  /// Common GCE subjects. Teacher can also type a custom one.
  static const List<String> commonSubjects = [
    'Mathematics',
    'English Language',
    'French',
    'Physics',
    'Chemistry',
    'Biology',
    'Geography',
    'History',
    'Economics',
    'Commerce',
    'Computer Science',
    'Literature',
    'Further Mathematics',
    'Technical Drawing',
    'Food & Nutrition',
  ];
}
