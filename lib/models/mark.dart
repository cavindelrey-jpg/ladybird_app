// lib/models/mark.dart

class SubjectMark {
  final String subjectName;
  final double score;
  final double maxScore;
  final int coefficient;
  final String teacherComment;

  const SubjectMark({
    required this.subjectName,
    required this.score,
    required this.maxScore,
    required this.coefficient,
    this.teacherComment = '',
  });

  /// Normalised mark out of 20
  double get outOf20 => maxScore > 0 ? (score / maxScore) * 20 : 0.0;

  String get grade {
    final n = outOf20;
    if (n >= 16) return 'A';
    if (n >= 13) return 'B';
    if (n >= 10) return 'C';
    if (n >= 7)  return 'D';
    return 'F';
  }

  factory SubjectMark.fromFirestore(String name, Map<String, dynamic> d) =>
      SubjectMark(
        subjectName: name,
        score: (d['score'] as num?)?.toDouble() ?? 0.0,
        maxScore: (d['maxScore'] as num?)?.toDouble() ?? 20.0,
        coefficient: (d['coefficient'] as num?)?.toInt() ?? 1,
        teacherComment: d['teacherComment'] as String? ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'score': score,
    'maxScore': maxScore,
    'coefficient': coefficient,
    'teacherComment': teacherComment,
  };

  SubjectMark copyWith({
    double? score,
    double? maxScore,
    int? coefficient,
    String? teacherComment,
  }) => SubjectMark(
    subjectName: subjectName,
    score: score ?? this.score,
    maxScore: maxScore ?? this.maxScore,
    coefficient: coefficient ?? this.coefficient,
    teacherComment: teacherComment ?? this.teacherComment,
  );
}

class SequenceReport {
  final String sequenceId;
  final String studentId;
  final String schoolId;
  final List<SubjectMark> subjects;

  const SequenceReport({
    required this.sequenceId,
    required this.studentId,
    required this.schoolId,
    required this.subjects,
  });

  double get average {
    if (subjects.isEmpty) return 0;
    final totalCoef = subjects.fold<int>(0, (s, m) => s + m.coefficient);
    if (totalCoef == 0) return 0;
    final weighted = subjects.fold<double>(
        0, (s, m) => s + m.outOf20 * m.coefficient);
    return weighted / totalCoef;
  }
}
