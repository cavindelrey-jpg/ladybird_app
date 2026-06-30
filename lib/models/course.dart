// lib/models/course.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Course {
  final String id;
  final String schoolId;
  final String? departmentId;
  final String code;
  final String name;
  final String? description;
  final String lecturerId;
  final String lecturerName;
  final int credits;
  final String? classGroup;
  final int currentYear;
  final String? semester;

  const Course({
    required this.id, required this.schoolId, this.departmentId,
    required this.code, required this.name, this.description,
    required this.lecturerId, required this.lecturerName,
    this.credits = 3, this.classGroup,
    required this.currentYear, this.semester,
  });

  factory Course.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Course(
      id: doc.id, schoolId: d['schoolId'] ?? '',
      departmentId: d['departmentId'],
      code: d['code'] ?? '', name: d['name'] ?? '',
      description: d['description'],
      lecturerId: d['lecturerId'] ?? '', lecturerName: d['lecturerName'] ?? '',
      credits: (d['credits'] as num?)?.toInt() ?? 3,
      classGroup: d['classGroup'],
      currentYear: (d['currentYear'] as num?)?.toInt() ?? DateTime.now().year,
      semester: d['semester'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolId': schoolId, 'departmentId': departmentId,
    'code': code, 'name': name, 'description': description,
    'lecturerId': lecturerId, 'lecturerName': lecturerName,
    'credits': credits, 'classGroup': classGroup,
    'currentYear': currentYear, 'semester': semester,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
