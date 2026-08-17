// lib/models/personal_study_slot.dart
// production_plan.md §5's "Personal Study Timetable" — deliberately a
// separate model/collection from TimetableSlot (the School Timetable,
// admin-authored, institution-scoped). This one is self-authored by the
// student, stored per-user: users/{uid}/study_timetable/{id}.

import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalStudySlot {
  final String id;
  final String userId;
  final int dayOfWeek; // 1=Mon … 7=Sun
  final String startTime; // "18:00"
  final String endTime;
  final String activity; // e.g. "Mathematics revision"
  final String? subject; // optional link to kAcademicSubjects, for filtering/recommendations

  const PersonalStudySlot({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.activity,
    this.subject,
  });

  static const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get dayName => dayOfWeek >= 1 && dayOfWeek <= 7 ? dayNames[dayOfWeek] : '';

  factory PersonalStudySlot.fromFirestore(DocumentSnapshot doc, String userId) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PersonalStudySlot(
      id: doc.id,
      userId: userId,
      dayOfWeek: (d['dayOfWeek'] as num?)?.toInt() ?? 1,
      startTime: d['startTime'] ?? '18:00',
      endTime: d['endTime'] ?? '19:00',
      activity: d['activity'] ?? '',
      subject: d['subject'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'activity': activity,
        'subject': subject,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
