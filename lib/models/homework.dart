// lib/models/homework.dart
// Teacher-created homework, scoped to one school+class+subject. Backed by
// public.homework -- see supabase/migrations/20260903160000_homework_and_
// calendar_events.sql for the schema and the first DB-enforced
// per-(subject, classLevel) teacher write permission in this project.

class Homework {
  final String id;
  final String schoolId;
  final String classLevel;
  final String subject;
  final String teacherId;
  final String title;
  final String description;
  final String homeworkType;
  final DateTime dueAt;
  final String? attachmentUrl;
  final String? attachmentName;
  final List<String> requiredMaterials;
  final bool notify;
  final DateTime createdAt;

  /// Set only when [homeworkType] == 'quiz' — the linked public.tests row
  /// (spec item 4B, quiz-as-homework). Backed by public.homework.test_id,
  /// see supabase/migrations/20260904000001_homework_quizzes_and_extensions.sql.
  final String? testId;

  const Homework({
    required this.id,
    required this.schoolId,
    required this.classLevel,
    required this.subject,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.homeworkType,
    required this.dueAt,
    this.attachmentUrl,
    this.attachmentName,
    this.requiredMaterials = const [],
    this.notify = true,
    required this.createdAt,
    this.testId,
  });

  bool get isQuiz => homeworkType == 'quiz' && (testId ?? '').isNotEmpty;

  bool get isOverdue => DateTime.now().isAfter(dueAt);

  factory Homework.fromSupabase(Map<String, dynamic> d) => Homework(
        id: d['id'] as String,
        schoolId: d['school_id'] as String,
        classLevel: d['class_level']?.toString() ?? '',
        subject: d['subject']?.toString() ?? '',
        teacherId: d['teacher_id'] as String,
        title: d['title']?.toString() ?? '',
        description: d['description']?.toString() ?? '',
        homeworkType: d['homework_type']?.toString() ?? 'assignment',
        dueAt: DateTime.tryParse(d['due_at']?.toString() ?? '') ?? DateTime.now(),
        attachmentUrl: d['attachment_url'],
        attachmentName: d['attachment_name'],
        requiredMaterials: (d['required_materials'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        notify: d['notify'] ?? true,
        createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
        testId: d['test_id']?.toString(),
      );

  Map<String, dynamic> toSupabase() => {
        'school_id': schoolId,
        'class_level': classLevel,
        'subject': subject,
        'teacher_id': teacherId,
        'title': title,
        'description': description,
        'homework_type': homeworkType,
        'due_at': dueAt.toIso8601String(),
        'attachment_url': attachmentUrl,
        'attachment_name': attachmentName,
        'required_materials': requiredMaterials,
        'notify': notify,
        'test_id': testId,
      };
}
