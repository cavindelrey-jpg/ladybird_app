// lib/models/school_mark.dart
// A single subject mark for one student in one term/sequence. No
// Postgres table yet — zero real data at migration time;
// SchoolMarksRepository below is an honest stub.

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
  final String studentName;
  final String classLevel;
  final String subject;
  final String teacherName;
  final AcademicSequence sequence;

  /// e.g. "2026" -- distinguishes marks from different academic years for
  /// the same student/subject/sequence.
  final String academicYear;

  final double score;
  final double maxScore; // as originally entered -- usually 20 or 100
  final DateTime? gradedAt;
  final String? gradedBy;

  const SchoolMark({
    required this.id,
    required this.schoolId,
    required this.studentId,
    this.studentName = '',
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
  double get scoreOn20 => scoreOutOf(20);

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

  String get gradeLetter => grade;
}

/// How a mark is shown everywhere: exact, never rounded (a parent once saw
/// 6.5/20 as "7/20"), without a trailing ".0" -- 14, 13.5, 12.25.
String formatMark(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}
