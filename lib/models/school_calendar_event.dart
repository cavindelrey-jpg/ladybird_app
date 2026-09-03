// lib/models/school_calendar_event.dart
// Admin-authored school calendar/activities (spec item 7 / the "School
// Calendar / Activities" mockup). Backed by public.school_calendar_events
// -- see supabase/migrations/20260903160000_homework_and_calendar_events.sql.
// affectedClasses empty means "every class".

enum SchoolEventCategory { academic, exam, meeting, sports, holiday;

  String get label {
    switch (this) {
      case SchoolEventCategory.academic: return 'Academic';
      case SchoolEventCategory.exam:     return 'Exam';
      case SchoolEventCategory.meeting:  return 'Meeting';
      case SchoolEventCategory.sports:   return 'Sports';
      case SchoolEventCategory.holiday:  return 'Holiday';
    }
  }
}

class SchoolCalendarEvent {
  final String id;
  final String schoolId;
  final String title;
  final String description;
  final SchoolEventCategory category;
  final DateTime startDate;
  final DateTime endDate;
  final bool allDay;
  final String? startTime;
  final String? endTime;
  final String? location;
  final List<String> affectedClasses;
  final bool notifyParents;

  const SchoolCalendarEvent({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.description,
    required this.category,
    required this.startDate,
    required this.endDate,
    this.allDay = true,
    this.startTime,
    this.endTime,
    this.location,
    this.affectedClasses = const [],
    this.notifyParents = true,
  });

  bool get isAllClasses => affectedClasses.isEmpty;
  bool appliesTo(String classLevel) => isAllClasses || affectedClasses.contains(classLevel);

  factory SchoolCalendarEvent.fromSupabase(Map<String, dynamic> d) => SchoolCalendarEvent(
        id: d['id'] as String,
        schoolId: d['school_id'] as String,
        title: d['title']?.toString() ?? '',
        description: d['description']?.toString() ?? '',
        category: SchoolEventCategory.values.firstWhere(
          (c) => c.name == d['category'],
          orElse: () => SchoolEventCategory.academic,
        ),
        startDate: DateTime.tryParse(d['start_date']?.toString() ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(d['end_date']?.toString() ?? '') ?? DateTime.now(),
        allDay: d['all_day'] ?? true,
        startTime: d['start_time'],
        endTime: d['end_time'],
        location: d['location'],
        affectedClasses: (d['affected_classes'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        notifyParents: d['notify_parents'] ?? true,
      );

  Map<String, dynamic> toSupabase() => {
        'school_id': schoolId,
        'title': title,
        'description': description,
        'category': category.name,
        'start_date': '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        'end_date': '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        'all_day': allDay,
        'start_time': startTime,
        'end_time': endTime,
        'location': location,
        'affected_classes': affectedClasses,
        'notify_parents': notifyParents,
      };
}
