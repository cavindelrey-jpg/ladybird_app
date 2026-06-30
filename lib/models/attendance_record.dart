// lib/models/attendance_record.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late, excused }

class AttendanceRecord {
  final String id;
  final String schoolId;
  final String courseId;
  final String studentId;
  final String studentName;
  final DateTime date;
  final AttendanceStatus status;
  final String markedById;

  const AttendanceRecord({
    required this.id, required this.schoolId, required this.courseId,
    required this.studentId, required this.studentName,
    required this.date, required this.status, required this.markedById,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceRecord(
      id: doc.id, schoolId: d['schoolId'] ?? '',
      courseId: d['courseId'] ?? '', studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendanceStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => AttendanceStatus.absent),
      markedById: d['markedById'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolId': schoolId, 'courseId': courseId,
    'studentId': studentId, 'studentName': studentName,
    'date': Timestamp.fromDate(date), 'status': status.name,
    'markedById': markedById,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class AttendanceSummary {
  final int total, present, absent, late, excused;
  const AttendanceSummary({
    required this.total, required this.present,
    required this.absent, required this.late, required this.excused,
  });
  double get rate => total == 0 ? 0 : (present + late) / total;
  String get rateLabel => '${(rate * 100).toStringAsFixed(1)}%';
}
