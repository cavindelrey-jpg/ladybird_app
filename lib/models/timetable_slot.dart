// lib/models/timetable_slot.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TimetableSlot {
  final String id;
  final String schoolId;
  final String courseId;
  final String courseName;
  final String lecturerId;
  final String lecturerName;
  final String venue;
  final int dayOfWeek;    // 1=Mon … 5=Fri
  final String startTime; // "08:00"
  final String endTime;
  final String classGroup;

  const TimetableSlot({
    required this.id, required this.schoolId,
    required this.courseId, required this.courseName,
    required this.lecturerId, required this.lecturerName,
    required this.venue, required this.dayOfWeek,
    required this.startTime, required this.endTime,
    required this.classGroup,
  });

  static const dayNames = ['', 'Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  String get dayName => dayOfWeek >= 1 && dayOfWeek <= 7 ? dayNames[dayOfWeek] : '';

  factory TimetableSlot.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return TimetableSlot(
      id: doc.id, schoolId: d['schoolId'] ?? '',
      courseId: d['courseId'] ?? '', courseName: d['courseName'] ?? '',
      lecturerId: d['lecturerId'] ?? '', lecturerName: d['lecturerName'] ?? '',
      venue: d['venue'] ?? '',
      dayOfWeek: (d['dayOfWeek'] as num?)?.toInt() ?? 1,
      startTime: d['startTime'] ?? '08:00', endTime: d['endTime'] ?? '09:00',
      classGroup: d['classGroup'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolId': schoolId, 'courseId': courseId, 'courseName': courseName,
    'lecturerId': lecturerId, 'lecturerName': lecturerName,
    'venue': venue, 'dayOfWeek': dayOfWeek,
    'startTime': startTime, 'endTime': endTime,
    'classGroup': classGroup,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
