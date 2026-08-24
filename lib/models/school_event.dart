// lib/models/school_event.dart
// School Connect's "Calendar of Activities" / "Upcoming Events" --
// backed by schools/{schoolId}/academic_calendar/{id}, which already had
// a correct rule (isOwnSchool()-scoped read, canManageSchool() write)
// with nothing implementing it, same situation as the school Timetable.

import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolEvent {
  final String id;
  final String schoolId;
  final String title;
  final String description;
  final DateTime startAt;
  final DateTime? endAt;
  final String? location;

  const SchoolEvent({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.description,
    required this.startAt,
    this.endAt,
    this.location,
  });

  bool get isUpcoming => startAt.isAfter(DateTime.now());

  factory SchoolEvent.fromFirestore(DocumentSnapshot doc, String schoolId) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SchoolEvent(
      id: doc.id,
      schoolId: schoolId,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      startAt: (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (d['endAt'] as Timestamp?)?.toDate(),
      location: d['location'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': endAt != null ? Timestamp.fromDate(endAt!) : null,
        'location': location,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
