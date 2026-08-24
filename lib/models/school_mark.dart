// lib/models/school_mark.dart
// A single subject mark for one student in one term/sequence.
//
// Deliberately NOT the existing marks/{schoolId}/{studentId}/sequences/
// {sequenceId}/{markId} schema -- that one encodes studentId and
// sequenceId as Firestore COLLECTION ids, which firestore.rules' own
// comment on that block admits makes "a student may read their own
// marks" inexpressible (a security rule can't bind a wildcard to a
// collection id the way it can a document field). This model stores
// studentId as a plain FIELD on the existing flat marks/{id} collection
// instead -- firestore.rules already has a correct, field-based rule
// for exactly that path (`resource.data.studentId == request.auth.uid
// || staff`), just sitting unused. Same shape attendance/{id} already
// uses correctly. No firestore.rules changes needed.

import 'package:cloud_firestore/cloud_firestore.dart';

/// The six-sequence academic year (Cameroon GCE structure: 3 terms of 2
/// sequences each). A fixed, ordered list rather than free text so
/// "compare with the previous sequence" has an unambiguous chronological
/// order to walk.
enum AcademicSequence {
  t1s1, t1s2, t2s1, t2s2, t3s1, t3s2;

  String get term {
    switch (this) {
      case AcademicSequence.t1s1:
      case AcademicSequence.t1s2:
        return 'Term 1';
      case AcademicSequence.t2s1:
      case AcademicSequence.t2s2:
        return 'Term 2';
      case AcademicSequence.t3s1:
      case AcademicSequence.t3s2:
        return 'Term 3';
    }
  }

  String get sequenceLabel {
    switch (this) {
      case AcademicSequence.t1s1:
      case AcademicSequence.t2s1:
      case AcademicSequence.t3s1:
        return 'Sequence 1';
      case AcademicSequence.t1s2:
      case AcademicSequence.t2s2:
      case AcademicSequence.t3s2:
        return 'Sequence 2';
    }
  }

  String get label => '$term · $sequenceLabel';

  /// The sequence immediately before this one, or null for the very
  /// first sequence of the year (nothing to compare Term 1 · Sequence 1
  /// against).
  AcademicSequence? get previous {
    final i = AcademicSequence.values.indexOf(this);
    return i == 0 ? null : AcademicSequence.values[i - 1];
  }

  static AcademicSequence? fromKey(String key) {
    for (final s in AcademicSequence.values) {
      if (s.name == key) return s;
    }
    return null;
  }
}

class SchoolMark {
  final String id;
  final String schoolId;
  final String studentId;
  final String classLevel;
  final String subject;
  final String teacherName;
  final AcademicSequence sequence;

  /// e.g. "2026" -- was entirely absent before the CSV import feature
  /// (architecture brief item 21) needed it: without a year, marks from
  /// different academic years for the same student/subject/sequence are
  /// indistinguishable. Defaults to the current calendar year for any
  /// mark written without one, including every pre-existing document
  /// read back before this field existed.
  final String academicYear;

  final double score;
  final double maxScore; // as originally entered -- usually 20 or 100
  final DateTime? gradedAt;
  final String? gradedBy;

  const SchoolMark({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.classLevel,
    required this.subject,
    this.teacherName = '',
    required this.sequence,
    required this.academicYear,
    required this.score,
    required this.maxScore,
    this.gradedAt,
    this.gradedBy,
  });

  /// This mark rescaled onto a different denominator -- e.g. a mark
  /// entered as 14/20 rescaled onto [outOf]=100 becomes 70. Clamped so a
  /// malformed maxScore (<=0) never divides by zero or produces NaN.
  double scoreOutOf(double outOf) {
    if (maxScore <= 0) return 0;
    return (score / maxScore) * outOf;
  }

  double get percentage => scoreOutOf(100);

  /// Cameroon GCE-style letter grade off the percentage. A pure function
  /// of percentage alone, independent of subject, so it's the same scale
  /// everywhere marks are shown.
  String get grade {
    final p = percentage;
    if (p >= 80) return 'A';
    if (p >= 70) return 'B';
    if (p >= 60) return 'C';
    if (p >= 50) return 'D';
    if (p >= 40) return 'E';
    return 'F';
  }

  factory SchoolMark.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SchoolMark(
      id: doc.id,
      schoolId: d['schoolId'] ?? '',
      studentId: d['studentId'] ?? '',
      classLevel: d['classLevel'] ?? '',
      subject: d['subject'] ?? '',
      teacherName: d['teacherName'] ?? '',
      sequence: AcademicSequence.fromKey(d['sequence'] ?? '') ?? AcademicSequence.t1s1,
      academicYear: (d['academicYear'] as String?)?.isNotEmpty == true
          ? d['academicYear'] as String
          : DateTime.now().year.toString(),
      score: (d['score'] as num?)?.toDouble() ?? 0,
      maxScore: (d['maxScore'] as num?)?.toDouble() ?? 20,
      gradedAt: (d['gradedAt'] as Timestamp?)?.toDate(),
      gradedBy: d['gradedBy'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'schoolId': schoolId,
        'studentId': studentId,
        'classLevel': classLevel,
        'subject': subject,
        'teacherName': teacherName,
        'sequence': sequence.name,
        'academicYear': academicYear,
        'score': score,
        'maxScore': maxScore,
        'gradedAt': FieldValue.serverTimestamp(),
        'gradedBy': gradedBy,
      };
}
