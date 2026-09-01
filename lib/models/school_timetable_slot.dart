// lib/models/school_timetable_slot.dart
// The official, admin-authored School Timetable -- deliberately a
// separate model from PersonalStudySlot (the self-authored Study Plan).
// Scoped by schoolId + classLevel rather than per-user. No Postgres
// table yet — zero real data at migration time; SchoolTimetableRepository
// below is an honest stub.

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
