// lib/models/school_event.dart
// School Connect's "Calendar of Activities" / "Upcoming Events". No
// Postgres table yet — zero real data at migration time;
// SchoolEventRepository below is an honest stub.

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
}
