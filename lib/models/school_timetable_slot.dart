// lib/models/school_timetable_slot.dart
// The official, admin-authored School Timetable -- deliberately a
// separate model/collection from PersonalStudySlot (the self-authored
// Study Plan every user already has on Profile). Scoped by schoolId +
// classLevel rather than per-user: one slot document is read by every
// student in that class, not duplicated per student.
//
// Firestore: schools/{schoolId}/timetable/{id} -- this exact path/rule
// already existed in firestore.rules (isSignedIn()+isOwnSchool() read,
// canManageSchool() write) before this model did; nothing implemented it.

import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolTimetableSlot {
  final String id;
  final String schoolId;
  final String classLevel; // e.g. "Form 4" -- matches AppUser.classLevel
  final int dayOfWeek; // 1=Mon...7=Sun
  final String startTime; // "08:00"
  final String endTime;   // "09:00"
  final String subject;
  final String teacherName;
  final String? room;

  const SchoolTimetableSlot({
    required this.id,
    required this.schoolId,
    required this.classLevel,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacherName,
    this.room,
  });

  static const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get dayName => dayOfWeek >= 1 && dayOfWeek <= 7 ? dayNames[dayOfWeek] : '';

  factory SchoolTimetableSlot.fromFirestore(DocumentSnapshot doc, String schoolId) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SchoolTimetableSlot(
      id: doc.id,
      schoolId: schoolId,
      classLevel: d['classLevel'] ?? '',
      dayOfWeek: (d['dayOfWeek'] as num?)?.toInt() ?? 1,
      startTime: d['startTime'] ?? '08:00',
      endTime: d['endTime'] ?? '09:00',
      subject: d['subject'] ?? '',
      teacherName: d['teacherName'] ?? '',
      room: d['room'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'classLevel': classLevel,
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'subject': subject,
        'teacherName': teacherName,
        'room': room,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  SchoolTimetableSlot copyWith({
    String? classLevel, int? dayOfWeek, String? startTime, String? endTime,
    String? subject, String? teacherName, String? room,
  }) => SchoolTimetableSlot(
        id: id, schoolId: schoolId,
        classLevel: classLevel ?? this.classLevel,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        subject: subject ?? this.subject,
        teacherName: teacherName ?? this.teacherName,
        room: room ?? this.room,
      );
}
