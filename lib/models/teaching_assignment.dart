// lib/models/teaching_assignment.dart
// Architecture brief item 22: "A Physics teacher teaches Physics in Form 5
// only... cannot record Form 4 Physics." AppUser.subject/classLevel were a
// single string each — enough for a STUDENT's own class, not enough to
// express which (subject, class) pairs a TEACHER is actually assigned to.
// This is the real permission source for marks-entry gating; see
// SchoolMarksRepository / marks_permission.dart.

class TeachingAssignment {
  final String subject;
  final String classLevel;

  const TeachingAssignment({required this.subject, required this.classLevel});

  factory TeachingAssignment.fromMap(Map<String, dynamic> m) => TeachingAssignment(
        subject: m['subject']?.toString() ?? '',
        classLevel: m['classLevel']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {'subject': subject, 'classLevel': classLevel};

  @override
  bool operator ==(Object other) =>
      other is TeachingAssignment && other.subject == subject && other.classLevel == classLevel;

  @override
  int get hashCode => Object.hash(subject, classLevel);
}
