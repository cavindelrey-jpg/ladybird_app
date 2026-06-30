// lib/models/assignment.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AssignmentStatus { draft, published, closed }
enum SubmissionStatus { notSubmitted, submitted, graded, late }

class Assignment {
  final String id;
  final String schoolId;
  final String courseId;
  final String courseName;
  final String title;
  final String description;
  final String lecturerId;
  final String lecturerName;
  final DateTime dueDate;
  final int maxScore;
  final AssignmentStatus status;
  final String? classGroup;

  const Assignment({
    required this.id, required this.schoolId,
    required this.courseId, required this.courseName,
    required this.title, required this.description,
    required this.lecturerId, required this.lecturerName,
    required this.dueDate, required this.maxScore,
    required this.status, this.classGroup,
  });

  bool get isOverdue => DateTime.now().isAfter(dueDate) && status != AssignmentStatus.closed;
  int  get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Assignment(
      id: doc.id, schoolId: d['schoolId'] ?? '',
      courseId: d['courseId'] ?? '', courseName: d['courseName'] ?? '',
      title: d['title'] ?? '', description: d['description'] ?? '',
      lecturerId: d['lecturerId'] ?? '', lecturerName: d['lecturerName'] ?? '',
      dueDate: (d['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maxScore: (d['maxScore'] as num?)?.toInt() ?? 100,
      status: AssignmentStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => AssignmentStatus.published),
      classGroup: d['classGroup'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolId': schoolId, 'courseId': courseId, 'courseName': courseName,
    'title': title, 'description': description,
    'lecturerId': lecturerId, 'lecturerName': lecturerName,
    'dueDate': Timestamp.fromDate(dueDate),
    'maxScore': maxScore, 'status': status.name,
    'classGroup': classGroup,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String? submissionText;
  final DateTime submittedAt;
  final SubmissionStatus status;
  final int? score;
  final String? feedback;

  const AssignmentSubmission({
    required this.id, required this.assignmentId,
    required this.studentId, required this.studentName,
    this.submissionText, required this.submittedAt,
    required this.status, this.score, this.feedback,
  });

  factory AssignmentSubmission.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AssignmentSubmission(
      id: doc.id, assignmentId: d['assignmentId'] ?? '',
      studentId: d['studentId'] ?? '', studentName: d['studentName'] ?? '',
      submissionText: d['submissionText'],
      submittedAt: (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: SubmissionStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => SubmissionStatus.submitted),
      score: (d['score'] as num?)?.toInt(),
      feedback: d['feedback'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'assignmentId': assignmentId, 'studentId': studentId, 'studentName': studentName,
    'submissionText': submissionText,
    'submittedAt': Timestamp.fromDate(submittedAt),
    'status': status.name, 'score': score, 'feedback': feedback,
  };
}
