// lib/models/calendar_event.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum CalendarEventType { classStart, classEnd, exam, holiday, deadline, ceremony, other }

class CalendarEvent {
  final String id;
  final String schoolId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final CalendarEventType type;
  final bool isAllDay;

  const CalendarEvent({
    required this.id, required this.schoolId,
    required this.title, this.description,
    required this.startDate, this.endDate,
    required this.type, this.isAllDay = true,
  });

  String get typeLabel {
    switch (type) {
      case CalendarEventType.classStart: return 'Term Start';
      case CalendarEventType.classEnd:   return 'Term End';
      case CalendarEventType.exam:       return 'Exam';
      case CalendarEventType.holiday:    return 'Holiday';
      case CalendarEventType.deadline:   return 'Deadline';
      case CalendarEventType.ceremony:   return 'Ceremony';
      case CalendarEventType.other:      return 'Event';
    }
  }

  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CalendarEvent(
      id: doc.id, schoolId: d['schoolId'] ?? '',
      title: d['title'] ?? '', description: d['description'],
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      type: CalendarEventType.values.firstWhere(
          (t) => t.name == d['type'], orElse: () => CalendarEventType.other),
      isAllDay: d['isAllDay'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolId': schoolId, 'title': title, 'description': description,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'type': type.name, 'isAllDay': isAllDay,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
