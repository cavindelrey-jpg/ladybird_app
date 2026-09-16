// lib/models/personal_study_slot.dart
// production_plan.md §5's "Personal Study Timetable" — deliberately a
// separate model from TimetableSlot (the School Timetable, admin-
// authored, institution-scoped). This one is self-authored by the
// student. Backed by public.personal_study_slots (see
// repositories/personal_study_repository.dart).

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'activity': activity,
    'subject': subject,
  };

  factory PersonalStudySlot.fromJson(Map<String, dynamic> json) => PersonalStudySlot(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    dayOfWeek: json['day_of_week'] as int,
    startTime: json['start_time'] as String,
    endTime: json['end_time'] as String,
    activity: json['activity'] as String,
    subject: json['subject'] as String?,
  );
}
