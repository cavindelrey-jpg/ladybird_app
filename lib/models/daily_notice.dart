// lib/models/daily_notice.dart
// Production-ready data model for Daily Academic Notices submitted by
// Teachers/Class Masters and automatically generated timetable programmes.

enum NoticeType {
  announcement,
  homework,
  reminder,
  assignment,
  notice,
  timetableProgramme;

  String get label {
    switch (this) {
      case NoticeType.announcement:
        return 'Announcement';
      case NoticeType.homework:
        return 'Homework';
      case NoticeType.reminder:
        return 'Reminder';
      case NoticeType.assignment:
        return 'Assignment';
      case NoticeType.notice:
        return 'Notice';
      case NoticeType.timetableProgramme:
        return "Tomorrow's Programme";
    }
  }

  static NoticeType fromString(String? val) {
    return NoticeType.values.firstWhere(
      (e) => e.name.toLowerCase() == (val ?? '').toLowerCase(),
      orElse: () => NoticeType.notice,
    );
  }
}

class DailyNotice {
  final String id;
  final String schoolId;
  final String classLevel; // e.g. "Form 5"
  final String subject; // e.g. "Mathematics" or "General"
  final String teacherId;
  final String teacherName;
  final String teacherRole; // e.g. "Class Master", "Subject Teacher", "School Administration"
  final NoticeType noticeType;
  final String title;
  final String content;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime date;
  final bool isSystemGenerated; // true for timetable programme, false for teacher input
  final DateTime createdAt;

  const DailyNotice({
    required this.id,
    required this.schoolId,
    required this.classLevel,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    required this.teacherRole,
    required this.noticeType,
    required this.title,
    required this.content,
    this.attachmentUrl,
    this.attachmentName,
    required this.date,
    this.isSystemGenerated = false,
    required this.createdAt,
  });

  DailyNotice copyWith({
    String? id,
    String? schoolId,
    String? classLevel,
    String? subject,
    String? teacherId,
    String? teacherName,
    String? teacherRole,
    NoticeType? noticeType,
    String? title,
    String? content,
    String? attachmentUrl,
    String? attachmentName,
    DateTime? date,
    bool? isSystemGenerated,
    DateTime? createdAt,
  }) {
    return DailyNotice(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      classLevel: classLevel ?? this.classLevel,
      subject: subject ?? this.subject,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherRole: teacherRole ?? this.teacherRole,
      noticeType: noticeType ?? this.noticeType,
      title: title ?? this.title,
      content: content ?? this.content,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      date: date ?? this.date,
      isSystemGenerated: isSystemGenerated ?? this.isSystemGenerated,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory DailyNotice.fromJson(Map<String, dynamic> json) {
    return DailyNotice(
      id: json['id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      classLevel: json['class_level'] as String? ?? '',
      subject: json['subject'] as String? ?? 'General',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? 'School Staff',
      teacherRole: json['teacher_role'] as String? ?? 'Staff',
      noticeType: NoticeType.fromString(json['notice_type'] as String?),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      isSystemGenerated: json['is_system_generated'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'class_level': classLevel,
        'subject': subject,
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'teacher_role': teacherRole,
        'notice_type': noticeType.name,
        'title': title,
        'content': content,
        'attachment_url': attachmentUrl,
        'attachment_name': attachmentName,
        'date': date.toIso8601String(),
        'is_system_generated': isSystemGenerated,
        'created_at': createdAt.toIso8601String(),
      };
}
